extends CanvasLayer
# DailyChallengeScreen — Shows today's challenge details + modifiers
# v0.79 — Daily challenge with modifiers and bonus rewards

signal closed()

@onready var title_label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var chapter_label = $Panel/MarginContainer/VBoxContainer/ChapterLabel
@onready var modifiers_container = $Panel/MarginContainer/VBoxContainer/ModifiersContainer
@onready var reward_label = $Panel/MarginContainer/VBoxContainer/RewardLabel
@onready var status_label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var start_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/StartButton
@onready var back_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/BackButton
@onready var stats_label = $Panel/MarginContainer/VBoxContainer/StatsLabel

func _ready():
	visible = false
	
	# Daily challenge background art
	var bg_path = "res://assets/art/screens/daily_challenge_bg.png"
	if ResourceLoader.exists(bg_path):
		var tex = load(bg_path)
		if tex:
			var bg_art = TextureRect.new()
			bg_art.name = "DailyBgArt"
			bg_art.texture = tex
			bg_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg_art.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg_art.modulate = Color(1, 1, 1, 0.15)
			bg_art.z_index = -1
			var p = get_node_or_null("Panel")
			if p:
				p.add_child(bg_art)
				p.move_child(bg_art, 0)

func show_challenge():
	visible = true
	_refresh()
	back_button.grab_focus()

func _refresh():
	var challenge := GameState.get_daily_challenge()
	var chapter_id: String = challenge.get("chapter_id", "act01_ch001")
	var modifiers: Array = challenge.get("modifiers", [])
	var bonus_gold: int = challenge.get("bonus_gold", 50)
	var completed: bool = challenge.get("completed", false)
	
	# Title
	title_label.text = "⚔ Daily Challenge"
	
	# Chapter name
	var ch_data := ChapterDatabase.chapters.get(chapter_id, {})
	var ch_title := ch_data.get("title", chapter_id)
	chapter_label.text = "📍 %s" % ch_title
	
	# Modifiers
	for child in modifiers_container.get_children():
		child.queue_free()
	
	for mod_id in modifiers:
		var mod_data := GameState.DAILY_CHALLENGE_MODIFIERS.get(mod_id, {})
		var label := Label.new()
		label.text = "%s %s — %s" % [
			mod_data.get("icon", "?"),
			mod_data.get("label", mod_id),
			mod_data.get("description", "")
		]
		label.add_theme_color_override("font_color", Color.from_string(mod_data.get("color", "#FFFFFF"), Color.WHITE))
		label.add_theme_font_size_override("font_size", 14)
		modifiers_container.add_child(label)
	
	# Reward
	reward_label.text = "💰 Bonus: +%d gold" % bonus_gold
	
	# Status
	if completed:
		status_label.text = "✅ Completed today!"
		status_label.add_theme_color_override("font_color", Color.GREEN)
		start_button.disabled = true
		start_button.text = "✅ Done"
	else:
		status_label.text = "⏳ Available"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
		start_button.disabled = false
		start_button.text = "⚔ Start Challenge"
	
	# Lifetime stats
	stats_label.text = "Completed: %d total | Best: %dg" % [
		GameState.daily_challenge_total_completed,
		GameState.daily_challenge_best_gold
	]

func _on_start_pressed():
	AudioManager.play_sfx("ui_click")
	visible = false
	
	# Load the challenge chapter with daily challenge flag
	var challenge := GameState.get_daily_challenge()
	var chapter_id: String = challenge.get("chapter_id", "act01_ch001")
	var modifiers: Array = challenge.get("modifiers", [])
	
	ChapterDatabase.set_current_chapter(chapter_id)
	GameState.reset_chapter_state()
	
	# Store active daily challenge modifiers for LevelManager to read
	GameState.active_daily_modifiers = modifiers
	GameState.is_daily_challenge_run = true
	
	AudioManager.stop_bgm(0.5)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed():
	AudioManager.play_sfx("ui_click")
	visible = false
	closed.emit()