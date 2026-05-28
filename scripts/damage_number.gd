extends Node2D
# DamageNumber — floats text up and fades out
# v0.73 — critical hits (gold, bigger), healing (green), XP (blue)

var _tween: Tween = null

func setup(amount: int, base_color := Color.RED, is_critical := false):
	# Random horizontal offset so overlapping numbers don't stack
	position.x += randf_range(-8, 8)
	
	# Find label child
	var label := $Label as Label
	if not label:
		return
	
	if is_critical:
		# Critical hit: gold color, bigger font, "!" suffix
		label.text = str(amount) + "!"
		label.add_theme_font_size_override("font_size", 20)
		label.self_modulate = Color.GOLD
		# Extra vertical pop for crits
		position.y -= 8
	else:
		label.text = str(amount)
		label.self_modulate = base_color
	
	# Animate: float up + fade out
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "position:y", position.y - 36, 0.9)
	
	if is_critical:
		# Crit: slight scale punch
		_tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_BACK)
		_tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	var fade = create_tween()
	fade.tween_property(label, "self_modulate:a", 0.0, 0.7).set_delay(0.2)
	fade.tween_callback(_cleanup)

func setup_heal(amount: int):
	setup(amount, Color.GREEN)

func setup_xp(amount: int):
	# XP gain — blue text, smaller
	position.x += randf_range(-4, 4)
	var label := $Label as Label
	if not label:
		return
	label.text = "+" + str(amount) + " XP"
	label.add_theme_font_size_override("font_size", 10)
	label.self_modulate = Color(0.4, 0.7, 1.0)  # Light blue
	
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "position:y", position.y - 28, 0.7)
	
	var fade = create_tween()
	fade.tween_property(label, "self_modulate:a", 0.0, 0.5).set_delay(0.3)
	fade.tween_callback(_cleanup)

func _cleanup():
	if is_instance_valid(self):
		queue_free()