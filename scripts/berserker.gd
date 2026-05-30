extends CharacterBody2D
## Berserker — Dual-wielding brute that gets FASTER as HP drops.
## At 50% HP enters ENRAGE: +50% speed, +30% damage, red aura.

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 90
@export var speed := 75.0
@export var detection_range := 220.0
@export var attack_range := 36.0
@export var attack_damage := 18
@export var attack_cooldown := 1.0
@export var attack_duration := 0.35

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Knockback
var knockback_velocity := Vector2.ZERO
const KNOCKBACK_FRICTION := 350.0  # Heavy — hard to push

# Berserker mechanics
var is_enraged := false
var enrage_threshold := 0.5  # 50% HP
var enrage_speed_mult := 1.5
var enrage_damage_mult := 1.3
var enrage_attack_speed_mult := 0.6  # Attack faster
var _original_speed := 0.0
var _original_damage := 0
var _original_cooldown := 0.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox/CollisionShape2D
@onready var detection_area = $DetectionArea
@onready var label = $Label
@onready var health_bar = $HealthBar

func _ready():
	health = max_health
	attack_hitbox.set_deferred("disabled", true)
	_original_speed = speed
	_original_damage = attack_damage
	_original_cooldown = attack_cooldown
	_update_label()
	sprite.play("idle")
	
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dead:
		return
	
	# Check enrage
	if not is_enraged and health <= int(max_health * enrage_threshold):
		_enter_enrage()
	
	# Knockback (reduced when enraged)
	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		var friction = KNOCKBACK_FRICTION * (0.5 if is_enraged else 1.0)
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	
	# Timers
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()
	
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
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
	
	# AI: direct charge — berserkers don't flank
	if dist <= detection_range and dist > attack_range:
		velocity = to_player.normalized() * speed
		if not is_attacking:
			sprite.play("walk")
	elif dist <= attack_range and cooldown_timer <= 0 and not is_attacking:
		_start_attack()
		velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
		if not is_attacking:
			sprite.play("idle")
	
	# Enraged aura visual
	if is_enraged:
		modulate = Color(1.0, 0.4 + 0.2 * sin(Time.get_ticks_msec() / 100.0), 0.3)
	
	move_and_slide()

func _enter_enrage():
	"""Enter enraged state — faster, stronger, scarier."""
	is_enraged = true
	speed = _original_speed * enrage_speed_mult
	attack_damage = int(_original_damage * enrage_damage_mult)
	attack_cooldown = _original_cooldown * enrage_attack_speed_mult
	
	# Visual: red pulse + shake
	modulate = Color(1.5, 0.3, 0.2)
	ScreenShake.shake(3.0, 0.3)
	
	# Brief pause for drama
	Engine.time_scale = 0.3
	await get_tree().create_timer(0.3, true, false, true).timeout
	Engine.time_scale = 1.0
	
	# Update label
	_update_label()
	print("BERSERKER ENRAGED! Speed=%.0f Dmg=%d" % [speed, attack_damage])

func _start_attack():
	is_attacking = true
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	attack_hitbox.disabled = false
	sprite.play("attack")
	
	# Enraged: double lunge
	var lunge_mult = 2.0 if is_enraged else 1.5
	AudioManager.play_random_pitch("sword_swing", 0.7, 0.9)  # Heavier sound
	
	if player:
		var to_player = (player.global_position - global_position).normalized()
		velocity = to_player * speed * lunge_mult

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
		dn.setup(amount, Color.ORANGE if is_enraged else Color.RED)

func take_damage(amount: int):
	if is_dead:
		return
	
	health -= amount
	_update_label()
	show_damage_number(amount)
	AudioManager.play_sfx("sword_hit")
	
	if not is_enraged:
		modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if not is_dead:
			modulate = Color.WHITE
	
	if health <= 0:
		_die()

func _update_label():
	var tag = "ENRAGED " if is_enraged else ""
	if label:
		label.text = "%sBERSERKER\nHP:%d/%d" % [tag, health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	_show_death_sprite("berserker_death")
	GameState.record_kill("berserker")
	if is_enraged:
		GameState.unlock_achievement("enraged_kill")
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	if randf() < 0.30:
		var potion_scene = preload("res://scenes/potion_pickup.tscn")
		var potion = potion_scene.instantiate()
		potion.global_position = global_position
		get_tree().current_scene.add_child(potion)
	
	# Loot drop
	var loot = GameState.roll_loot_drop("berserker", false)
	if not loot.is_empty():
		_show_loot_popup(loot)
	
	modulate = Color.DARK_RED
	await get_tree().create_timer(0.4).timeout
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
	var mult = 0.6 if is_enraged else 1.0  # Harder to push when enraged
	knockback_velocity = direction * force * mult
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
