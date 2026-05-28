extends CanvasLayer
# AchievementsScreen — Trophy wall showing all 16 achievements
# v0.71 — Retention system: Accomplishment & Ownership drives

signal back_pressed

@onready var grid = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var stats_label = $MarginContainer/VBoxContainer/StatsLabel
@onready var back_btn = $MarginContainer/VBoxContainer/HBoxContainer/BackButton

func _ready():
	visible = false
	back_btn.pressed.connect(_on_back)

func show_achievements():
	visible = true
	get_tree().paused = true
	_refresh_list()

func hide_achievements():
	visible = false
	get_tree().paused = false

func _refresh_list():
	for child in grid.get_children():
		child.queue_free()
	
	var unlocked_count = GameState.unlocked_achievements.size()
	var total_count = GameState.ACHIEVEMENTS.size()
	stats_label.text = "🏆 %d / %d unlocked" % [unlocked_count, total_count]
	
	# Show all achievements (unlocked first, then locked)
	var sorted_ids = GameState.ACHIEVEMENTS.keys().duplicate()
	sorted_ids.sort_custom(func(a, b):
		var a_unlocked = GameState.unlocked_achievements.has(a)
		var b_unlocked = GameState.unlocked_achievements.has(b)
		if a_unlocked and not b_unlocked: return true
		if b_unlocked and not a_unlocked: return false
		return a < b
	)
	
	for id in sorted_ids:
		var ach = GameState.ACHIEVEMENTS[id]
		var is_unlocked = GameState.unlocked_achievements.has(id)
		
		var btn = Button.new()
		if is_unlocked:
			btn.text = "%s %s" % [ach["icon"], ach["name"]]
			btn.modulate = Color(1.0, 0.84, 0.0)  # Gold
			btn.tooltip_text = ach["desc"]
		else:
			btn.text = "🔒 ???"
			btn.modulate = Color(0.4, 0.4, 0.4)
			btn.tooltip_text = "Not yet unlocked"
		btn.custom_minimum_size = Vector2(200, 36)
		btn.disabled = not is_unlocked
		grid.add_child(btn)

func _on_back():
	hide_achievements()
	back_pressed.emit()