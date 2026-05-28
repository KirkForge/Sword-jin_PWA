extends CharacterBody2D
var enemy_type := "shadow_lord"
## Shadow Lord — Act 3 Final Boss
## Phase 1: Teleports, summons wolves, shadow bolts
## Phase 2 (below 40% HP): Faster, more aggressive, shadow dash attacks

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 280
@export var speed := 80.0
@export var detection_range := 600.0
@export var attack_range := 50.0
@export var attack_damage := 30
@export var attack_cooldown := 1.5
@export var attack_duration := 0.4

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Phase system
var phase := 1
var phase2_threshold := 0.4  # 40% HP
var is_enraged := false

# Shadow Lord mechanics
var teleport_cooldown := 5.0
var teleport_timer := 0.0
var summon_cooldown := 12.0
var summon_timer := 0.0
var shadow_dash_speed := 400.0
var is_dashing := false
var dash_timer := 0.0
var dash_duration := 0.3
var dash_direction := Vector2.ZERO
var wolves_summoned := 0
var max_wolves := 2

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox/CollisionShape2D
@onready var detection_area = $DetectionArea
@onready var label = $Label
@onready var health_bar = $HealthBar

func _ready():
	health = max_health
	attack_hitbox.set_deferred("disabled", true)
	teleport_timer = teleport_cooldown * randf_range(0.5, 1.0)
	summon_timer = summon_cooldown * randf_range(0.3, 0.6)
	_update_label()
	sprite.play("idle")
	
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dead:
		return
	
	# Phase check
	if not is_enraged and float(health) / float(max_health) <= phase2_threshold:
		_enter_phase2()
	
	# Timers
	teleport_timer -= delta
	summon_timer -= delta
	
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()
	
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * shadow_dash_speed
		if phase == 2:
			shadow_dash_speed = 500.0
		if dash_timer <= 0:
			is_dashing = false
			velocity = Vector2.ZERO
		move_and_slide()
		return
	
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
	
	# Shadow Lord AI
	if dist <= detection_range:
		# Summon wolves periodically
		if summon_timer <= 0 and wolves_summoned < max_wolves:
			_summon_wolf()
		
		# Teleport if player is too close
		if dist < 60 and teleport_timer <= 0:
			_teleport_away()
		elif dist <= attack_range and cooldown_timer <= 0 and not is_attacking:
			_start_attack()
		elif dist > attack_range:
			# Approach player (phase 2: more aggressive)
			var move_speed = speed * (1.5 if phase == 2 else 1.0)
			velocity = to_player.normalized() * move_speed
			if not is_attacking:
				sprite.play("walk")
		
		# Phase 2: shadow dash attack
		if phase == 2 and dist > 60 and dist < 200 and cooldown_timer <= 0 and not is_attacking and not is_dashing:
			if randf() < 0.01:  # Random chance per frame
				_shadow_dash(to_player.normalized())
	else:
		velocity = Vector2.ZERO
		if not is_attacking:
			sprite.play("idle")
	
	move_and_slide()

func _enter_phase2():
	is_enraged = true
	phase = 2
	max_wolves = 3
	attack_cooldown = 1.0
	speed = 100.0
	
	# Dramatic phase transition
	ScreenShake.shake(6.0, 0.5)
	modulate = Color(0.4, 0.0, 0.6)  # Deep purple flash
	
	# Heal slightly
	health = mini(health + 30, max_health)
	_update_label()
	
	await get_tree().create_timer(0.3).timeout
	if not is_dead:
		modulate = Color.WHITE
		print(">>> SHADOW LORD enters PHASE 2! <<<")

func _summon_wolf():
	summon_timer = summon_cooldown
	wolves_summoned += 1
	
	var wolf_scene = load("res://scenes/wolf.tscn")
	if not wolf_scene:
		return
	
	var wolf = wolf_scene.instantiate()
	# Spawn near the Shadow Lord
	var offset = Vector2(randf_range(-80, 80), randf_range(-60, 60))
	wolf.global_position = global_position + offset
	wolf.max_health = 25  # Weaker wolves
	wolf.health = 25
	wolf.attack_damage = 6
	get_tree().current_scene.add_child(wolf)
	wolf.add_to_group("enemy")
	
	AudioManager.play_sfx("sword_swing")
	print("Shadow Lord summons a wolf!")

