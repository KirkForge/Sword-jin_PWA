extends CanvasLayer
# VictoryScreen — Chapter complete overlay
# v0.71 — Stars, loot drops, rested XP indicator

signal next_chapter_pressed
signal chapter_select_pressed
signal title_screen_pressed

@onready var panel = $Panel
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var xp_label = $Panel/VBoxContainer/XPLabel
@onready var gold_label = $Panel/VBoxContainer/GoldLabel
@onready var reward_label = $Panel/VBoxContainer/RewardLabel
@onready var continue_btn = $Panel/VBoxContainer/HBoxContainer/ContinueButton
@onready var select_btn = $Panel/VBoxContainer/HBoxContainer/SelectButton
@onready var title_btn = $Panel/VBoxContainer/HBoxContainer/TitleButton
@onready var animation = $AnimationPlayer

var _has_next_chapter: bool = false
var _stars: int = 1
var _loot: Dictionary = {}

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Run while paused
	continue_btn.pressed.connect(_on_continue)
	select_btn.pressed.connect(_on_select)
	title_btn.pressed.connect(_on_title)
	title_btn.visible = false  # Hidden by default, shown for final chapter

func show_victory(chapter_title: String, xp_gained: int, gold_gained: int = 0, reward_weapon: String = "", reward_skill: String = "", stars: int = 1, loot: Dictionary = {}):
	_stars = stars
	_loot = loot
	
	# Pause the game
	get_tree().paused = true
	
	# Title
	title_label.text = "VICTORY: " + chapter_title
	
	# Stars display
	var star_str = ""
	for i in range(3):
		if i < stars:
			star_str += "⭐"
		else:
			star_str += "☆"
	
	# XP line (with rested bonus indicator)
	var xp_mult = GameState.get_xp_multiplier()
	if xp_mult > 1.0:
		xp_label.text = "🔥 XP Gained: %d (×%.0f Rested!)" % [xp_gained, xp_mult]
		xp_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))  # Orange
	else:
		xp_label.text = "XP Gained: " + str(xp_gained)
	
	# Gold line + loot tier
	var gold_total = gold_gained + loot.get("gold", 0)
	gold_label.text = "Gold Earned: " + str(gold_total)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))  # #FFD700
	
	# Loot tier display
	var loot_parts: Array[String] = []
	if loot.has("tier") and loot["tier"] != "common":
		var tier_colors = {"uncommon": "#1eff00", "rare": "#0070dd", "legendary": "#ff8000"}
		var color = tier_colors.get(loot["tier"], "#ffffff")
		loot_parts.append("[color=%s]%s loot![/color]" % [color, loot["tier"].capitalize()])
	
	# Reward line
	var reward_parts: Array[String] = []
	if not reward_weapon.is_empty():
		reward_parts.append("Weapon: " + _format_name(reward_weapon))
	if not reward_skill.is_empty():
		reward_parts.append("Skill: " + _format_name(reward_skill))
	
	var display_parts = reward_parts + loot_parts
	if display_parts.is_empty():
		reward_label.text = star_str
		reward_label.visible = true
	else:
		reward_label.text = star_str + "\nUnlocked: " + " | ".join(display_parts)
		reward_label.visible = true
	
	# Show / hide continue based on whether there's a next chapter
	continue_btn.visible = _has_next_chapter
	
	# Act Complete state for final chapter
	if not _has_next_chapter:
		title_label.text = "ACT COMPLETE"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))  # Gold #FFD700
		title_btn.visible = true
	else:
		title_label.add_theme_color_override("font_color", Color.WHITE)
		title_btn.visible = false
	
	# Fade in
	visible = true
	modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color.WHITE, 0.4)
	
	AudioManager.play_sfx("level_complete")

func _format_name(snake_case: String) -> String:
	var parts = snake_case.split("_")
	var out: Array[String] = []
	for p in parts:
		out.append(p.capitalize())
	return " ".join(out)

func _on_continue():
	AudioManager.play_sfx("ui_click")
	hide_victory()
	next_chapter_pressed.emit()

func _on_select():
	AudioManager.play_sfx("ui_click")
	hide_victory()
	chapter_select_pressed.emit()

func _on_title():
	AudioManager.play_sfx("ui_click")
	hide_victory()
	title_screen_pressed.emit()

func hide_victory():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	await tween.finished
	visible = false
	get_tree().paused = false