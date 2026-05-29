extends Control
# TitleScreen — Entry point: start, continue, chapter select
# v0.77 — Added achievement screen button + toast + progress display

@onready var start_btn = $CenterContainer/VBoxContainer/StartButton
@onready var continue_btn = $CenterContainer/VBoxContainer/ContinueButton
@onready var select_btn = $CenterContainer/VBoxContainer/SelectButton
@onready var bestiary_btn = $CenterContainer/VBoxContainer/BestiaryButton
@onready var achievement_btn = $CenterContainer/VBoxContainer/AchievementButton
@onready var stars_label = $CenterContainer/VBoxContainer/StarsLabel
@onready var collection_label = $CenterContainer/VBoxContainer/CollectionLabel
@onready var bestiary_label = $CenterContainer/VBoxContainer/BestiaryLabel
@onready var achievement_label = $CenterContainer/VBoxContainer/AchievementLabel
@onready var chm = $ChapterManager

var bestiary_screen: CanvasLayer = null
var achievement_screen: CanvasLayer = null
var achievement_toast: CanvasLayer = null

func _ready():
	start_btn.grab_focus()
	
	# Start title music
	AudioManager.play_bgm("bgm_title", 1.0, true)
	
	# Disable continue if no progress
	if GameState.completed_chapters.is_empty():
		continue_btn.disabled = true
		continue_btn.modulate = Color.GRAY
	
	# Show star progress
	var total_stars := GameState.get_total_stars()
	var max_stars := GameState.get_max_possible_stars()
	if total_stars > 0:
		stars_label.text = "⭐ %d / %d" % [total_stars, max_stars]
		stars_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
	else:
		stars_label.text = ""
	
	# Show weapon collection progress
	if collection_label:
		var cp := GameState.get_collection_progress()
		if cp.collected > 0:
			collection_label.text = "⚔ %d / %d Weapons (%.0f%%)" % [cp.collected, cp.total, cp.percentage]
			collection_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		else:
			collection_label.text = ""
	
	# Show bestiary progress
	if bestiary_label:
		var bp := GameState.get_bestiary_progress()
		if bp.discovered > 0:
			bestiary_label.text = "📖 %d / %d Enemies | %d Kills" % [bp.discovered, bp.total_types, bp.total_kills]
			bestiary_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		else:
			bestiary_label.text = ""
	
	# Show achievement progress
	if achievement_label:
		var ap := GameState.get_achievement_progress()
		if ap.unlocked > 0:
			achievement_label.text = "🏆 %d / %d Badges (%.0f%%)" % [ap.unlocked, ap.total, ap.percentage]
			achievement_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
		else:
			achievement_label.text = ""
	
	# Spawn achievement toast (listens for unlock signals globally)
	if achievement_toast == null:
		achievement_toast = load("res://scenes/ui/achievement_toast.tscn").instantiate()
		add_child(achievement_toast)
	
	# Run initial achievement check (catches any that should already be unlocked)
	GameState.check_achievements()

func _on_start_pressed():
	ChapterDatabase.set_current_chapter("act01_ch001")
	GameState.reset_chapter_state()
	AudioManager.play_sfx("ui_click")
	AudioManager.stop_bgm(0.5)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_continue_pressed():
	var id = _get_last_chapter()
	ChapterDatabase.set_current_chapter(id)
	GameState.reset_chapter_state()
	AudioManager.play_sfx("ui_click")
	AudioManager.stop_bgm(0.5)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_select_pressed():
	AudioManager.play_sfx("ui_click")
	chm.show_manager()
	# Hide our buttons while chapter manager is open
	$CenterContainer.visible = false
	# Re-show when back is pressed
	var back_btn = chm.get_node("MarginContainer/VBoxContainer/HBoxContainer/BackButton")
	back_btn.pressed.connect(_on_chapter_back, CONNECT_ONE_SHOT)

func _on_chapter_back():
	$CenterContainer.visible = true
	start_btn.grab_focus()

func _on_bestiary_pressed():
	AudioManager.play_sfx("ui_click")
	if bestiary_screen == null:
		bestiary_screen = load("res://scenes/ui/bestiary_screen.tscn").instantiate()
		bestiary_screen.closed.connect(_on_bestiary_closed)
		add_child(bestiary_screen)
	bestiary_screen.show_bestiary()

func _on_bestiary_closed():
	start_btn.grab_focus()

func _on_achievement_pressed():
	AudioManager.play_sfx("ui_click")
	if achievement_screen == null:
		achievement_screen = load("res://scenes/ui/achievement_screen.tscn").instantiate()
		achievement_screen.closed.connect(_on_achievement_closed)
		add_child(achievement_screen)
	achievement_screen.show_achievements()

func _on_achievement_closed():
	start_btn.grab_focus()

func _get_last_chapter() -> String:
	if GameState.completed_chapters.is_empty():
		return "act01_ch001"
	var last_id := ""
	var last_chapter := 0
	for id in GameState.completed_chapters:
		var ch = ChapterDatabase.chapters.get(id, {})
		var ch_num = ch.get("chapter", 0)
		if ch_num >= last_chapter:
			last_chapter = ch_num
			last_id = id
	var next = ChapterDatabase.chapters.get(last_id, {}).get("next_chapter", "")
	if not next.is_empty():
		return next
	return last_id