func _teleport_away():
	teleport_timer = teleport_cooldown
	modulate.a = 0.0
	
	if player:
		var angle = randf() * TAU
		var dist = 150.0 + randf_range(0, 60)
		var new_pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		new_pos.x = clampf(new_pos.x, 60, 580)
		new_pos.y = clampf(new_pos.y, 60, 300)
		global_position = new_pos
	
	# Shadow reappearance effect
	modulate = Color(0.5, 0.0, 0.8)
	AudioManager.play_sfx("dodge_roll")
	await get_tree().create_timer(0.2).timeout
	if not is_dead:
		modulate = Color.WHITE

func _shadow_dash(dir: Vector2):
	is_dashing = true
	dash_direction = dir
	dash_timer = dash_duration
	modulate = Color(0.3, 0.0, 0.5, 0.7)
	AudioManager.play_sfx("sword_swing")
	
	# Create shadow trail
	_create_shadow_trail()
	
	await get_tree().create_timer(dash_duration).timeout
	if not is_dead:
		is_dashing = false
		modulate = Color.WHITE

func _create_shadow_trail():
	# Simple afterimage effect
	var trail = ColorRect.new()
	trail.size = Vector2(32, 48)
	trail.position = global_position - Vector2(16, 24)
	trail.color = Color(0.3, 0.0, 0.5, 0.4)
	get_tree().current_scene.add_child(trail)
	
	var tween = trail.create_tween()
	tween.tween_property(trail, "color:a", 0.0, 0.5)
	tween.tween_callback(trail.queue_free)

func _start_attack():
	is_attacking = true
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	attack_hitbox.disabled = false
	sprite.play("attack")
	AudioManager.play_random_pitch("sword_swing", 0.3, 0.5)
	HitStop.trigger_heavy()

func _end_attack():
	is_attacking = false
	attack_hitbox.disabled = true
	velocity = Vector2.ZERO
	sprite.play("idle")

func show_damage_number(amount: int, is_heal := false, is_critical := false):
	var dn = damage_number_scene.instantiate() as Node2D
	dn.global_position = global_position + Vector2(0, -24)
	get_tree().current_scene.add_child(dn)
	if is_heal:
		dn.setup_heal(amount)
	else:
		dn.setup(amount, Color.RED, is_critical)

func take_damage(amount: int, is_critical := false):
	if is_dead:
		return
	
	# Phase 2: 20% damage reduction
	if phase == 2:
		amount = int(amount * 0.8)
	
	health -= amount
	_update_label()
	show_damage_number(amount, false, is_critical)
	AudioManager.play_sfx("player_hurt")
	
	ScreenShake.shake(2.0, 0.15)
	# Hit flash — white on crit, red on normal (boss gets extra shake on crit)
	if is_critical:
		modulate = Color.WHITE
		ScreenShake.shake(4.0, 0.25)
		await get_tree().create_timer(0.08).timeout
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = Color.WHITE
	
	if health <= 0:
		_die()

func _update_label():
	if label:
		var phase_str = " P2" if phase == 2 else ""
		label.text = "SHADOW LORD%s\nHP:%d/%d" % [phase_str, health, max_health]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	# Epic boss death
	ScreenShake.shake(8.0, 0.8)
	
	# Phase through death animation
	modulate = Color(0.5, 0.0, 0.8)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.8)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	
	AudioManager.play_sfx("level_complete")
	await tween.finished
	queue_free()

func _on_attack_hitbox_body_entered(body):
	if body.has_method("take_damage") and body != self:
		body.take_damage(attack_damage)
		HitStop.trigger_heavy()

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body):
	if body.is_in_group("player") and body == player:
		player = null