extends Control
# TitleScreen — Entry point: start, continue, chapter select, stats
# v0.71 — Shows daily streak popup, rested XP status

@onready var start_btn = $CenterContainer/VBoxContainer/StartButton
@onready var continue_btn = $CenterContainer/VBoxContainer/ContinueButton
@onready var select_btn = $CenterContainer/VBoxContainer/SelectButton
@onready var stats_btn = $CenterContainer/VBoxContainer/StatsButton
@onready var daily_btn = $CenterContainer/VBoxContainer/DailyButton
@onready var chm = $ChapterManager

var stats_screen: CanvasLayer = null
var daily_challenge_screen: CanvasLayer = null
var streak_popup_shown := false

func _ready():
	start_btn.grab_focus()
	
	# Start title music
	AudioManager.play_bgm("bgm_title", 1.0, true)
	
	# Disable continue if no progress
	if GameState.completed_chapters.is_empty():
		continue_btn.disabled = true
		continue_btn.modulate = Color.GRAY
	
	# Highlight daily challenge if available
	if GameState.has_daily_challenge_available():
		daily_btn.text = "⚔️ DAILY CHALLENGE 🆕"
		daily_btn.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
	else:
		daily_btn.text = "📅 Daily Challenge ✅"
	
	# Show daily streak popup on first visit
	_show_streak_popup_if_needed()
	_print_login_status()

func _show_streak_popup_if_needed():
	if streak_popup_shown:
		return
	streak_popup_shown = true
	
	if GameState.daily_streak < 1:
		return
	
	var popup_scene = load("res://scenes/ui/streak_popup.tscn")
	if not popup_scene:
		return
	
	var reward = GameState.get_streak_reward_preview(GameState.daily_streak)
	var gold = reward.get("gold", 0)
	var potions = reward.get("potion", 0)
	var rested_active = GameState.rested_chapters_remaining > 0
	
	var popup = popup_scene.instantiate()
	add_child(popup)
	popup.show_popup(GameState.daily_streak, gold, potions, rested_active, GameState.rested_chapters_remaining)

func _print_login_status():
	if GameState.daily_streak > 1:
		print("📅 Daily Streak: %d days" % GameState.daily_streak)
	if GameState.rested_chapters_remaining > 0:
		print("🔥 Rested XP: 2× bonus active for %d chapters! (Pool: %d XP)" % [GameState.rested_chapters_remaining, GameState.rested_xp_pool])

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

func _on_stats_pressed():
	AudioManager.play_sfx("ui_click")
	if not stats_screen:
		var stats_scene = load("res://scenes/ui/stats_screen.tscn")
		stats_screen = stats_scene.instantiate()
		add_child(stats_screen)
		stats_screen.back_pressed.connect(_on_stats_back)
	stats_screen.show_stats()
	$CenterContainer.visible = false

func _on_daily_pressed():
	AudioManager.play_sfx("ui_click")
	if not daily_challenge_screen:
		var daily_scene = load("res://scenes/ui/daily_challenge_screen.tscn")
		daily_challenge_screen = daily_scene.instantiate()
		add_child(daily_challenge_screen)
		daily_challenge_screen.back_pressed.connect(_on_daily_back)
		daily_challenge_screen.challenge_accepted.connect(_on_daily_accept)
	daily_challenge_screen.show_challenge()
	$CenterContainer.visible = false

func _on_daily_back():
	$CenterContainer.visible = true
	start_btn.grab_focus()

func _on_daily_accept():
	# Load the daily challenge chapter with modifiers
	var challenge = GameState.get_daily_challenge()
	var base_id = challenge.get("base_chapter", "act01_ch001")
	ChapterDatabase.set_current_chapter(base_id)
	GameState.reset_chapter_state()
	# Store modifiers for level_manager to apply
	GameState.daily_modifiers = challenge.get("modifiers", {})
	AudioManager.play_sfx("ui_click")
	AudioManager.stop_bgm(0.5)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_stats_back():
	$CenterContainer.visible = true
	start_btn.grab_focus()

func _on_chapter_back():
	$CenterContainer.visible = true
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
