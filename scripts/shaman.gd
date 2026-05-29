extends CharacterBody2D
## Shaman — Support enemy that buffs nearby allies with damage and speed aura.
## Must kill first or fights get much harder. Stays behind other enemies.

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 55
@export var speed := 55.0
@export var detection_range := 300.0
@export var attack_range := 150.0  # Ranged — stays back
@export var attack_damage := 8
@export var attack_cooldown := 3.0
@export var attack_duration := 0.5

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Knockback
var knockback_velocity := Vector2.ZERO
const KNOCKBACK_FRICTION := 450.0

# Shaman mechanics
var aura_range := 120.0
var aura_damage_mult := 1.3   # +30% damage to nearby allies
var aura_speed_mult := 1.2    # +20% speed to nearby allies
var aura_active := true
var aura_pulse_timer := 0.0
const AURA_PULSE_INTERVAL := 0.5
var preferred_distance := 160.0

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
	
	# Aura pulse — apply buffs to nearby allies
	aura_pulse_timer -= delta
	if aura_pulse_timer <= 0 and aura_active:
		_apply_aura()
		aura_pulse_timer = AURA_PULSE_INTERVAL
	
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
	
	# AI: stay behind allies, maintain distance
	if dist <= detection_range:
		if dist < preferred_distance - 30:
			# Too close — retreat
			velocity = -to_player.normalized() * speed
			if not is_attacking:
				sprite.play("walk")
		elif dist > preferred_distance + 60:
			# Too far — approach
			velocity = to_player.normalized() * speed * 0.5
			if not is_attacking:
				sprite.play("walk")
		else:
			# Good range — strafe and attack
			var strafe = Vector2(-to_player.y, to_player.x).normalized() * speed * 0.25
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

func _apply_aura():
	"""Buff nearby allies with damage and speed increase."""
	if not aura_active or is_dead:
		return
	
	var buffed_count := 0
	for child in get_parent().get_children():
		if child.is_in_group("enemy") and child != self and not child.is_dead:
			var dist = global_position.distance_to(child.global_position)
			if dist <= aura_range:
				# Apply temporary buff
				if child.has_method("apply_shaman_buff"):
					child.apply_shaman_buff(aura_damage_mult, aura_speed_mult, 1.0)
				buffed_count += 1
	
	# Visual pulse
	modulate = Color(0.3, 0.8, 1.0)  # Blue flash
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = Color.WHITE

func _start_attack():
	is_attacking = true
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	attack_hitbox.disabled = false
	sprite.play("attack")
	
	# Blue bolt visual
	modulate = Color(0.4, 0.5, 1.0)
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
		dn.setup(amount, Color.CYAN)

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
		label.text = "SHAMAN\nHP:%d/%d" % [health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	aura_active = false
	GameState.record_kill("shaman")
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	if randf() < 0.25:
		var potion_scene = preload("res://scenes/potion_pickup.tscn")
		var potion = potion_scene.instantiate()
		potion.global_position = global_position
		get_tree().current_scene.add_child(potion)
	
	# Loot drop
	var loot = GameState.roll_loot_drop("shaman", false)
	if not loot.is_empty():
		_show_loot_popup(loot)
	
	modulate = Color(0.2, 0.4, 0.6)
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
	knockback_velocity = direction * force * 0.8
	modulate = Color(1.5, 0.5, 0.5)
	await get_tree().create_timer(0.08).timeout
	if not is_dead:
		modulate = Color.WHITE

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