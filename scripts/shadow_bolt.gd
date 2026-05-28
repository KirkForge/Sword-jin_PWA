extends Area2D
# ShadowBolt — Homing projectile fired by Dark Mages
# Travels toward player position, moderate speed, despawns after 3 seconds

var direction := Vector2.RIGHT
var speed := 180.0
var damage := 22
var lifetime := 3.0
var age := 0.0

@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $CollisionShape2D

func _ready():
	# Disable hitbox until moving
	hitbox.set_deferred("disabled", false)
	if sprite:
		sprite.play("fly")
	# Rotate to face direction
	rotation = direction.angle()

func _physics_process(delta):
	age += delta
	if age >= lifetime:
		queue_free()
		return
	
	position += direction * speed * delta
	
	# Slight homing — adjust direction toward player
	var player = get_tree().get_first_node_in_group("player")
	if player and not player.is_dead:
		var to_player = (player.global_position - global_position).normalized()
		direction = direction.lerp(to_player, 0.03).normalized()
		rotation = direction.angle()

func _on_body_entered(body):
	if body.has_method("take_damage") and body.is_in_group("player"):
		body.take_damage(damage)
		HitStop.trigger_light()
		queue_free()
	elif not body.is_in_group("enemy"):
		# Hit a wall or obstacle
		queue_free()

func _on_area_entered(_area):
	# Hit another area (like player hitbox)
	pass