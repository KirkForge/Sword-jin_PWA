extends CharacterBody2D
## Necromancer — Ranged caster that summons skeleton minions.
## Stays at distance, raises up to 2 skeletons. Priority kill target.

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 60
@export var speed := 50.0
@export var detection_range := 350.0
@export var attack_range := 200.0  # Ranged — keeps distance
@export var attack_damage := 10
@export var attack_cooldown := 2.5
@export var attack_duration := 0.6

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Knockback
var knockback_velocity := Vector2.ZERO
const KNOCKBACK_FRICTION := 400.0

# Necromancer mechanics
var summon_cooldown := 8.0
var summon_timer := 3.0  # First summon after 3s
var max_summons := 2
var active_summons := 0
var preferred_distance := 180.0  # Tries to stay this far from player

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
	
	# Knockback
	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
		move_and_slide()
		return
	
	# Timers
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()
	
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
	# Summon timer
	summon_timer -= delta
	if summon_timer <= 0 and active_summons < max_summons:
		_summon_skeleton()
		summon_timer = summon_cooldown
	
	# Count living summons
	_count_summons()
	
	if not player or player.is_dead:
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
	
	# AI: maintain preferred distance
	if dist <= detection_range:
		if dist < preferred_distance - 30:
			# Too close — retreat
			velocity = -to_player.normalized() * speed
			if not is_attacking:
				sprite.play("walk")
		elif dist > preferred_distance + 50:
			# Too far — approach
			velocity = to_player.normalized() * speed * 0.5
			if not is_attacking:
				sprite.play("walk")
		else:
			# Good range — strafe and attack
			var strafe = Vector2(-to_player.y, to_player.x).normalized() * speed * 0.3
			velocity = strafe
			if cooldown_timer <= 0 and not is_attacking:
				_start_attack()
			elif not is_attacking:
				sprite.play("idle")
	else:
		velocity = Vector2.ZERO
		if not is_attacking:
			sprite.play("idle")
	
	move_and_slide()

func _summon_skeleton():
	"""Summon a skeleton minion near the necromancer."""
	var skeleton_scene = preload("res://scenes/skeleton.tscn")
	var skel = skeleton_scene.instantiate()
	
	# Spawn near the necromancer
	var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
	skel.global_position = global_position + offset
	skel.max_health = 20  # Weak summoned version
	skel.health = 20
	skel.attack_damage = 6
	skel.speed = 70
	skel.add_to_group("enemy")
	skel.add_to_group("summon")
	
	get_parent().add_child(skel)
	active_summons += 1
	
	# Visual: green summon flash
	modulate = Color(0.3, 1.0, 0.3)
	await get_tree().create_timer(0.2).timeout
	if not is_dead:
		modulate = Color.WHITE
	
	print("Necromancer summons a skeleton! (%d active)" % active_summons)

func _count_summons():
	"""Recount living summons."""
	active_summons = 0
	for child in get_parent().get_children():
		if child.is_in_group("summon") and not child.is_dead:
			active_summons += 1

func _start_attack():
	is_attacking = true
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	attack_hitbox.disabled = false
	sprite.play("attack")
	
	# Dark bolt visual — brief flash
	modulate = Color(0.5, 0.2, 0.8)
	await get_tree().create_timer(0.15).timeout
	if not is_dead:
		modulate = Color.WHITE

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
		dn.setup(amount)

func take_damage(amount: int):
	if is_dead:
		return
	
	health -= amount
	_update_label()
	show_damage_number(amount)
	AudioManager.play_sfx("sword_hit")
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = Color.WHITE
	
	if health <= 0:
		_die()

func _update_label():
	if label:
		label.text = "NECROMANCER\nHP:%d/%d" % [health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	_show_death_sprite("necromancer_death")
	GameState.record_kill("necromancer")
	GameState.unlock_achievement("summon_slayer")
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	# Dark explosion on death — kill remaining summons
	for child in get_parent().get_children():
		if child.is_in_group("summon") and not child.is_dead:
			child.take_damage(999)  # Summons die with master
	
	if randf() < 0.25:
		var potion_scene = preload("res://scenes/potion_pickup.tscn")
		var potion = potion_scene.instantiate()
		potion.global_position = global_position
		get_tree().current_scene.add_child(potion)
	
	# Loot drop
	var loot = GameState.roll_loot_drop("necromancer", false)
	if not loot.is_empty():
		_show_loot_popup(loot)
	
	modulate = Color(0.3, 0.1, 0.5)
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
	knockback_velocity = direction * force * 0.7  # Necromancers are light
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
