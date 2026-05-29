extends Node
## CritEffect — Cinematic critical hit effects
## Triggers slow-motion, camera zoom, flash, and particle burst on crit

class_name CritEffect

# Slow-motion settings
const SLOWMO_SCALE := 0.2
const SLOWMO_DURATION := 0.3
const SLOWMO_RAMP_BACK := 0.2  # Time to ramp back to 1.0

# Camera zoom
const ZOOM_TARGET := Vector2(1.15, 1.15)
const ZOOM_DURATION := 0.15

var _is_slowmo := false

func trigger_crit(pos: Vector2):
	"""Trigger the full cinematic crit sequence at the given world position."""
	# 1. Slow-motion
	_trigger_slowmo()
	
	# 2. Camera zoom (find main camera)
	_zoom_camera()
	
	# 3. Screen shake + heavy hitstop
	ScreenShake.shake(6.0, 0.4)
	HitStop.trigger_heavy()
	
	# 4. Spawn crit damage number (golden, larger)
	_spawn_crit_number(pos)
	
	# 5. Spawn spark particles
	_spawn_sparks(pos)
	
	# 6. Flash the screen briefly white
	_flash_screen()

func _trigger_slowmo():
	if _is_slowmo:
		return
	_is_slowmo = true
	Engine.time_scale = SLOWMO_SCALE
	
	# Hold slow-mo, then ramp back
	await get_tree().create_timer(SLOWMO_DURATION, true, false, true).timeout
	
	# Ramp back to normal speed
	var tween = create_tween()
	tween.tween_method(_set_time_scale, SLOWMO_SCALE, 1.0, SLOWMO_RAMP_BACK)
	tween.tween_callback(func(): _is_slowmo = false)

func _set_time_scale(val: float):
	Engine.time_scale = val

func _zoom_camera():
	var cam = _get_camera()
	if cam == null:
		return
	
	var orig_zoom = cam.zoom
	var tween = create_tween().set_parallel()
	tween.tween_property(cam, "zoom", ZOOM_TARGET, ZOOM_DURATION).set_ease(Tween.EASE_OUT)
	
	# Zoom back after slowmo
	await get_tree().create_timer(SLOWMO_DURATION + 0.1, true, false, true).timeout
	var tween_back = create_tween()
	tween_back.tween_property(cam, "zoom", orig_zoom, 0.3).set_ease(Tween.EASE_IN)

func _get_camera() -> Camera2D:
	var cameras = get_tree().get_nodes_in_group("main_camera")
	if cameras.size() > 0:
		return cameras[0]
	return null

func _spawn_crit_number(pos: Vector2):
	"""Spawn a large golden CRIT! damage number."""
	var label_node := Label.new()
	label_node.text = "CRIT!"
	label_node.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))  # Gold
	label_node.add_theme_font_size_override("font_size", 20)
	label_node.global_position = pos + Vector2(-20, -48)
	label_node.z_index = 100
	get_tree().current_scene.add_child(label_node)
	
	var tween := label_node.create_tween().set_parallel()
	tween.tween_property(label_node, "position:y", label_node.position.y - 50, 1.2)
	tween.tween_property(label_node, "modulate:a", 0.0, 1.0).set_delay(0.5)
	# Scale pulse
	tween.tween_property(label_node, "scale", Vector2(1.3, 1.3), 0.15)
	tween.chain().tween_property(label_node, "scale", Vector2(1.0, 1.0), 0.2)
	tween.chain().tween_callback(label_node.queue_free)

func _spawn_sparks(pos: Vector2):
	"""Spawn burst of spark particles at crit position."""
	for i in range(8):
		var spark := ColorRect.new()
		spark.size = Vector2(3, 3)
		spark.color = Color(1.0, 0.9, 0.3, 1.0)  # Gold spark
		spark.global_position = pos
		spark.z_index = 99
		get_tree().current_scene.add_child(spark)
		
		var angle = randf() * TAU
		var dist = randf_range(20, 50)
		var target = pos + Vector2(cos(angle), sin(angle)) * dist
		
		var tween := spark.create_tween().set_parallel()
		tween.tween_property(spark, "position", target, 0.4)
		tween.tween_property(spark, "modulate:a", 0.0, 0.4).set_delay(0.1)
		tween.tween_property(spark, "scale", Vector2(0.1, 0.1), 0.4)
		tween.chain().tween_callback(spark.queue_free)

func _flash_screen():
	"""Brief white flash overlay."""
	var flash := ColorRect.new()
	flash.size = Vector2(640, 360)
	flash.color = Color(1, 1, 1, 0.3)
	flash.z_index = 50
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(flash)
	
	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)