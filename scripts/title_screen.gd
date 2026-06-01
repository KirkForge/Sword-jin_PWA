extends Control
# TitleScreen — Entry point: start, continue, chapter select
# v0.80 — Added leaderboard button

@onready var start_btn = $CenterContainer/VBoxContainer/StartButton
@onready var continue_btn = $CenterContainer/VBoxContainer/ContinueButton
@onready var select_btn = $CenterContainer/VBoxContainer/SelectButton
@onready var bestiary_btn = $CenterContainer/VBoxContainer/BestiaryButton
@onready var achievement_btn = $CenterContainer/VBoxContainer/AchievementButton
@onready var leaderboard_btn = $CenterContainer/VBoxContainer/LeaderboardButton
@onready var settings_btn = $CenterContainer/VBoxContainer/SettingsButton
@onready var stars_label = $CenterContainer/VBoxContainer/StarsLabel
@onready var collection_label = $CenterContainer/VBoxContainer/CollectionLabel
@onready var bestiary_label = $CenterContainer/VBoxContainer/BestiaryLabel
@onready var achievement_label = $CenterContainer/VBoxContainer/AchievementLabel
@onready var streak_label = $CenterContainer/VBoxContainer/StreakLabel
@onready var streak_claim_btn = $CenterContainer/VBoxContainer/StreakClaimButton
@onready var daily_challenge_btn = $CenterContainer/VBoxContainer/DailyChallengeButton
@onready var chm = $ChapterManager

var bestiary_screen: CanvasLayer = null
var achievement_screen: CanvasLayer = null
var achievement_toast: CanvasLayer = null
var daily_challenge_screen: CanvasLayer = null
var leaderboard_screen: CanvasLayer = null

func _ready():
	# Reset daily challenge runtime state when returning to title
	GameState.is_daily_challenge_run = false
	GameState.active_daily_modifiers = []
	
	# Title screen background art
	var title_bg_path = "res://assets/art/screens/title_bg.webp"
	if ResourceLoader.exists(title_bg_path):
		var tex = load(title_bg_path)
		if tex:
			var bg_art = TextureRect.new()
			bg_art.name = "TitleBgArt"
			bg_art.texture = tex
			bg_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg_art.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg_art.modulate = Color(1, 1, 1, 0.35)
			bg_art.z_index = -1
			add_child(bg_art)
			move_child(bg_art, 0)
	
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
	
	# Show daily streak
	if streak_label:
		var si := GameState.get_streak_info()
		if si.streak > 0:
			var fire := "🔥" if si.streak >= 3 else ""
			streak_label.text = "%s Day %d Streak" % [fire, si.streak]
			streak_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if si.streak >= 3 else Color(0.7, 0.7, 0.7))
		else:
			streak_label.text = ""
	
	# Show rested XP bonus
	var rested_info := GameState.get_rested_xp_info()
	if rested_info.has_bonus:
		stars_label.text = stars_label.text + "  😴 +%d" % rested_info.rested_xp if stars_label.text != "" else "😴 +%d Rested XP" % rested_info.rested_xp
	
	# Show streak claim button
	if streak_claim_btn:
		var si := GameState.get_streak_info()
		if not si.claimed_today and si.streak > 0:
			streak_claim_btn.text = "🔥 Claim Day %d Reward" % si.streak
			streak_claim_btn.visible = true
			streak_claim_btn.disabled = false
		else:
			streak_claim_btn.visible = false
	
	# Show daily challenge button
	if daily_challenge_btn:
		if GameState.is_daily_challenge_available():
			daily_challenge_btn.text = "⚔ Daily Challenge"
			daily_challenge_btn.modulate = Color(1.0, 0.843, 0.0)  # Gold highlight
		else:
			daily_challenge_btn.text = "✅ Daily Done"
			daily_challenge_btn.modulate = Color(0.5, 0.5, 0.5)
	
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

func _on_streak_claim_pressed():
	AudioManager.play_sfx("ui_click")
	var rewards := GameState.claim_daily_streak()
	if rewards.is_empty():
		return
	
	# Update UI
	if streak_claim_btn:
		streak_claim_btn.visible = false
	if streak_label:
		var si := GameState.get_streak_info()
		var fire := "🔥" if si.streak >= 3 else ""
		streak_label.text = "%s Day %d Streak ✅" % [fire, si.streak]
	
	# Show reward feedback via toast
	if achievement_toast == null:
		achievement_toast = load("res://scenes/ui/achievement_toast.tscn").instantiate()
		add_child(achievement_toast)func _on_daily_challenge_pressed():
	AudioManager.play_sfx("ui_click")
	if daily_challenge_screen == null:
		daily_challenge_screen = load("res://scenes/ui/daily_challenge_screen.tscn").instantiate()
		daily_challenge_screen.closed.connect(_on_daily_challenge_closed)
		add_child(daily_challenge_screen)
	daily_challenge_screen.show_challenge()

func _on_daily_challenge_closed():
	start_btn.grab_focus()
	# Refresh button state in case they started the challenge
	if daily_challenge_btn:
		if GameState.is_daily_challenge_available():
			daily_challenge_btn.text = "⚔ Daily Challenge"
			daily_challenge_btn.modulate = Color(1.0, 0.843, 0.0)
		else:
			daily_challenge_btn.text = "✅ Daily Done"
			daily_challenge_btn.modulate = Color(0.5, 0.5, 0.5)

func _on_leaderboard_pressed():
	AudioManager.play_sfx("ui_click")
	if leaderboard_screen == null:
		leaderboard_screen = load("res://scenes/ui/leaderboard_screen.tscn").instantiate()
		leaderboard_screen.back_pressed.connect(_on_leaderboard_closed)
		leaderboard_screen.ghost_run_requested.connect(_on_ghost_run_start)
		add_child(leaderboard_screen)
	leaderboard_screen.show_leaderboard()

func _on_leaderboard_closed():
	start_btn.grab_focus()

func _on_ghost_run_start(chapter_id: String):
	"""Start a chapter with ghost run enabled."""
	ChapterDatabase.set_current_chapter(chapter_id)
	GameState.reset_chapter_state()
	GameState.ghost_runs_enabled = true
	AudioManager.play_sfx("ui_click")
	AudioManager.stop_bgm(0.5)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

var settings_screen: Control = null

func _on_settings_pressed():
	AudioManager.play_sfx("ui_click")
	if settings_screen == null:
		settings_screen = load("res://scenes/ui/settings_screen.tscn").instantiate()
		settings_screen.close_btn.pressed.connect(_on_settings_closed)
		add_child(settings_screen)
	settings_screen.visible = true

func _on_settings_closed():
	start_btn.grab_focus()