extends CharacterBody2D
## Ghost — spectral enemy that phases between tangible/intangible states.
## Physical attacks have a chance to miss. Slow movement, high damage.

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 35
@export var speed := 60.0
@export var detection_range := 300.0
@export var attack_range := 40.0
@export var attack_damage := 18
@export var attack_cooldown := 1.8
@export var attack_duration := 0.4

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Ghost mechanics
var is_tangible := true
var phase_timer := 0.0
const PHASE_DURATION := 1.5
const TANGIBLE_CHANCE := 0.6  # 60% chance to be tangible at any moment
var dodge_chance := 0.30  # 30% dodge chance when tangible

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
	
	# Phase management
	phase_timer -= delta
	if phase_timer <= 0:
		is_tangible = randf() < TANGIBLE_CHANCE
		phase_timer = PHASE_DURATION
		_update_phase_visual()
	
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
	
	# Chase / Attack
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

func _update_phase_visual():
	if is_tangible:
		modulate = Color(0.6, 0.7, 1.0, 1.0)  # Blue-white, solid
	else:
		modulate = Color(0.3, 0.4, 0.8, 0.4)  # Semi-transparent
	if label:
		label.text = "GHOST\nHP:%d/%d\n%s" % [health, max_health, "TANGIBLE" if is_tangible else "ETHEREAL"]

func _start_attack():
	is_attacking = true
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	attack_hitbox.disabled = false
	sprite.play("attack")
	AudioManager.play_random_pitch("sword_swing", 0.6, 0.9)
	
	if player:
		var to_player = (player.global_position - global_position).normalized()
		velocity = to_player * speed * 2.0

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
	
	# Ethereal dodge
	if not is_tangible:
		show_damage_number(0)
		modulate = Color(0.3, 0.3, 1.0, 0.6)
		await get_tree().create_timer(0.2).timeout
		_update_phase_visual()
		return
	
	# Chance to phase-dodge even when tangible
	if randf() < dodge_chance:
		modulate = Color(0.4, 0.4, 1.0, 0.5)
		await get_tree().create_timer(0.15).timeout
		_update_phase_visual()
		AudioManager.play_sfx("shield_block")
		return
	
	health -= amount
	_update_label()
	show_damage_number(amount)
	AudioManager.play_sfx("skeleton_death")
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		_update_phase_visual()
	
	if health <= 0:
		_die()

func _update_label():
	if label:
		label.text = "GHOST\nHP:%d/%d" % [health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	GameState.record_kill("ghost")
	modulate = Color(0.2, 0.2, 0.4, 0.3)
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	# Loot drop (15% for trash, ghost can drop spirit_edge)
	var loot = GameState.roll_loot_drop("ghost", false)
	if not loot.is_empty():
		_show_loot_popup(loot)
	
	# Ghost death effect — slow fade
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()

func _on_attack_hitbox_body_entered(body):
	if body.has_method("take_damage") and body != self:
		body.take_damage(attack_damage)

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body):
	if body.is_in_group("player") and body == player:
		player = null

func _show_loot_popup(loot: Dictionary):
	"""Show a brief loot notification above the enemy."""
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
