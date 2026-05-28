extends CharacterBody2D
var enemy_type := "wolf"
## Wolf — Fast pack enemy. Low HP but attacks in swarms.
## Circles the player and lunges in for quick bites.

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 30
@export var speed := 120.0
@export var detection_range := 350.0
@export var attack_range := 30.0
@export var attack_damage := 8
@export var attack_cooldown := 0.8
@export var attack_duration := 0.2

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Wolf AI — circling behavior
var circle_angle := 0.0
var circle_speed := 2.0
var circle_radius := 80.0
var is_circling := true
var lunge_speed := 350.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox/CollisionShape2D
@onready var detection_area = $DetectionArea
@onready var label = $Label
@onready var health_bar = $HealthBar

func _ready():
	health = max_health
	attack_hitbox.set_deferred("disabled", true)
	circle_angle = randf() * TAU
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
	
	# Wolf AI: circle at distance, lunge when close
	if dist <= detection_range:
		if is_circling and dist > attack_range + 20:
			# Circle the player
			circle_angle += circle_speed * delta
			var target = player.global_position + Vector2(cos(circle_angle), sin(circle_angle)) * circle_radius
			velocity = (target - global_position).normalized() * speed
			if not is_attacking:
				sprite.play("walk")
		elif dist <= attack_range and cooldown_timer <= 0 and not is_attacking:
			# Lunge attack
			_start_attack()
		elif dist <= attack_range + 40 and not is_attacking:
			# Close distance quickly
			velocity = to_player.normalized() * speed * 1.3
			sprite.play("walk")
		else:
			velocity = to_player.normalized() * speed * 0.8
			if not is_attacking:
				sprite.play("walk")
	else:
		# Wander toward player
		velocity = to_player.normalized() * speed * 0.5
		if not is_attacking:
			sprite.play("walk")
	
	move_and_slide()

func _start_attack():
	is_attacking = true
	is_circling = false
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	attack_hitbox.disabled = false
	sprite.play("attack")
	AudioManager.play_random_pitch("sword_swing", 1.2, 1.5)
	
	# Lunge toward player
	if player:
		var to_player = (player.global_position - global_position).normalized()
		velocity = to_player * lunge_speed

func _end_attack():
	is_attacking = false
	is_circling = true
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
	AudioManager.play_sfx("skeleton_death")
	
	# Wolves scatter briefly when hit
	is_circling = true
	circle_angle += PI  # Jump to opposite side
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = Color.WHITE
	
	if health <= 0:
		_die()

func _update_label():
	if label:
		label.text = "WOLF\nHP:%d/%d" % [health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	# Wolf death — quick fade
	modulate = Color.GRAY
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
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