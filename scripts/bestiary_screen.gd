extends CanvasLayer
# BestiaryScreen — Enemy catalog with kill counts, stats, and lore unlocks
# v0.76 — Bestiary system with milestone-based lore reveals

signal closed

@onready var bg_panel = $Panel
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var progress_label = $Panel/VBoxContainer/ProgressLabel
@onready var enemy_list = $Panel/VBoxContainer/HBoxContainer/EnemyList
@onready var detail_panel = $Panel/VBoxContainer/HBoxContainer/DetailPanel
@onready var close_btn = $Panel/VBoxContainer/CloseButton

var selected_enemy: String = ""
var enemy_buttons: Dictionary = {}

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_on_close)

func show_bestiary():
	get_tree().paused = true
	visible = true
	selected_enemy = ""
	_populate_enemy_list()
	_update_progress()
	_show_empty_detail()

func hide_bestiary():
	visible = false
	get_tree().paused = false
	closed.emit()

func _on_close():
	hide_bestiary()

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		hide_bestiary()

func _populate_enemy_list():
	# Clear existing
	for child in enemy_list.get_children():
		child.queue_free()
	enemy_buttons.clear()
	
	var enemy_order := ["skeleton", "skeleton_archer", "skeleton_captain", "ghost", "bandit", "assassin", "golem"]
	
	for enemy_type in enemy_order:
		var entry: Dictionary = GameState.get_bestiary_entry(enemy_type)
		var btn := Button.new()
		
		if entry.discovered:
			btn.text = "  " + entry.name + "  "
		else:
			btn.text = "  ???  "
		
		btn.custom_minimum_size = Vector2(160, 36)
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		
		# Color-code by discovery status
		if entry.discovered:
			var type_color := _type_color(entry.stats.get("type", ""))
			btn.add_theme_color_override("font_color", type_color)
		else:
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		
		btn.pressed.connect(_on_enemy_selected.bind(enemy_type))
		enemy_list.add_child(btn)
		enemy_buttons[enemy_type] = btn

func _on_enemy_selected(enemy_type: String):
	selected_enemy = enemy_type
	_show_enemy_detail(enemy_type)

func _show_enemy_detail(enemy_type: String):
	# Clear detail panel
	for child in detail_panel.get_children():
		child.queue_free()
	
	var entry: Dictionary = GameState.get_bestiary_entry(enemy_type)
	
	if not entry.discovered:
		# Undiscovered — show silhouette
		var title := Label.new()
		title.text = "???"
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		detail_panel.add_child(title)
		
		var hint := Label.new()
		hint.text = "Defeat this enemy to reveal its entry."
		hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		detail_panel.add_child(hint)
		return
	
	# Enemy name
	var name_label := Label.new()
	name_label.text = entry.name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", _type_color(entry.stats.get("type", "")))
	detail_panel.add_child(name_label)
	
	# Type badge
	var type_label := Label.new()
	type_label.text = "Type: " + entry.stats.get("type", "Unknown")
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_panel.add_child(type_label)
	
	# Description
	var desc_label := Label.new()
	desc_label.text = entry.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	detail_panel.add_child(desc_label)
	
	# Separator
	_add_separator()
	
	# Kill count
	var kill_label := Label.new()
	kill_label.text = "Kills: " + str(entry.kill_count)
	kill_label.add_theme_font_size_override("font_size", 16)
	kill_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	detail_panel.add_child(kill_label)
	
	# Stats
	var stats_label := Label.new()
	var stats: Dictionary = entry.stats
	stats_label.text = "HP: %s  |  DMG: %s  |  SPD: %s" % [
		str(stats.get("hp", "?")),
		str(stats.get("damage", "?")),
		str(stats.get("speed", "?")),
	]
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	detail_panel.add_child(stats_label)
	
	# Lore entries (milestone unlocks)
	var lore: Dictionary = GameState.BESTIARY.get(enemy_type, {}).get("lore", {})
	var unlocked: Array = entry.get("lore_unlocked", [])
	
	if lore.size() > 0:
		_add_separator()
		var lore_title := Label.new()
		lore_title.text = "━━━ Lore ━━━"
		lore_title.add_theme_font_size_override("font_size", 15)
		lore_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		detail_panel.add_child(lore_title)
		
		# Sort milestones
		var milestones: Array = lore.keys()
		milestones.sort()
		
		for milestone in milestones:
			var lore_text: String = lore[milestone]
			var is_unlocked: bool = milestone in unlocked
			
			var lore_entry := Label.new()
			if is_unlocked:
				lore_entry.text = "  [%d kills] %s" % [milestone, lore_text]
				lore_entry.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
			else:
				lore_entry.text = "  [%d kills] ████ ████ ████ ████]" % milestone
				lore_entry.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
			lore_entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lore_entry.add_theme_font_size_override("font_size", 13)
			detail_panel.add_child(lore_entry)

func _show_empty_detail():
	for child in detail_panel.get_children():
		child.queue_free()
	
	var hint := Label.new()
	hint.text = "Select an enemy to view details."
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font_size", 14)
	detail_panel.add_child(hint)

func _update_progress():
	var progress: Dictionary = GameState.get_bestiary_progress()
	progress_label.text = "%d/%d Discovered  |  %d Total Kills  |  %d/%d Lore" % [
		progress.discovered,
		progress.total_types,
		progress.total_kills,
		progress.lore_unlocked,
		progress.total_lore,
	]
	
	# Color based on completion percentage
	var pct: float = progress.percentage
	if pct >= 100:
		progress_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	elif pct >= 50:
		progress_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		progress_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

func _add_separator():
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	detail_panel.add_child(sep)

func _type_color(type_string: String) -> Color:
	if "Undead" in type_string:
		return Color(0.6, 0.8, 0.6)  # Greenish
	if "Spectral" in type_string:
		return Color(0.5, 0.7, 1.0)  # Ghostly blue
	if "Human" in type_string:
		return Color(1.0, 0.7, 0.5)  # Warm orange
	if "Construct" in type_string:
		return Color(0.8, 0.7, 0.5)  # Earthy brown
	return Color(0.85, 0.85, 0.85)  # Default light gray