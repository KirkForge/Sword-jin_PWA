extends CharacterBody2D
## Golem — slow heavy construct with damage-reducing armor.
## Deals massive damage but attacks slowly. Stuns briefly after each hit.

var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

@export var max_health := 180
@export var speed := 40.0
@export var detection_range := 350.0
@export var attack_range := 45.0
@export var attack_damage := 30
@export var attack_cooldown := 2.5
@export var attack_duration := 0.8
@export var armor := 10  # Flat damage reduction

var health: int
var player: Node2D = null
var is_attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var is_dead := false

# Golem mechanics
var stun_timer := 0.0
const STUN_DURATION := 0.5

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
	
	# Stun recovery
	if stun_timer > 0:
		stun_timer -= delta
		velocity = Vector2.ZERO
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
	
	# Face player slowly
	if to_player.x > 0:
		sprite.scale.x = abs(sprite.scale.x)
	elif to_player.x < 0:
		sprite.scale.x = -abs(sprite.scale.x)
	
	# Chase — slow but steady
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

func _start_attack():
	is_attacking = true
	attack_timer = attack_duration
	cooldown_timer = attack_duration + attack_cooldown
	attack_hitbox.disabled = false
	sprite.play("attack")
	AudioManager.play_random_pitch("captain_charge", 0.5, 0.7)
	
	# Ground pound — heavy screen shake for telegraph
	ScreenShake.shake(4.0, 0.5)
	
	if player:
		velocity = Vector2.ZERO
	print("GOLEM SMASH!")

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
	
	# Armor reduces damage
	var actual_damage = max(1, amount - armor)
	health -= actual_damage
	stun_timer = STUN_DURATION  # Brief stun on hit
	
	_update_label()
	show_damage_number(actual_damage)
	AudioManager.play_random_pitch("shield_block", 0.4, 0.6)
	
	modulate = Color(0.7, 0.5, 0.3)
	await get_tree().create_timer(0.15).timeout
	if not is_dead:
		modulate = Color.WHITE
	
	if health <= 0:
		_die()

func _update_label():
	if label:
		label.text = "GOLEM\nHP:%d/%d\n🛡%d" % [health, max_health, armor]
	if health_bar:
		health_bar.update_health(health, max_health)

func _die():
	is_dead = true
	ScreenShake.shake(8.0, 0.8)
	HitStop.trigger_heavy()
	modulate = Color(0.4, 0.3, 0.2)
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("disabled", true)
	
	# Golem crumbles slowly
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.5, 0.3), 1.5)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.5)
	await tween.finished
	queue_free()

func _on_attack_hitbox_body_entered(body):
	if body.has_method("take_damage") and body != self:
		body.take_damage(attack_damage)
		HitStop.trigger_heavy()
		ScreenShake.shake(3.0, 0.3)

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body):
	if body.is_in_group("player") and body == player:
		player = null
