extends CharacterBody2D
# SkeletonCaptain — Boss variant with shield + charge attack
# Inherits base skeleton behavior, adds captain mechanics

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")


@export var max_health := 80
@export var speed := 65.0
@export var detection_range := 280.0
@export var attack_range := 36.0
@export var attack_damage := 15
@export var attack_cooldown := 1.5
@export var attack_duration := 0.5

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Knockback
var knockback_velocity := Vector2.ZERO
const KNOCKBACK_FRICTION := 400.0  # Heavier, slower friction

# Captain Mechanics
@export var shield_max := 3
var shield_charges := 0
var is_shielded := false
var shield_cooldown := 0.0
var charge_ready := false
var charge_timer := 0.0

@onready var sprite = $AnimatedSprite2D
@onready var shield_sprite = $Shield
@onready var attack_hitbox = $AttackHitbox/CollisionShape2D
@onready var detection_area = $DetectionArea
@onready var label = $Label
@onready var health_bar = $HealthBar

var potion_scene = preload("res://scenes/potion_pickup.tscn")

func _ready():
	health = max_health
	shield_charges = shield_max
	_update_shield_visual()
	attack_hitbox.set_deferred("disabled", true)
	_update_label()
	sprite.play("idle")
	
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dead:
		return
	
	# Knockback (reduced when shield is up)
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
	
	if shield_cooldown > 0:
		shield_cooldown -= delta
		if shield_cooldown <= 0 and shield_charges < shield_max:
			shield_charges += 1
			_update_shield_visual()
	
	if charge_timer > 0:
		charge_timer -= delta
	else:
		charge_ready = true
	
	if not player or player.is_dead:
		return
	
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	
	# Face player
	if to_player.x > 0:
		sprite.scale.x = 1
		shield_sprite.scale.x = 1
	elif to_player.x < 0:
		sprite.scale.x = -1
		shield_sprite.scale.x = -1
	
	# Chase / Attack
	if dist <= detection_range and dist > attack_range:
		var dir = to_player.normalized()
		if charge_ready and shield_charges > 0:
			# Charge dash
			velocity = dir * speed * 2.5
			shield_charges -= 1
			_update_shield_visual()
			charge_ready = false
			charge_timer = 4.0
			sprite.play("walk")
		else:
			velocity = dir * speed
			if not is_attacking:
				sprite.play("walk")
	elif dist <= attack_range and cooldown_timer <= 0 and not is_attacking:
		_start_attack()
		velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
		if not is_attacking:
			sprite.play("idle")
	
	move_and_slide()

func _start_attack():
	is_attacking = true
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	attack_hitbox.disabled = false
	sprite.play("attack")
	
	AudioManager.play_random_pitch("sword_swing", 0.7, 1.0)
	
	# Lunge
	if player:
		var to_player = (player.global_position - global_position).normalized()
		velocity = to_player * speed * 1.5
	
	print("Captain attacks!")

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
	
	# Shield absorbs one hit
	if shield_charges > 0:
		shield_charges -= 1
		_update_shield_visual()
		# Flash gold for blocked
		modulate = Color.GOLD
		await get_tree().create_timer(0.15).timeout
		if not is_dead:
			modulate = Color.WHITE
		# Counterattack faster
		cooldown_timer = 0.5
		AudioManager.play_sfx("shield_block")
		print("Captain blocked!")
		return
	
	show_damage_number(amount)
	
	health -= amount
	_update_label()
	
	# Flash red
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = Color.WHITE
	
	if health <= 0:
		_die()

func _update_shield_visual():
	shield_sprite.visible = shield_charges > 0
	if label:
		label.self_modulate = Color.GOLD if shield_charges > 0 else Color.WHITE

func _update_label():
	if label:
		label.text = "CAPTAIN\nHP: %d/%d\n🛡%d" % [health, max_health, shield_charges]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	GameState.record_kill("skeleton_captain")
	print("Captain defeated!")
	
	# Drop potion (50% chance — captains are more generous)
	if randf() < 0.50:
		var potion = potion_scene.instantiate()
		potion.global_position = global_position
		get_tree().current_scene.add_child(potion)
		print("Potion dropped!")
	
	# Boss loot drop (guaranteed, better rarity)
	var loot = GameState.roll_loot_drop("skeleton_captain", true)
	if not loot.is_empty():
		_show_loot_popup(loot)
	
	# Always drop key on first kill
	GameState.has_gate_key = true
	print("Key acquired! Gate is open.")

	modulate = Color.DARK_GRAY
	velocity = Vector2.ZERO
	
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _show_loot_popup(loot: Dictionary):
	"""Show a brief loot notification above the enemy."""
	var label_node := Label.new()
	var rarity: String = loot.get("rarity", "common")
	var weapon_id: String = loot.get("weapon_id", "?")
	var color_hex: String = GameState.RARITY.get(rarity, {}).get("color", "#FFFFFF")
	label_node.text = "⚔ %s [%s]" % [weapon_id.replace("_", " ").capitalize(), GameState.RARITY.get(rarity, {}).get("label", rarity)]
	label_node.add_theme_color_override("font_color", Color.from_string(color_hex, Color.WHITE))
	label_node.add_theme_font_size_override("font_size", 16)
	label_node.global_position = global_position + Vector2(-40, -40)
	label_node.z_index = 100
	get_tree().current_scene.add_child(label_node)
	
	var tween := label_node.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.parallel().tween_property(label_node, "position:y", label_node.position.y - 30, 1.5)
	tween.parallel().tween_property(label_node, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.tween_callback(label_node.queue_free)

func _on_attack_hitbox_body_entered(body):
	if body.has_method("take_damage") and body != self:
		body.take_damage(attack_damage)
		HitStop.trigger_heavy()
		print("Captain hit: ", body.name)

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body):
	if body.is_in_group("player") and body == player:
		player = null

func apply_knockback(direction: Vector2, force: float):
	# Captain is heavier — reduce knockback by 40%
	knockback_velocity = direction * force * 0.6
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
