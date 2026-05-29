extends CanvasLayer
# LeaderboardScreen — Local leaderboard + ghost run management
# v0.80 — Ghost runs + local leaderboard

signal back_pressed
signal ghost_run_requested(chapter_id: String)

@onready var panel = $Panel
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var chapter_list = $Panel/VBoxContainer/ScrollContainer/ChapterList
@onready var ghost_toggle = $Panel/VBoxContainer/HBoxContainer/GhostToggle
@onready var run_ghost_btn = $Panel/VBoxContainer/HBoxContainer/RunGhostButton
@onready var back_btn = $Panel/VBoxContainer/HBoxContainer/BackButton
@onready var animation = $AnimationPlayer

var ghost_enabled := true
var selected_chapter := ""

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	ghost_toggle.pressed.connect(_on_ghost_toggle)
	run_ghost_btn.pressed.connect(_on_run_ghost)
	back_btn.pressed.connect(_on_back)

func show_leaderboard():
	"""Populate and show the leaderboard screen."""
	get_tree().paused = true
	selected_chapter = ""
	_populate_chapters()
	_update_ghost_button()
	visible = true
	modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func _populate_chapters():
	"""Populate the chapter list with best times and ghost status."""
	for child in chapter_list.get_children():
		child.queue_free()
	
	var chapters = ChapterDatabase.chapters
	var sorted_ids = chapters.keys()
	sorted_ids.sort()
	
	for chapter_id in sorted_ids:
		var ch = chapters[chapter_id]
		if not ch.get("is_unlocked", false):
			continue
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		
		# Chapter name
		var name_label = Label.new()
		name_label.text = ch.get("title", chapter_id)
		name_label.custom_minimum_size.x = 200
		name_label.add_theme_font_size_override("font_size", 14)
		hbox.add_child(name_label)
		
		# Best time
		var time_label = Label.new()
		var best_time = GhostRecorder.get_best_time(chapter_id)
		if best_time > 0:
			time_label.text = "%.1fs" % best_time
			time_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Green
		else:
			time_label.text = "—"
			time_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		time_label.custom_minimum_size.x = 80
		time_label.add_theme_font_size_override("font_size", 14)
		hbox.add_child(time_label)
		
		# Stars
		var stars = GameState.get_stars(chapter_id)
		var stars_label = Label.new()
		var stars_text := ""
		for i in range(3):
			stars_text += "⭐" if i < stars else "☆"
		stars_label.text = stars_text
		stars_label.custom_minimum_size.x = 60
		stars_label.add_theme_font_size_override("font_size", 14)
		hbox.add_child(stars_label)
		
		# Ghost indicator
		var ghost_label = Label.new()
		if GhostRecorder.has_ghost(chapter_id):
			ghost_label.text = "👻"
		else:
			ghost_label.text = ""
		ghost_label.custom_minimum_size.x = 30
		ghost_label.add_theme_font_size_override("font_size", 14)
		hbox.add_child(ghost_label)
		
		# Select button
		var select_btn = Button.new()
		select_btn.text = "▶"
		select_btn.custom_minimum_size.x = 40
		select_btn.add_theme_font_size_override("font_size", 12)
		select_btn.pressed.connect(_on_chapter_select.bind(chapter_id))
		hbox.add_child(select_btn)
		
		chapter_list.add_child(hbox)

func _on_chapter_select(chapter_id: String):
	selected_chapter = chapter_id
	_update_ghost_button()
	# Highlight selected chapter
	for child in chapter_list.get_children():
		for c in child.get_children():
			if c is Label:
				c.add_theme_color_override("font_color", Color.WHITE)
		var select_btn = child.get_child(child.get_child_count() - 1) as Button
		if select_btn:
			select_btn.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	# Re-highlight selected
	var idx = 0
	for chapter_id_key in ChapterDatabase.chapters.keys():
		if chapter_id_key == chapter_id:
			if idx < chapter_list.get_child_count():
				var hbox = chapter_list.get_child(idx)
				for c in hbox.get_children():
					if c is Label:
						c.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			break
		idx += 1

func _update_ghost_button():
	if selected_chapter != "" and GhostRecorder.has_ghost(selected_chapter):
		run_ghost_btn.disabled = false
		run_ghost_btn.text = "👻 Run with Ghost"
	else:
		run_ghost_btn.disabled = true
		run_ghost_btn.text = "No Ghost"

func _on_ghost_toggle():
	ghost_enabled = not ghost_enabled
	ghost_toggle.text = "👻 Ghosts: " + ("ON" if ghost_enabled else "OFF")
	ghost_toggle.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3) if ghost_enabled else Color(1.0, 0.3, 0.3))

func _on_run_ghost():
	if selected_chapter != "":
		hide_leaderboard()
		ghost_run_requested.emit(selected_chapter)

func _on_back():
	hide_leaderboard()
	back_pressed.emit()

func hide_leaderboard():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.2)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
	)