extends CharacterBody2D
## Assassin — Crimson Fang elite. Extremely fast with poison attacks.
## Periodically vanishes and reappears behind the player.

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 45
@export var speed := 140.0
@export var detection_range := 350.0
@export var attack_range := 28.0
@export var attack_damage := 20
@export var attack_cooldown := 1.3
@export var attack_duration := 0.25

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Assassin mechanics
var is_vanished := false
var vanish_cooldown := 5.0
var vanish_timer := 0.0
var vanish_duration := 1.0
var vanish_countdown := 0.0
var poison_damage := 4  # Tick damage per hit
var poison_duration := 3.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox/CollisionShape2D
@onready var detection_area = $DetectionArea
@onready var label = $Label
@onready var health_bar = $HealthBar

func _ready():
	health = max_health
	attack_hitbox.set_deferred("disabled", true)
	vanish_timer = vanish_cooldown * randf_range(0.5, 1.5)
	_update_label()
	sprite.play("idle")
	
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dead:
		return
	
	# Vanish management
	vanish_timer -= delta
	if vanish_timer <= 0 and not is_vanished:
		_start_vanish()
	
	if vanish_countdown > 0:
		vanish_countdown -= delta
		if vanish_countdown <= 0:
			_end_vanish()
	
	# Timers
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()
	
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
	if not player or player.is_dead or is_vanished:
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
	
	# Chase — assassins are relentless
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
	
	move_and_slide()

func _start_vanish():
	is_vanished = true
	vanish_countdown = vanish_duration
	modulate.a = 0.2
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	# Store where to reappear
	if player:
		var behind_player = player.global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		# Teleport is handled in _end_vanish

func _end_vanish():
	is_vanished = false
	modulate.a = 1.0
	$CollisionShape2D.set_deferred("disabled", false)
	vanish_timer = vanish_cooldown
	
	# Reappear behind player
	if player:
		var behind = player.global_position
		var facing_dir = Vector2.RIGHT if player.sprite.scale.x >= 0 else Vector2.LEFT
		global_position = behind - facing_dir * 60 + Vector2(0, randf_range(-40, 40))
	
	AudioManager.play_sfx("dodge_roll")

func _start_attack():
	is_attacking = true
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	attack_hitbox.disabled = false
	sprite.play("attack")
	AudioManager.play_random_pitch("sword_swing", 1.0, 1.2)
	
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
	if is_dead or is_vanished:
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
		label.text = "ASSASSIN\nHP:%d/%d" % [health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	# Smoke bomb death
	modulate.a = 0.0
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _on_attack_hitbox_body_entered(body):
	if body.has_method("take_damage") and body != self:
		body.take_damage(attack_damage)
		# Poison application
		if body.has_method("apply_poison"):
			body.apply_poison(poison_damage, poison_duration)
		HitStop.trigger_light()

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body):
	if body.is_in_group("player") and body == player:
		player = null
