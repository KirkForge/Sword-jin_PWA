extends CharacterBody2D
# SkeletonArcher — Ranged enemy: keeps distance, fires projectiles

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 25
@export var speed := 70.0
@export var detection_range := 300.0
@export var optimal_range := 170.0     # Ideal distance to stand at
@export var too_close_range := 80.0     # Run away if player closer than this
@export var arrow_damage := 7
@export var arrow_speed := 220.0
@export var fire_cooldown := 2.0
@export var fire_windup := 0.6          # Telegraph before shot

# Packed scene for the arrow projectile
@export var arrow_scene: PackedScene = preload("res://scenes/projectiles/arrow.tscn")

var health: int
var player: Node2D = null
var is_dead := false

# Knockback
var knockback_velocity := Vector2.ZERO
const KNOCKBACK_FRICTION := 500.0
var cooldown_timer := 0.0
var windup_timer := 0.0
var is_winding_up := false

@onready var sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var label = $Label
@onready var fire_point = $FirePoint
@onready var health_bar = $HealthBar

var potion_scene = preload("res://scenes/potion_pickup.tscn")

func _ready():
	health = max_health
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
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
	if is_winding_up:
		windup_timer -= delta
		if windup_timer <= 0:
			_fire_arrow()
			is_winding_up = false
			modulate = Color.WHITE  # reset telegraph
		return
	
	if not player or player.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var dir = to_player.normalized()
	
	# Face player
	if to_player.x > 0:
		sprite.scale.x = 1
	elif to_player.x < 0:
		sprite.scale.x = -1
	
	# Behavior based on distance
	if dist > detection_range:
		# Too far, idle
		velocity = Vector2.ZERO
		sprite.play("idle")
	elif dist < too_close_range:
		# Too close — back away
		velocity = -dir * speed * 1.2
		sprite.play("walk")
	elif dist < optimal_range - 20.0:
		# A bit too close — gentle retreat
		velocity = -dir * speed * 0.6
		sprite.play("walk")
	elif dist > optimal_range + 30.0:
		# A bit too far — approach
		velocity = dir * speed
		sprite.play("walk")
	else:
		# In the sweet spot — try to fire
		velocity = Vector2.ZERO
		sprite.play("idle")
		if cooldown_timer <= 0 and not is_winding_up:
			_start_windup()
	
	move_and_slide()

func _start_windup():
	is_winding_up = true
	windup_timer = fire_windup
	# Telegraph: flash yellow for windup duration
	modulate = Color.YELLOW
	# Timer _physics_process will call _fire_arrow when windup_timer reaches 0

func _fire_arrow():
	if not player or is_dead:
		return
	
	cooldown_timer = fire_cooldown
	
	# Spawn arrow at fire point
	var arrow = arrow_scene.instantiate() if arrow_scene else null
	if not arrow:
		push_error("No arrow scene assigned to archer")
		return
	
	var origin = fire_point.global_position if fire_point else global_position
	arrow.position = origin
	
	# Aim at player
	var to_player = player.global_position - origin
	arrow.direction = to_player.normalized()
	arrow.speed = arrow_speed
	arrow.damage = arrow_damage
	
	get_tree().current_scene.add_child(arrow)
	
	AudioManager.play_sfx("bow_fire")

func take_damage(amount: int):
	if is_dead:
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

func show_damage_number(amount: int):
	var dn = damage_number_scene.instantiate() as Node2D
	dn.global_position = global_position + Vector2(0, -24)
	get_tree().current_scene.add_child(dn)
	dn.setup(amount)

func _update_label():
	if label:
		label.text = "HP: %d/%d\n🏹" % [health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	GameState.record_kill("skeleton_archer")
	print("Archer defeated!")
	
	AudioManager.play_sfx("skeleton_death")
	
	# Drop potion (20% chance)
	if randf() < 0.20:
		var potion = potion_scene.instantiate()
		potion.global_position = global_position
		get_tree().current_scene.add_child(potion)
		print("Potion dropped!")
	
	# Loot drop (15% chance for trash mobs)
	var loot = GameState.roll_loot_drop("skeleton_archer", false)
	if not loot.is_empty():
		_show_loot_popup(loot)
	
	modulate = Color.DARK_GRAY
	velocity = Vector2.ZERO
	
	if $CollisionShape2D:
		$CollisionShape2D.set_deferred("disabled", true)
	
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
	label_node.add_theme_font_size_override("font_size", 14)
	label_node.global_position = global_position + Vector2(-40, -40)
	label_node.z_index = 100
	get_tree().current_scene.add_child(label_node)
	
	var tween := label_node.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.parallel().tween_property(label_node, "position:y", label_node.position.y - 30, 1.5)
	tween.parallel().tween_property(label_node, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.tween_callback(label_node.queue_free)

func _on_attack_hitbox_body_entered(body):
	if body.has_method("take_damage") and body != self and body.is_in_group("player"):
		body.take_damage(int(arrow_damage * 0.6))  # Weak melee: 60% of arrow dmg
		print("Archer bashed: ", body.name)

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body):
	if body.is_in_group("player") and body == player:
		player = null

func apply_knockback(direction: Vector2, force: float):
	knockback_velocity = direction * force
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
