extends CanvasLayer
# StreakPopup — Daily login streak reward notification
# v0.71 — Shows on first login of the day with streak info and reward

@onready var panel = $Panel
@onready var streak_label = $Panel/VBoxContainer/StreakLabel
@onready var reward_label = $Panel/VBoxContainer/RewardLabel
@onready var rested_label = $Panel/VBoxContainer/RestedLabel
@onready var continue_btn = $Panel/VBoxContainer/ContinueButton

func _ready():
	visible = false
	continue_btn.pressed.connect(_on_continue)
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_popup(streak_day: int, gold_reward: int, potion_reward: int, rested_active: bool, rested_chapters: int):
	get_tree().paused = true
	
	# Streak label with fire emoji for long streaks
	var streak_emoji = "🔥" if streak_day >= 7 else "📅" if streak_day >= 3 else "📆"
	streak_label.text = "%s Day %d Streak!" % [streak_emoji, streak_day]
	
	# Reward breakdown
	var parts = ["+%d Gold" % gold_reward]
	if potion_reward > 0:
		parts.append("+%d Potion%s" % [potion_reward, "s" if potion_reward > 1 else ""])
	reward_label.text = " | ".join(parts)
	
	# Rested XP indicator
	if rested_active:
		rested_label.text = "🔥 Rested XP Active! 2× bonus for %d chapter%s" % [rested_chapters, "s" if rested_chapters > 1 else ""]
		rested_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
		rested_label.visible = true
	else:
		rested_label.visible = false
	
	visible = true
	modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	continue_btn.grab_focus()

func _on_continue():
	get_tree().paused = false
	visible = false