extends CharacterBody2D
## Wraith — Elite ghost variant. Teleports short distances.
## Area-of-effect life drain. Intangible during teleport.

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 70
@export var speed := 65.0
@export var detection_range := 300.0
@export var attack_range := 50.0
@export var attack_damage := 15
@export var attack_cooldown := 2.0
@export var attack_duration := 0.5

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Knockback
var knockback_velocity := Vector2.ZERO
const KNOCKBACK_FRICTION := 500.0

# Wraith mechanics
var is_phasing := false
var teleport_cooldown := 4.0
var teleport_timer := 2.0
var teleport_distance := 120.0
var drain_radius := 60.0
var drain_damage := 5
var drain_heal := 3
var drain_cooldown := 3.0
var drain_timer := 1.5
var intangible_cycle := 0.0  # Flickers between tangible/intangible
var is_tangible := true

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox/CollisionShape2D
@onready var detection_area = $DetectionArea
@onready var label = $Label
@onready var health_bar = $HealthBar

func _ready():
	health = max_health
	attack_hitbox.set_deferred("disabled", true)
	_update_label()
	sprite.play("idle")
	
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dead:
		return
	
	# Knockback (only when tangible)
	if knockback_velocity.length() > 1.0:
		if not is_tangible:
			is_tangible = true
			is_phasing = false
			modulate.a = 1.0
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
		move_and_slide()
		return
	
	# Intangible cycle — wraith flickers between tangible and intangible
	intangible_cycle += delta
	is_tangible = sin(intangible_cycle * 1.5) > -0.3  # Tangible ~75% of the time
	if not is_tangible and not is_phasing:
		modulate.a = 0.4
	else:
		modulate.a = 1.0
	
	# Timers
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()
	
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
	# Teleport timer
	teleport_timer -= delta
	if teleport_timer <= 0 and not is_phasing:
		_teleport()
	
	# Life drain timer
	drain_timer -= delta
	if drain_timer <= 0 and player and not player.is_dead:
		_life_drain()
		drain_timer = drain_cooldown
	
	if not player or player.is_dead or is_phasing:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	
	# Face player
	if to_player.x > 0:
		sprite.scale.x = 1
	elif to_player.x < 0:
		sprite.scale.x = -1
	
	# AI: approach and drain
	if dist <= detection_range and dist > attack_range:
		velocity = to_player.normalized() * speed
		if not is_attacking:
			sprite.play("walk")
	elif dist <= attack_range and cooldown_timer <= 0 and not is_attacking and is_tangible:
		_start_attack()
		velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
		if not is_attacking:
			sprite.play("idle")
	
	move_and_slide()

func _teleport():
	"""Short-range teleport near the player."""
	is_phasing = true
	is_tangible = false
	modulate.a = 0.1
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	# Brief invisibility
	await get_tree().create_timer(0.5).timeout
	
	if is_dead:
		return
	
	# Reappear near player
	if player and not player.is_dead:
		var angle = randf() * TAU
		global_position = player.global_position + Vector2(cos(angle), sin(angle)) * teleport_distance
	
	is_phasing = false
	is_tangible = true
	modulate.a = 1.0
	$CollisionShape2D.set_deferred("disabled", false)
	teleport_timer = teleport_cooldown
	
	AudioManager.play_sfx("ghost_start")

func _life_drain():
	"""Area-of-effect life drain — damages player, heals self."""
	if not player or player.is_dead:
		return
	
	var dist = global_position.distance_to(player.global_position)
	if dist <= drain_radius:
		player.take_damage(drain_damage)
		health = min(health + drain_heal, max_health)
		_update_label()
		
		# Visual: purple drain lines
		_show_drain_effect()
		print("Wraith life drain! Player -%d, Wraith +%d" % [drain_damage, drain_heal])

func _show_drain_effect():
	"""Show purple drain particles between wraith and player."""
	for i in range(5):
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.color = Color(0.6, 0.2, 0.8, 0.8)
		particle.global_position = player.global_position if player else global_position
		particle.z_index = 99
		get_tree().current_scene.add_child(particle)
		
		var target = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var start = particle.global_position
		
		var tween := particle.create_tween()
		tween.tween_property(particle, "global_position", target, 0.4)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_callback(particle.queue_free)

