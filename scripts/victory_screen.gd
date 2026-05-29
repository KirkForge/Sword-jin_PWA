extends CanvasLayer
# VictoryScreen — Chapter complete overlay
# v0.81: Ghost time comparison on victory screen

signal next_chapter_pressed
signal chapter_select_pressed
signal title_screen_pressed

@onready var panel = $Panel
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var stars_label = $Panel/VBoxContainer/StarsLabel
@onready var xp_label = $Panel/VBoxContainer/XPLabel
@onready var gold_label = $Panel/VBoxContainer/GoldLabel
@onready var reward_label = $Panel/VBoxContainer/RewardLabel
@onready var loot_label = $Panel/VBoxContainer/LootLabel
@onready var ghost_label = $Panel/VBoxContainer/GhostLabel
@onready var continue_btn = $Panel/VBoxContainer/HBoxContainer/ContinueButton
@onready var select_btn = $Panel/VBoxContainer/HBoxContainer/SelectButton
@onready var title_btn = $Panel/VBoxContainer/HBoxContainer/TitleButton
@onready var animation = $AnimationPlayer

var _has_next_chapter: bool = false

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Run while paused
	continue_btn.pressed.connect(_on_continue)
	select_btn.pressed.connect(_on_select)
	title_btn.pressed.connect(_on_title)
	title_btn.visible = false  # Hidden by default, shown for final chapter

func show_victory(chapter_title: String, xp_gained: int, gold_gained: int = 0, reward_weapon: String = "", reward_skill: String = "", stars: int = 1, ghost_time: float = -1.0, completion_time: float = 0.0, rested_bonus: int = 0):
	# Pause the game
	get_tree().paused = true
	
	# Title
	title_label.text = "VICTORY: " + chapter_title
	
	# Stars display with criteria hint
	var star_text := ""
	for i in range(3):
		star_text += "⭐" if i < stars else "☆"
	stars_label.text = star_text
	stars_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))  # Gold
	stars_label.visible = true
	
	# XP line
	if rested_bonus > 0:
		xp_label.text = "XP Gained: %d (+%d 😴 rested)" % [xp_gained + rested_bonus, rested_bonus]
	else:
		xp_label.text = "XP Gained: " + str(xp_gained)
	
	# Gold line (yellow #FFD700)
	gold_label.text = "Gold Earned: " + str(gold_gained)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))  # #FFD700
	gold_label.visible = true
	
	# Reward line
	var reward_parts: Array[String] = []
	if not reward_weapon.is_empty():
		reward_parts.append("Weapon: " + _format_name(reward_weapon))
	if not reward_skill.is_empty():
		reward_parts.append("Skill: " + _format_name(reward_skill))
	
	if reward_parts.is_empty():
		reward_label.text = ""
		reward_label.visible = false
	else:
		reward_label.text = "Unlocked: " + " | ".join(reward_parts)
		reward_label.visible = true
	
	# Loot drops line
	if loot_label:
		var loot_summary := GameState.get_loot_summary()
		if loot_summary.total_drops > 0:
			var loot_parts: Array[String] = []
			# Show drops by rarity (legendary first)
			var rarity_order := ["legendary", "rare", "uncommon", "common"]
			for r in rarity_order:
				if loot_summary.by_rarity.has(r):
					var data = loot_summary.by_rarity[r]
					var color_hex: String = GameState.RARITY.get(r, {}).get("color", "#FFFFFF")
					var label_text: String = GameState.RARITY.get(r, {}).get("label", r)
					loot_parts.append("[color=%s]%s x%d[/color]" % [color_hex, label_text, data.count])
			loot_label.text = "Loot: " + "  ".join(loot_parts)
			if loot_summary.new_weapons > 0:
				loot_label.text += "  ✨%d NEW" % loot_summary.new_weapons
			loot_label.visible = true
		else:
			loot_label.text = "Loot: —"
			loot_label.visible = true
	
	# Ghost time comparison
	if ghost_label:
		if ghost_time > 0 and completion_time > 0:
			var time_diff := completion_time - ghost_time
			if time_diff < 0:
				# Player beat the ghost!
				ghost_label.text = "👻 GHOST: %.1fs | You beat it by %.1fs!" % [ghost_time, absf(time_diff)]
				ghost_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Green
			elif time_diff < 0.5:
				ghost_label.text = "👻 GHOST: %.1fs | Almost tied!" % ghost_time
				ghost_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))  # Gold
			else:
				ghost_label.text = "👻 GHOST: %.1fs | Ghost was %.1fs faster" % [ghost_time, time_diff]
				ghost_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))  # Cyan
			ghost_label.visible = true
		else:
			ghost_label.text = ""
			ghost_label.visible = false
	
	# Show / hide continue based on whether there's a next chapter
	continue_btn.visible = _has_next_chapter
	
	# Act Complete state for final chapter
	if not _has_next_chapter:
		title_label.text = "ACT %d COMPLETE" % GameState.current_act
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