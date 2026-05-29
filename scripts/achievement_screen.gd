extends CanvasLayer
# AchievementScreen — Badge collection with categories and unlock status
# v0.77 — Achievement badges with progress tracking

signal closed

@onready var bg_panel = $Panel
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var progress_label = $Panel/VBoxContainer/ProgressLabel
@onready var category_tabs = $Panel/VBoxContainer/HBoxContainer/CategoryTabs
@onready var badge_list = $Panel/VBoxContainer/HBoxContainer/BadgeList
@onready var detail_panel = $Panel/VBoxContainer/HBoxContainer/DetailPanel
@onready var close_btn = $Panel/VBoxContainer/CloseButton

var current_category: String = "Combat"
var badge_buttons: Dictionary = {}

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_on_close)

func show_achievements():
	get_tree().paused = true
	visible = true
	current_category = "Combat"
	_build_category_tabs()
	_show_category("Combat")
	_update_progress()

func hide_achievements():
	visible = false
	get_tree().paused = false
	closed.emit()

func _on_close():
	hide_achievements()

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		hide_achievements()

func _build_category_tabs():
	for child in category_tabs.get_children():
		child.queue_free()
	
	var categories := ["Combat", "Exploration", "Collection", "Mastery"]
	var icons := {"Combat": "🗡", "Exploration": "🗺", "Collection": "⚔", "Mastery": "💎"}
	
	for cat in categories:
		var btn := Button.new()
		btn.text = "  %s %s  " % [icons.get(cat, ""), cat]
		btn.custom_minimum_size = Vector2(100, 32)
		btn.tooltip_text = cat
		btn.pressed.connect(_show_category.bind(cat))
		category_tabs.add_child(btn)

func _show_category(category: String):
	current_category = category
	_populate_badge_list(category)
	_show_empty_detail()

func _populate_badge_list(category: String):
	for child in badge_list.get_children():
		child.queue_free()
	badge_buttons.clear()
	
	var categories_data := GameState.get_achievements_by_category()
	var badges: Array = categories_data.get(category, [])
	
	for badge in badges:
		var btn := Button.new()
		var icon: String = badge.get("icon", "?")
		var name: String = badge.get("name", "???")
		var unlocked: bool = badge.get("unlocked", false)
		
		if unlocked:
			btn.text = "  %s %s  " % [icon, name]
		else:
			btn.text = "  🔒 ???  "
		
		btn.custom_minimum_size = Vector2(160, 36)
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		
		if unlocked:
			btn.modulate = Color(1.0, 1.0, 1.0)
		else:
			btn.modulate = Color(0.5, 0.5, 0.5)
		
		var badge_id: String = badge.get("id", "")
		btn.pressed.connect(_on_badge_selected.bind(badge_id))
		badge_list.add_child(btn)
		badge_buttons[badge_id] = btn

func _on_badge_selected(badge_id: String):
	var categories_data := GameState.get_achievements_by_category()
	var all_badges: Array = []
	for cat in categories_data.values():
		all_badges.append_array(cat)
	
	var badge_data: Dictionary = {}
	for b in all_badges:
		if b.get("id", "") == badge_id:
			badge_data = b
			break
	
	if badge_data.is_empty():
		_show_empty_detail()
		return
	
	_show_badge_detail(badge_data)

func _show_badge_detail(badge: Dictionary):
	for child in detail_panel.get_children():
		child.queue_free()
	
	var unlocked: bool = badge.get("unlocked", false)
	var icon: String = badge.get("icon", "?")
	var name: String = badge.get("name", "???")
	var desc: String = badge.get("description", "")
	var category: String = badge.get("category", "")
	
	# Icon + Name
	var title := Label.new()
	if unlocked:
		title.text = "%s  %s" % [icon, name]
		title.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))  # Gold
	else:
		title.text = "🔒  %s" % name
		title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	title.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(title)
	
	# Category tag
	var cat_label := Label.new()
	cat_label.text = "[%s]" % category
	cat_label.add_theme_font_size_override("font_size", 11)
	cat_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	detail_panel.add_child(cat_label)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	detail_panel.add_child(spacer)
	
	# Description
	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	else:
		desc_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	detail_panel.add_child(desc_label)
	
	# Unlock time
	if unlocked:
		var time_label := Label.new()
		var unlock_time: float = badge.get("unlock_time", 0.0)
		if unlock_time > 0:
			var datetime := Time.get_datetime_string_from_unix_time(int(unlock_time))
			time_label.text = "Unlocked: %s" % datetime.split(" ")[0]
		else:
			time_label.text = "Unlocked ✓"
		time_label.add_theme_font_size_override("font_size", 10)
		time_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		detail_panel.add_child(time_label)

func _show_empty_detail():
	for child in detail_panel.get_children():
		child.queue_free()
	
	var hint := Label.new()
	hint.text = "Select a badge to view details"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	detail_panel.add_child(hint)

func _update_progress():
	var progress := GameState.get_achievement_progress()
	progress_label.text = "🏆 %d / %d Badges (%.0f%%)" % [
		progress.unlocked, progress.total, progress.percentage
	]
	progress_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))