extends CanvasLayer
# BestiaryScreen — Enemy encyclopedia with kill counts and lore unlocks
# v0.71 — Retention system: Ownership & Curiosity drives

signal back_pressed

@onready var grid = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var detail_label = $MarginContainer/VBoxContainer/DetailLabel
@onready var back_btn = $MarginContainer/VBoxContainer/HBoxContainer/BackButton
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var stats_label = $MarginContainer/VBoxContainer/StatsLabel

var selected_type: String = ""

func _ready():
	visible = false
	back_btn.pressed.connect(_on_back)
	_refresh_list()

func show_bestiary():
	visible = true
	get_tree().paused = true
	_refresh_list()
	_update_stats()

func hide_bestiary():
	visible = false
	get_tree().paused = false

func _refresh_list():
	for child in grid.get_children():
		child.queue_free()
	
	# Sort: unlocked first, then by kill count descending
	var types = GameState.BESTIARY_LORE.keys().duplicate()
	types.sort_custom(func(a, b): 
		var ka = GameState.bestiary.get(a, 0)
		var kb = GameState.bestiary.get(b, 0)
		if ka > 0 and kb == 0: return true
		if kb > 0 and ka == 0: return false
		return ka > kb
	)
	
	for enemy_type in types:
		var kills = GameState.bestiary.get(enemy_type, 0)
		var entry = GameState.get_bestiary_entry(enemy_type)
		var lore = entry.get("lore", {})
		
		var btn = Button.new()
		if kills > 0:
			btn.text = "%s [%d]" % [_format_name(enemy_type), kills]
			btn.modulate = Color.WHITE
		else:
			btn.text = "???" 
			btn.modulate = Color.GRAY
		btn.custom_minimum_size = Vector2(160, 36)
		btn.pressed.connect(_on_entry_selected.bind(enemy_type))
		grid.add_child(btn)

func _on_entry_selected(enemy_type: String):
	selected_type = enemy_type
	var kills = GameState.bestiary.get(enemy_type, 0)
	var entry = GameState.get_bestiary_entry(enemy_type)
	var lore = entry.get("lore", {})
	var name = _format_name(enemy_type)
	
	var text = "🗡 %s\n" % name
	text += "Kills: %d\n" % kills
	
	# Show unlocked lore
	if kills == 0:
		text += "\n??? (Not yet encountered)"
	else:
		text += "\n"
		var milestones = lore.keys()
		milestones.sort()
		for milestone in milestones:
			if kills >= milestone:
				text += "📜 %s\n" % lore[milestone]
			else:
				text += "🔒 %d kills to unlock next lore\n" % milestone
	
	# Show next milestone
	var next_milestone = 0
	for m in milestones:
		if kills < m:
			next_milestone = m
			break
	if next_milestone > 0:
		text += "\nNext lore at %d kills (%d to go)" % [next_milestone, next_milestone - kills]
	elif kills >= 100:
		text += "\n✦ LORE COMPLETE ✦"
	
	detail_label.text = text

func _update_stats():
	var total_kills = 0
	for count in GameState.bestiary.values():
		total_kills += count
	var discovered = GameState.get_bestiary_unlock_count()
	var total = GameState.BESTIARY_LORE.size()
	stats_label.text = "📖 %d/%d discovered | ☠ %d total kills" % [discovered, total, total_kills]

func _format_name(enemy_type: String) -> String:
	return enemy_type.replace("_", " ").capitalize()

func _on_back():
	hide_bestiary()
	back_pressed.emit()