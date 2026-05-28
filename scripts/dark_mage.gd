extends CharacterBody2D
var enemy_type := "dark_mage"
## Dark Mage — Ranged spellcaster. Fires homing shadow bolts.
## Stays at distance, teleports away when player gets close.
## Summons shadow clones at low HP.

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 60
@export var speed := 50.0
@export var detection_range := 400.0
@export var attack_range := 200.0
@export var attack_damage := 22
@export var attack_cooldown := 2.0
@export var attack_duration := 0.5

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Dark Mage mechanics
var teleport_cooldown := 6.0
var teleport_timer := 0.0
var shadow_bolt_scene: PackedScene = null
var preferred_distance := 180.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox/CollisionShape2D
@onready var detection_area = $DetectionArea
@onready var label = $Label
@onready var health_bar = $HealthBar

func _ready():
	health = max_health
	attack_hitbox.set_deferred("disabled", true)
	teleport_timer = teleport_cooldown * randf_range(0.5, 1.0)
	_update_label()
	sprite.play("idle")
	
	# Try to load shadow bolt scene (may not exist yet)
	shadow_bolt_scene = load("res://scenes/projectiles/shadow_bolt.tscn")
	
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dead:
		return
	
	# Teleport timer
	teleport_timer -= delta
	
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
	
	# Dark Mage AI: keep distance, teleport if cornered
	if dist <= detection_range:
		if dist < preferred_distance * 0.6 and teleport_timer <= 0:
			_teleport_away()
		elif dist > preferred_distance * 1.4:
			# Move closer
			velocity = to_player.normalized() * speed
			if not is_attacking:
				sprite.play("walk")
		elif dist < preferred_distance * 0.8:
			# Move away
			velocity = -to_player.normalized() * speed * 1.2
			if not is_attacking:
				sprite.play("walk")
		else:
			# Maintain distance, strafe
			var strafe = Vector2(-to_player.y, to_player.x).normalized() * speed * 0.6
			velocity = strafe
			if not is_attacking:
				sprite.play("walk")
		
		# Cast shadow bolt at range
		if dist <= attack_range and cooldown_timer <= 0 and not is_attacking:
			_cast_shadow_bolt()
	else:
		velocity = Vector2.ZERO
		if not is_attacking:
			sprite.play("idle")
	
	move_and_slide()

func _teleport_away():
	teleport_timer = teleport_cooldown
	modulate.a = 0.0
	
	# Teleport to a random position away from player
	if player:
		var angle = randf() * TAU
		var dist = preferred_distance + randf_range(20, 60)
		var new_pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		
		# Clamp to arena bounds
		new_pos.x = clampf(new_pos.x, 60, 580)
		new_pos.y = clampf(new_pos.y, 60, 300)
		global_position = new_pos
	
	# Flash reappearance
	modulate = Color(0.5, 0.2, 0.8)  # Purple flash
	AudioManager.play_sfx("dodge_roll")
	await get_tree().create_timer(0.2).timeout
	if not is_dead:
		modulate = Color.WHITE

func _cast_shadow_bolt():
	is_attacking = true
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	sprite.play("attack")
	AudioManager.play_random_pitch("sword_swing", 0.4, 0.6)
	
	# Fire projectile if scene exists
	if shadow_bolt_scene:
		var bolt = shadow_bolt_scene.instantiate()
		bolt.global_position = global_position
		if player:
			bolt.direction = (player.global_position - global_position).normalized()
		bolt.damage = attack_damage
		get_tree().current_scene.add_child(bolt)
	else:
		# Fallback: direct damage at range (hitscan)
		if player and player.global_position.distance_to(global_position) <= attack_range:
			player.take_damage(attack_damage)
			HitStop.trigger_light()

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
	
	modulate = Color.PURPLE
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = Color.WHITE
	
	# Chance to teleport away when hit
	if randf() < 0.3 and teleport_timer <= 0:
		_teleport_away()
	
	if health <= 0:
		_die()

func _update_label():
	if label:
		label.text = "DARK MAGE\nHP:%d/%d" % [health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	# Dark mage death — purple explosion
	ScreenShake.shake(4.0, 0.3)
	modulate = Color(0.5, 0.2, 0.8)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
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