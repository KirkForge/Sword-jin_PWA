extends CanvasLayer
# AchievementPopup — Toast notification that slides in when an achievement unlocks
# v0.71 — Shows icon + name + description, auto-dismisses after 3 seconds

var queue: Array[Dictionary] = []
var is_showing := false

@onready var panel = $Panel
@onready var icon_label = $Panel/HBoxContainer/IconLabel
@onready var name_label = $Panel/HBoxContainer/VBoxContainer/NameLabel
@onready var desc_label = $Panel/HBoxContainer/VBoxContainer/DescLabel

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect to GameState achievement signal
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(ach_id: String):
	show_achievement(ach_id)

func show_achievement(ach_id: String):
	var ach = GameState.ACHIEVEMENTS.get(ach_id, {})
	if ach.is_empty():
		return
	queue.append({"icon": ach.get("icon", "🏆"), "name": ach.get("name", "???"), "desc": ach.get("desc", "")})
	if not is_showing:
		_show_next()

func _show_next():
	if queue.is_empty():
		is_showing = false
		visible = false
		return
	
	is_showing = true
	var item = queue.pop_front()
	
	icon_label.text = item["icon"]
	name_label.text = item["name"]
	desc_label.text = item["desc"]
	
	# Slide in from top
	visible = true
	panel.position.y = -80
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "position:y", 10, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.5)
	tween.tween_property(panel, "position:y", -80, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(_show_next)

func _process(_delta):
	# Check for new achievements each frame
	pass