func _start_attack():
	is_attacking = true
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	attack_hitbox.disabled = false
	sprite.play("attack")
	AudioManager.play_random_pitch("sword_swing", 0.8, 1.0)

func _end_attack():
	is_attacking = false
	attack_hitbox.disabled = true
	velocity = Vector2.ZERO
	sprite.play("idle")

func show_damage_number(amount: int, is_heal := false):
	var dn = damage_number_scene.instantiate() as Node2D
	dn.global_position = global_position + Vector2(0, -24)
	get_tree().current_scene.add_child(dn)
	if is_heal:
		dn.setup_heal(amount)
	else:
		dn.setup(amount, Color(0.6, 0.3, 0.9))  # Purple damage numbers

func take_damage(amount: int):
	if is_dead or not is_tangible:
		return
	
	health -= amount
	_update_label()
	show_damage_number(amount)
	AudioManager.play_sfx("sword_hit")
	
	modulate = Color(0.8, 0.2, 1.0)  # Purple flash
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = Color.WHITE
	
	if health <= 0:
		_die()

func _update_label():
	if label:
		label.text = "WRAITH\nHP:%d/%d" % [health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	_show_death_sprite("wraith_death")
	GameState.record_kill("wraith")
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	if randf() < 0.25:
		var potion_scene = preload("res://scenes/potion_pickup.tscn")
		var potion = potion_scene.instantiate()
		potion.global_position = global_position
		get_tree().current_scene.add_child(potion)
	
	# Loot drop
	var loot = GameState.roll_loot_drop("wraith", false)
	if not loot.is_empty():
		_show_loot_popup(loot)
	
	# Ghost death — fade out
	modulate.a = 0.0
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _on_attack_hitbox_body_entered(body):
	if body.has_method("take_damage") and body != self:
		body.take_damage(attack_damage)
		HitStop.trigger_light()

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body):
	if body.is_in_group("player") and body == player:
		player = null

func apply_knockback(direction: Vector2, force: float):
	if not is_tangible:
		return  # Can't knock back intangible wraith
	knockback_velocity = direction * force * 0.5  # Ghosts are light
	modulate = Color(1.5, 0.5, 0.5)
	await get_tree().create_timer(0.08).timeout
	if not is_dead:
		modulate = Color.WHITE

func apply_shaman_buff(damage_mult: float, speed_mult: float, duration: float):
	attack_damage = int(attack_damage * damage_mult)
	speed *= speed_mult
	await get_tree().create_timer(duration).timeout
	if not is_dead:
		attack_damage = int(attack_damage / damage_mult)
		speed /= speed_mult

func _show_loot_popup(loot: Dictionary):
	var label_node := Label.new()
	var rarity: String = loot.get("rarity", "common")
	var weapon_id: String = loot.get("weapon_id", "?")
	var color_hex: String = GameState.RARITY.get(rarity, {}).get("color", "#FFFFFF")
	label_node.text = "⚔ %s [%s]" % [weapon_id.replace("_", " ").capitalize(), GameState.RARITY.get(rarity, {}).get("label", rarity)]
	label_node.add_theme_color_override("font_color", Color.from_string(color_hex, Color.WHITE))
	label_node.add_theme_font_size_override("font_size", 14)
	label_node.global_position = global_position + Vector2(-40, -40)
	label_node.z_index = 100
	get_tree().current_scene.add_child(label_node)
	var tween := label_node.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.parallel().tween_property(label_node, "position:y", label_node.position.y - 30, 1.5)
	tween.parallel().tween_property(label_node, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.tween_callback(label_node.queue_free)

func _show_death_sprite(sprite_name: String):
	var path = "res://assets/art/enemies/%s.png" % sprite_name
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			var death_sprite = Sprite2D.new()
			death_sprite.name = "DeathSprite"
			death_sprite.texture = tex
			death_sprite.global_position = global_position
			death_sprite.z_index = 10
			death_sprite.scale = Vector2(0.5, 0.5)
			get_tree().current_scene.add_child(death_sprite)
			var tween = get_tree().create_tween()
			tween.tween_property(death_sprite, "modulate:a", 0.0, 0.8)
			tween.tween_callback(death_sprite.queue_free)
