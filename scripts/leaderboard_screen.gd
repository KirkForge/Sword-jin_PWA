extends CanvasLayer
# LeaderboardScreen — Local + Online (PlayFab) leaderboard + ghost run management
# v0.86 — PlayFab online leaderboards

signal back_pressed
signal ghost_run_requested(chapter_id: String)

@onready var panel = $Panel
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var chapter_list = $Panel/VBoxContainer/ScrollContainer/ChapterList
@onready var ghost_toggle = $Panel/VBoxContainer/HBoxContainer/GhostToggle
@onready var run_ghost_btn = $Panel/VBoxContainer/HBoxContainer/RunGhostButton
@onready var back_btn = $Panel/VBoxContainer/HBoxContainer/BackButton
@onready var online_btn = $Panel/VBoxContainer/HBoxContainer/OnlineButton
@onready var animation = $AnimationPlayer

var ghost_enabled := true
var selected_chapter := ""
var showing_online := false

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	ghost_toggle.pressed.connect(_on_ghost_toggle)
	run_ghost_btn.pressed.connect(_on_run_ghost)
	back_btn.pressed.connect(_on_back)
	
	if online_btn:
		online_btn.pressed.connect(_on_online_toggle)
	
	# Connect PlayFab signals
	if PlayFab.is_configured():
		PlayFab.leaderboard_received.connect(_on_leaderboard_received)
		PlayFab.leaderboard_failed.connect(_on_leaderboard_failed)

func show_leaderboard():
	"""Populate and show the leaderboard screen."""
	get_tree().paused = true
	selected_chapter = ""
	showing_online = false
	_populate_chapters()
	_update_ghost_button()
	_update_online_button()
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
	
	if showing_online and not PlayFab.is_logged_in:
		_show_online_not_logged_in()
		return
	
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
		
		if showing_online:
			# Online leaderboard entry
			var rank_label = Label.new()
			rank_label.text = "🔄"  # Loading indicator
			rank_label.custom_minimum_size.x = 40
			rank_label.add_theme_font_size_override("font_size", 14)
			hbox.add_child(rank_label)
			
			var online_label = Label.new()
			online_label.text = "Loading..."
			online_label.custom_minimum_size.x = 120
			online_label.add_theme_font_size_override("font_size", 14)
			hbox.add_child(online_label)
		else:
			# Local best time
			var time_label = Label.new()
			var best_time = GhostRecorder.get_best_time(chapter_id)
			if best_time > 0:
				time_label.text = "%.1fs" % best_time
				time_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
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
	
	# If online, fetch leaderboards for all unlocked chapters
	if showing_online and PlayFab.is_logged_in:
		_fetch_online_leaderboards()

func _show_online_not_logged_in():
	"""Show a message when PlayFab is not configured/logged in."""
	var label := Label.new()
	label.text = "🌐 Online leaderboards not available\n\nSet your PlayFab Title ID in Settings\nto enable online rankings."
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size.y = 100
	chapter_list.add_child(label)

func _fetch_online_leaderboards():
	"""Fetch online leaderboards for all unlocked chapters."""
	var chapters = ChapterDatabase.chapters
	for chapter_id in chapters.keys():
		if chapters[chapter_id].get("is_unlocked", false):
			PlayFab.get_leaderboard_around_player(chapter_id, 5)

func _on_leaderboard_received(chapter_id: String, entries: Array):
	"""Update the chapter list entry with online leaderboard data."""
	if not showing_online:
		return
	
	# Find the chapter entry in the list and update it
	var idx := 0
	var chapters = ChapterDatabase.chapters
	var sorted_ids = chapters.keys()
	sorted_ids.sort()
	
	for cid in sorted_ids:
		if not chapters[cid].get("is_unlocked", false):
			continue
		if cid == chapter_id:
			if idx < chapter_list.get_child_count():
				var hbox = chapter_list.get_child(idx)
				# Update rank and time labels
				if hbox.get_child_count() >= 3:
					var rank_label = hbox.get_child(1)
					var online_label = hbox.get_child(2)
					
					if entries.size() > 0:
						var my_entry := {}
						for e in entries:
							if e.get("is_self", false):
								my_entry = e
								break
						
						if not my_entry.is_empty():
							rank_label.text = "#%d" % my_entry.rank
							rank_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
							online_label.text = "%.1fs" % my_entry.time
							online_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
						else:
							rank_label.text = "—"
							online_label.text = "No score"
					else:
						rank_label.text = "—"
						online_label.text = "Empty"
			break
		idx += 1

func _on_leaderboard_failed(chapter_id: String, error: String):
	"""Handle leaderboard fetch failure."""
	if not showing_online:
		return
	print("[Leaderboard] Failed to fetch online data for %s: %s" % [chapter_id, error])

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

func _update_online_button():
	if online_btn:
		if showing_online:
			online_btn.text = "🏠 Local"
			online_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			if PlayFab.is_configured():
				online_btn.text = "🌐 Online"
				online_btn.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
			else:
				online_btn.text = "🌐 Setup"
				online_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _on_ghost_toggle():
	ghost_enabled = not ghost_enabled
	ghost_toggle.text = "👻 Ghosts: " + ("ON" if ghost_enabled else "OFF")
	ghost_toggle.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3) if ghost_enabled else Color(1.0, 0.3, 0.3))

func _on_online_toggle():
	showing_online = not showing_online
	title_label.text = "🌐 Online Leaderboard" if showing_online else "🏠 Local Leaderboard"
	_populate_chapters()
	_update_online_button()

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