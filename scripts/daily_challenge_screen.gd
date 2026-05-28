extends CanvasLayer
# DailyChallengeScreen — Shows today's challenge with modifiers and rewards
# v0.72 — Daily challenge system (Octalysis CD6: Scarcity + CD7: Unpredictability)

signal back_pressed
signal challenge_accepted

@onready var panel = $Panel
@onready var title_label = $Panel/VBox/TitleLabel
@onready var base_label = $Panel/VBox/BaseLabel
@onready var mods_container = $Panel/VBox/ModsContainer
@onready var reward_label = $Panel/VBox/RewardLabel
@onready var status_label = $Panel/VBox/StatusLabel
@onready var accept_btn = $Panel/VBox/HBox/AcceptButton
@onready var back_btn = $Panel/VBox/HBox/BackButton

var challenge_data: Dictionary = {}

func _ready():
	visible = false
	accept_btn.pressed.connect(_on_accept)
	back_btn.pressed.connect(_on_back)

func show_challenge():
	challenge_data = GameState.get_daily_challenge()
	if challenge_data.is_empty():
		status_label.text = "No challenge available today."
		accept_btn.disabled = true
		visible = true
		return
	
	# Title
	title_label.text = "⚔️ DAILY CHALLENGE"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))  # Gold
	
	# Base chapter
	base_label.text = "Based on: " + challenge_data.get("title", "Unknown")
	
	# Clear old mod labels
	for child in mods_container.get_children():
		child.queue_free()
	
	# Show modifiers
	var mods = challenge_data.get("modifiers", {}).get("mods", [])
	for mod in mods:
		var label = Label.new()
		label.text = "%s %s — %s" % [mod.icon, mod.name, mod.desc]
		label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))  # Red-ish for danger
		mods_container.add_child(label)
	
	# Reward
	var gold = challenge_data.get("reward_gold", 30)
	var xp = challenge_data.get("reward_xp", 75)
	reward_label.text = "Reward: 💰 %d Gold  ⭐ %d XP" % [gold, xp]
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))  # Gold
	
	# Status
	if challenge_data.get("completed", false):
		status_label.text = "✅ Completed! Best: %.1fs  Stars: %s" % [
			challenge_data.get("best_time", 0.0),
			"⭐" * challenge_data.get("stars", 0)
		]
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		accept_btn.text = "Retry"
		accept_btn.disabled = false
	else:
		status_label.text = "🆕 New challenge available!"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		accept_btn.text = "Accept Challenge"
		accept_btn.disabled = false
	
	visible = true
	accept_btn.grab_focus()

func hide_challenge():
	visible = false

func _on_accept():
	AudioManager.play_sfx("ui_click")
	challenge_accepted.emit()

func _on_back():
	AudioManager.play_sfx("ui_click")
	back_pressed.emit()
	visible = false