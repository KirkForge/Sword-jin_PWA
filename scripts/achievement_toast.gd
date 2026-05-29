extends CanvasLayer
# AchievementToast — Non-blocking notification when an achievement unlocks
# v0.77 — Slides in from top, shows icon + name, auto-fades after 3s

var queue: Array[Dictionary] = []
var is_showing := false

@onready var toast_panel = $Panel
@onready var icon_label = $Panel/HBoxContainer/IconLabel
@onready var name_label = $Panel/HBoxContainer/NameLabel
@onready var desc_label = $Panel/HBoxContainer/DescLabel

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(achievement_id: String, achievement_data: Dictionary):
	queue.append(achievement_data)
	if not is_showing:
		_show_next()

func _show_next():
	if queue.is_empty():
		is_showing = false
		return
	
	is_showing = true
	var data: Dictionary = queue.pop_front()
	
	icon_label.text = data.get("icon", "🏆")
	name_label.text = data.get("name", "???")
	desc_label.text = data.get("description", "")
	
	# Slide in from top
	visible = true
	toast_panel.position = Vector2(toast_panel.position.x, -60)
	modulate = Color.TRANSPARENT
	
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	tween.parallel().tween_property(toast_panel, "position:y", 8.0, 0.3).set_ease(Tween.EASE_OUT)
	
	# Hold for 3 seconds
	tween.tween_interval(3.0)
	
	# Fade out
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(_on_toast_done)

func _on_toast_done():
	visible = false
	_show_next()