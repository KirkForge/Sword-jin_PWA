extends CharacterBody2D
## Bandit — fast flanking enemy. Tries to circle behind the player.
## Lower HP than skeletons but faster and smarter positioning.

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 50
@export var speed := 90.0
@export var detection_range := 260.0
@export var attack_range := 32.0
@export var attack_damage := 12
@export var attack_cooldown := 1.0
@export var attack_duration := 0.3

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Bandit AI — flanking behavior
var flank_direction := 1  # 1 = clockwise, -1 = counterclockwise
var flank_timer := 0.0
const FLANK_INTERVAL := 2.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox/CollisionShape2D
@onready var detection_area = $DetectionArea
@onready var label = $Label
@onready var health_bar = $HealthBar

func _ready():
	health = max_health
	attack_hitbox.set_deferred("disabled", true)
	flank_direction = 1 if randf() < 0.5 else -1
	_update_label()
	sprite.play("idle")
	
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dead:
		return
	
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()
	
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
	flank_timer -= delta
	if flank_timer <= 0:
		flank_direction = 1 if randf() < 0.5 else -1
		flank_timer = FLANK_INTERVAL
	
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
	
	# Chase with flanking
	if dist <= detection_range and dist > attack_range:
		var dir = to_player.normalized()
		# Add perpendicular component for flanking
		var flank = Vector2(-dir.y, dir.x) * flank_direction * 0.4
		velocity = (dir + flank).normalized() * speed
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
	AudioManager.play_random_pitch("sword_swing", 0.9, 1.1)
	
	if player:
		var to_player = (player.global_position - global_position).normalized()
		velocity = to_player * speed * 2.5

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
	AudioManager.play_sfx("player_hurt")
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = Color.WHITE
	
	if health <= 0:
		_die()

func _update_label():
	if label:
		label.text = "BANDIT\nHP:%d/%d" % [health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	if randf() < 0.25:
		var potion_scene = preload("res://scenes/potion_pickup.tscn")
		var potion = potion_scene.instantiate()
		potion.global_position = global_position
		get_tree().current_scene.add_child(potion)
	
	modulate = Color.DARK_GRAY
	await get_tree().create_timer(0.3).timeout
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
