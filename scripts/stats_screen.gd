extends CanvasLayer
# StatsScreen — Player progress dashboard (stars, streak, bestiary, achievements)
# v0.71 — All retention stats in one view

signal back_pressed

@onready var streak_label = $MarginContainer/VBoxContainer/StreakLabel
@onready var rested_label = $MarginContainer/VBoxContainer/RestedLabel
@onready var progress_label = $MarginContainer/VBoxContainer/ProgressLabel
@onready var stars_label = $MarginContainer/VBoxContainer/StarsLabel
@onready var gold_label = $MarginContainer/VBoxContainer/GoldLabel
@onready var level_label = $MarginContainer/VBoxContainer/LevelLabel
@onready var weapons_label = $MarginContainer/VBoxContainer/WeaponsLabel
@onready var bestiary_label = $MarginContainer/VBoxContainer/BestiaryLabel
@onready var achievements_label = $MarginContainer/VBoxContainer/AchievementsLabel
@onready var back_btn = $MarginContainer/VBoxContainer/HBoxContainer/BackButton
@onready var bestiary_btn = $MarginContainer/VBoxContainer/HBoxContainer/BestiaryButton
@onready var achievements_btn = $MarginContainer/VBoxContainer/HBoxContainer/AchievementsButton

func _ready():
	visible = false
	back_btn.pressed.connect(_on_back)
	bestiary_btn.pressed.connect(_on_bestiary)
	achievements_btn.pressed.connect(_on_achievements)

func show_stats():
	visible = true
	get_tree().paused = true
	_refresh()

func hide_stats():
	visible = false
	get_tree().paused = false

func _refresh():
	# Daily Streak
	var streak = GameState.daily_streak
	var streak_gold = GameState.STREAK_GOLD_BASE + (streak - 1) * GameState.STREAK_GOLD_INCREMENT
	streak_label.text = "📅 Daily Streak: %d days (+%d gold/day)" % [streak, streak_gold]
	if streak >= 7:
		streak_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	elif streak >= 3:
		streak_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	else:
		streak_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Rested XP
	if GameState.rested_chapters_remaining > 0:
		rested_label.text = "🔥 RESTED XP: 2× bonus for %d more chapters! (Pool: %d XP)" % [GameState.rested_chapters_remaining, GameState.rested_xp_pool]
		rested_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	else:
		var hours_needed = GameState.RESTED_XP_MAX_HOURS
		rested_label.text = "💤 Rested XP: Come back in %d+ hours for 2× bonus" % hours_needed
		rested_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	# Progress
	var total = ChapterDatabase.chapters.size()
	var done = GameState.completed_chapters.size()
	progress_label.text = "📜 Progress: %d / %d chapters (%.0f%%)" % [done, total, (float(done) / float(total) * 100) if total > 0 else 0]
	
	# Stars
	var total_stars = GameState.get_total_stars()
	var max_stars = GameState.get_max_possible_stars()
	stars_label.text = "⭐ Stars: %d / %d" % [total_stars, max_stars]
	
	# Gold
	gold_label.text = "💰 Gold: %d" % GameState.player_gold
	
	# Level
	var xp_needed = GameState.get_level_xp_requirement(GameState.player_level)
	level_label.text = "⭐ Level %d (%d / %d XP)" % [GameState.player_level, GameState.player_xp, xp_needed]
	
	# Weapons
	var wep_count = GameState.unlocked_weapons.size()
	var wep_total = GameState.WEAPON_STATS.size()
	weapons_label.text = "🗡 Weapons: %d / %d" % [wep_count, wep_total]
	
	# Bestiary
	var bio_count = GameState.get_bestiary_unlock_count()
	var bio_total = GameState.BESTIARY_LORE.size()
	bestiary_label.text = "📖 Bestiary: %d / %d discovered" % [bio_count, bio_total]
	
	# Achievements
	var ach_count = GameState.unlocked_achievements.size()
	var ach_total = GameState.ACHIEVEMENTS.size()
	achievements_label.text = "🏆 Achievements: %d / %d" % [ach_count, ach_total]

func _on_back():
	hide_stats()
	back_pressed.emit()

func _on_bestiary():
	# Navigate to bestiary screen
	var bestiary_scene = load("res://scenes/ui/bestiary_screen.tscn")
	if bestiary_scene:
		var bestiary = bestiary_scene.instantiate()
		get_tree().root.add_child(bestiary)
		bestiary.show_bestiary()
		bestiary.back_pressed.connect(_on_subscreen_back)

func _on_achievements():
	var ach_scene = load("res://scenes/ui/achievements_screen.tscn")
	if ach_scene:
		var ach = ach_scene.instantiate()
		get_tree().root.add_child(ach)
		ach.show_achievements()
		ach.back_pressed.connect(_on_subscreen_back)

func _on_subscreen_back():
	_refresh()