extends Node2D
# LevelManager — v0.86 — 11 enemy types, wave system, cinematic crits

@onready var player = $Player
@onready var skeleton_scene = preload("res://scenes/skeleton.tscn")
@onready var captain_scene = preload("res://scenes/skeleton_captain.tscn")
@onready var archer_scene = preload("res://scenes/skeleton_archer.tscn")
@onready var bandit_scene = preload("res://scenes/bandit.tscn")
@onready var assassin_scene = preload("res://scenes/assassin.tscn")
@onready var golem_scene = preload("res://scenes/golem.tscn")
@onready var ghost_scene = preload("res://scenes/ghost.tscn")
@onready var necromancer_scene = preload("res://scenes/necromancer.tscn")
@onready var berserker_scene = preload("res://scenes/berserker.tscn")
@onready var shaman_scene = preload("res://scenes/shaman.tscn")
@onready var wraith_scene = preload("res://scenes/wraith.tscn")
@onready var merchant_scene = preload("res://scenes/merchant_ally.tscn")
@onready var gate_scene = preload("res://scenes/iron_gate.tscn")
@onready var victory_screen_scene = preload("res://scenes/ui/victory_screen.tscn")
@onready var ghost_runner_scene = preload("res://scenes/ghost_runner.tscn")

var chapter_data: Dictionary = {}
var enemies_remaining := 0
var dialogue_triggered := {}
var pause_menu: Control
var victory_screen: CanvasLayer
var arena: Node2D  # ArenaBuilder tilemap
var ghost_runner_instance: CharacterBody2D = null  # Ghost replay sprite
var ghost_active := false  # Whether ghost is currently being shown
var ghost_best_time := 0.0  # Best time for current chapter (from ghost file)

# Wave system
var current_wave := 0
var total_waves := 0
var wave_data := []         # Array of wave definitions from chapter JSON
var wave_spawned := false   # Whether current wave has been spawned
var wave_cooldown := 0.0    # Delay between waves (seconds)
const WAVE_COOLDOWN_TIME := 2.0  # Seconds between waves

func _ready():
	# Load chapter 001 by default
	ChapterDatabase.set_current_chapter("act01_ch001")
	chapter_data = ChapterDatabase.get_current_chapter()
	
	if chapter_data.is_empty():
		push_error("No chapter data loaded")
		return
	
	# Build tilemap arena
	arena = load("res://scripts/arena_builder.gd").new()
	var chapter_id = chapter_data.get("chapter_id", "act01_ch001")
	arena.setup(chapter_id, self)
	
	# Setup scene
	_setup_level()
	
	# Add pause menu
	pause_menu = load("res://scripts/pause_menu.gd").new()
	pause_menu.setup(self)
	
	# Add mobile controls
	var mobile_scene = load("res://scenes/mobile_controls.tscn")
	if mobile_scene:
		add_child(mobile_scene.instantiate())
	
	# Add dialogue manager (from packed scene)
	var dlg_scene = load("res://scenes/dialogue_manager.tscn")
	if dlg_scene:
		var dlg_instance = dlg_scene.instantiate()
		dlg_instance.name = "DialogueManager"
		add_child(dlg_instance)
	
	# Add achievement toast (global listener for achievement unlocks)
	var toast_scene = load("res://scenes/ui/achievement_toast.tscn")
	if toast_scene:
		var toast_instance = toast_scene.instantiate()
		toast_instance.name = "AchievementToast"
		add_child(toast_instance)
	
	# Add chapter manager (hidden by default)
	var chm_scene = load("res://scenes/chapter_manager.tscn")
	if chm_scene:
		var chm_instance = chm_scene.instantiate()
		chm_instance.name = "ChapterManager"
		add_child(chm_instance)
	
	_dialogue_start()
	
	# Update UI
	$Objective.text = "Objective: " + chapter_data.get("objective", "Defeat enemies!")
	$LevelLabel.text = chapter_data.get("title", "Level 1")
	
	# Background handled by ArenaBuilder tilemap
	# (ColorRect removed by arena builder)
	
	# Fade in from black
	ScreenFader.fade_from_black(0.4)
	
	print("Chapter loaded: %s" % chapter_data.get("title", "?"))
	print("Controls: WASD move | SPACE attack | LEFT SHIFT dodge | ESC pause | C chapter select | M mute")

func _dialogue_start():
	var dlg = get_node("DialogueManager")
	if not dlg:
		dialogue_triggered["start"] = true
		return
	var dialogue = chapter_data.get("dialogue", [])
	if not dialogue.is_empty():
		dlg.load_dialogue(dialogue)
		dlg.dialogue_ended.connect(_on_dialogue_ended_start, CONNECT_ONE_SHOT)
		await get_tree().create_timer(0.5).timeout
		dlg.play_dialogue_for_trigger("start")
	else:
		# No dialogue, enable combat immediately
		dialogue_triggered["start"] = true

func _on_dialogue_ended_start():
	dialogue_triggered["start"] = true
	AudioManager.play_bgm("bgm_battle", 1.0, true)

func _setup_level():
	# Apply saved health from GameState
	if player and GameState.saved_health > 0:
		player.max_health = GameState.saved_max_health
		player.health = GameState.saved_health
		player._update_label()
	
	# Clear existing skeletons
	for child in get_children():
		if child.is_in_group("enemy"):
			child.queue_free()
	
	# Check for wave-based spawning
	wave_data = chapter_data.get("waves", [])
	
	if wave_data.size() > 0:
		# WAVE MODE: spawn waves one at a time
		total_waves = wave_data.size()
		current_wave = 0
		wave_spawned = false
		wave_cooldown = 0.0
		_spawn_next_wave()
	else:
		# LEGACY MODE: spawn all enemies at once
		var enemies = chapter_data.get("enemies", [])
		for group in enemies:
			var enemy_type = group.get("type", "skeleton")
			var positions = group.get("positions", [])
			var stats = group.get("stats", {})
			
			for pos_data in positions:
				var pos = Vector2(pos_data.x, pos_data.y)
				_spawn_enemy(enemy_type, pos, stats)
	
	# Spawn allies
	var allies = chapter_data.get("allies", [])
	for ally_data in allies:
		var ally_type = ally_data.get("type", "merchant")
		if ally_type == "merchant" and merchant_scene:
			var ally_inst = merchant_scene.instantiate()
			var apos = ally_data.get("position", {"x": 150, "y": 250})
			ally_inst.position = Vector2(apos.x, apos.y)
			var lines = []
			if ally_data.has("dialogue"):
				var dlg = ally_data["dialogue"]
				for k in ["start", "mid_combat", "objective_complete"]:
					if dlg.has(k):
						lines.append(dlg[k])
				if ally_inst.has_method("_setup"):
					ally_inst._setup(lines)
			add_child(ally_inst)
	
	# Gate spawning for ch004
	var chapter_id = chapter_data.get("chapter_id", "")
	if chapter_id == "act01_ch004" and gate_scene:
		var gate = gate_scene.instantiate()
		gate.position = Vector2(580, 180)
		add_child(gate)
		GameState.has_gate_key = false
		$Objective.text = "Objective: Defeat defenders and open the gate!"
	
	enemies_remaining = 0
	for child in get_children():
		if child.is_in_group("enemy"):
			enemies_remaining += 1
	
	# Apply daily challenge modifiers if active
	if GameState.is_daily_challenge_run:
		_apply_daily_modifiers()
	
	GameState.reset_chapter_state()
	GameState.chapter_kills = 0
	
	# Start ghost recording for this chapter
	GhostRecorder.start_recording()
	
	# Spawn ghost runner if one exists for this chapter
	_spawn_ghost_runner()

func _spawn_ghost_runner():
	"""Spawn a ghost runner if ghost runs are enabled and a recording exists."""
	# Clean up any existing ghost
	if ghost_runner_instance != null and is_instance_valid(ghost_runner_instance):
		ghost_runner_instance.queue_free()
		ghost_runner_instance = null
		ghost_active = false
	
	if not GameState.ghost_runs_enabled:
		return
	
	var chapter_id := "act%02d_ch%03d" % [GameState.current_act, GameState.current_chapter]
	if not GhostRecorder.has_ghost(chapter_id):
		return
	
	var snapshots := GhostRecorder.load_ghost(chapter_id)
	if snapshots.is_empty():
		return
	
	ghost_best_time = GhostRecorder.get_best_time(chapter_id)
	
	ghost_runner_instance = ghost_runner_scene.instantiate()
	add_child(ghost_runner_instance)
	ghost_runner_instance.start_playback(snapshots, ghost_best_time)
	ghost_active = true
	
	# Show ghost HUD indicator
	_update_ghost_hud()
	print("[LevelManager] Ghost runner spawned for %s (%.1fs best)" % [chapter_id, ghost_best_time])

func _update_ghost_hud():
	"""Update the ghost HUD indicator showing time comparison."""
	var ghost_hud = get_node_or_null("GhostHUD")
	if ghost_hud == null:
		return
	
	if not ghost_active or ghost_runner_instance == null or not is_instance_valid(ghost_runner_instance):
		ghost_hud.text = ""
		return
	
	# Calculate time comparison: player elapsed vs ghost elapsed
	var player_time = (Time.get_ticks_msec() / 1000.0) - GameState.chapter_start_time
	var ghost_time = ghost_runner_instance.get_elapsed_time()
	var ghost_progress = ghost_runner_instance.get_progress_ratio()
	
	# Compare player progress (based on position) to ghost progress
	# Show how far ahead/behind the ghost is
	var time_diff = player_time - ghost_time
	
	var progress_pct = int(ghost_progress * 100)
	
	if ghost_runner_instance.is_ghost_done():
		# Ghost finished — show final time comparison
		var final_diff = player_time - ghost_best_time
		if final_diff < 0:
			ghost_hud.text = "👻 GHOST DONE | You're AHEAD by %.1fs!" % absf(final_diff)
			ghost_hud.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Green
		else:
			ghost_hud.text = "👻 GHOST DONE | You're BEHIND by %.1fs" % final_diff
			ghost_hud.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red
	else:
		# Ghost still running — show live comparison
		if time_diff < -0.5:
			ghost_hud.text = "👻 GHOST RUN | Ahead %.1fs" % absf(time_diff)
			ghost_hud.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Green
		elif time_diff > 0.5:
			ghost_hud.text = "👻 GHOST RUN | Behind %.1fs" % time_diff
			ghost_hud.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))  # Orange
		else:
			ghost_hud.text = "👻 GHOST RUN | Neck and neck!"
			ghost_hud.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))  # Cyan

func _update_combo_hud():
	"""Update the combo counter display in the HUD."""
	var combo_label = get_node_or_null("ComboCounter")
	if combo_label == null:
		return
	
	var p = get_node_or_null("Player")
	if p == null or p.is_dead:
		combo_label.text = ""
		return
	
	if p.last_hit_was_crit:
		combo_label.text = "💥 CRIT!"
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		combo_label.add_theme_font_size_override("font_size", 22)
	elif p.combo_active and p.combo_count > 0:
		var hit_num = p.combo_count + 1
		var combo_colors = [Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.3), Color(1.0, 0.4, 0.1)]
		var color = combo_colors[p.combo_count] if p.combo_count < combo_colors.size() else Color(1.0, 0.2, 0.2)
		combo_label.text = "×%d COMBO!" % hit_num
		combo_label.add_theme_color_override("font_color", color)
		# Scale up briefly on finisher
		if p.combo_count == 2:
			combo_label.add_theme_font_size_override("font_size", 22)
		else:
			combo_label.add_theme_font_size_override("font_size", 18)
	else:
		combo_label.text = ""

# --- Wave System ---
func _spawn_next_wave():
	"""Spawn the next wave of enemies from wave_data."""
	if current_wave >= total_waves:
		return
	
	var wave = wave_data[current_wave]
	wave_spawned = true
	
	var wave_label = wave.get("label", "Wave %d" % (current_wave + 1))
	var enemies = wave.get("enemies", [])
	
	for group in enemies:
		var enemy_type = group.get("type", "skeleton")
		var positions = group.get("positions", [])
		var stats = group.get("stats", {})
		
		for pos_data in positions:
			var pos = Vector2(pos_data.x, pos_data.y)
			_spawn_enemy(enemy_type, pos, stats)
	
	# Count enemies in this wave
	enemies_remaining = 0
	for child in get_children():
		if child.is_in_group("enemy") and not child.is_dead:
			enemies_remaining += 1
	
	# Update HUD
	var wave_text = "WAVE %d/%d: %s" % [current_wave + 1, total_waves, wave_label]
	$Objective.text = wave_text
	print("[Wave] %s — %d enemies" % [wave_text, enemies_remaining])
	
	# Show wave announcement
	_show_wave_announcement(current_wave + 1, total_waves, wave_label)

func _process_waves(delta: float):
	"""Check if current wave is cleared and spawn next wave."""
	if current_wave >= total_waves:
		return
	
	# Count live enemies
	var live_enemies := 0
	for child in get_children():
		if child.is_in_group("enemy") and not child.is_dead:
			live_enemies += 1
	
	if live_enemies == 0 and wave_spawned:
		# Current wave cleared
		current_wave += 1
		wave_spawned = false
		
		if current_wave < total_waves:
			# Start cooldown before next wave
			wave_cooldown = WAVE_COOLDOWN_TIME
			$Objective.text = "WAVE CLEARED! Next wave incoming..."
		else:
			# All waves done — chapter completes via the normal check
			$Objective.text = "ALL WAVES CLEARED!"
	
	# Wave cooldown timer
	if wave_cooldown > 0:
		wave_cooldown -= delta
		if wave_cooldown <= 0 and current_wave < total_waves and not wave_spawned:
			_spawn_next_wave()

func _show_wave_announcement(wave_num: int, total: int, label: String):
	"""Show a brief wave announcement overlay."""
	var announce := Label.new()
	announce.text = "⚔ WAVE %d/%d ⚔\n%s" % [wave_num, total, label]
	announce.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	announce.add_theme_font_size_override("font_size", 24)
	announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce.anchor_left = 0.0
	announce.anchor_right = 1.0
	announce.offset_top = 140.0
	announce.offset_bottom = 200.0
	announce.z_index = 100
	add_child(announce)
	
	var tween := announce.create_tween().set_parallel()
	tween.tween_property(announce, "modulate:a", 0.0, 2.0).set_delay(1.0)
	tween.tween_property(announce, "position:y", announce.position.y - 20, 2.0)
	tween.chain().tween_callback(announce.queue_free)

func _spawn_enemy(type: String, pos: Vector2, stats: Dictionary):
	var inst: CharacterBody2D
	match type:
		"skeleton_captain":
			inst = captain_scene.instantiate()
		"skeleton_archer":
			inst = archer_scene.instantiate()
		"bandit":
			inst = bandit_scene.instantiate()
		"assassin":
			inst = assassin_scene.instantiate()
		"golem":
			inst = golem_scene.instantiate()
		"ghost":
			inst = ghost_scene.instantiate()
		"necromancer":
			inst = necromancer_scene.instantiate()
		"berserker":
			inst = berserker_scene.instantiate()
		"shaman":
			inst = shaman_scene.instantiate()
		"wraith":
			inst = wraith_scene.instantiate()
		_:
			inst = skeleton_scene.instantiate()
		
	inst.position = pos
	add_child(inst)
	
	# Apply stats
	if stats.has("health"):
		inst.max_health = stats.health
		inst.health = stats.health
	if stats.has("speed"):
		inst.speed = stats.speed
	if stats.has("damage"):
		inst.attack_damage = stats.damage
	
	inst.add_to_group("enemy")
	
	# Connect death signal
	if inst.has_method("_die"):
		# We'll poll in process instead — simpler
		pass

func _apply_daily_modifiers():
	"""Apply active daily challenge modifiers to the level."""
	var modifiers := GameState.active_daily_modifiers
	if modifiers.is_empty():
		return
	
	var challenge_info := GameState.get_daily_challenge()
	var mod_labels := []
	for mod_id in modifiers:
		var mod_data := GameState.DAILY_CHALLENGE_MODIFIERS.get(mod_id, {})
		mod_labels.append(mod_data.get("icon", "?") + " " + mod_data.get("label", mod_id))
	
	$Objective.text = "⚔ DAILY: " + " | ".join(mod_labels)
	print("DAILY CHALLENGE modifiers: %s" % str(modifiers))
	
	# double_enemies: duplicate each enemy
	if "double_enemies" in modifiers:
		var enemy_nodes := []
		for child in get_children():
			if child.is_in_group("enemy") and not child.is_dead:
				enemy_nodes.append(child)
		for enemy in enemy_nodes:
			var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
			var new_pos := enemy.position + offset
			# Determine enemy type from script name
			var enemy_type := "skeleton"
			var script_path = enemy.get_script().resource_path if enemy.get_script() else ""
			if "skeleton_captain" in script_path:
				enemy_type = "skeleton_captain"
			elif "skeleton_archer" in script_path:
				enemy_type = "skeleton_archer"
			elif "necromancer" in script_path:
				enemy_type = "necromancer"
			elif "berserker" in script_path:
				enemy_type = "berserker"
			elif "shaman" in script_path:
				enemy_type = "shaman"
			elif "wraith" in script_path:
				enemy_type = "wraith"
			elif "bandit" in script_path:
				enemy_type = "bandit"
			elif "assassin" in script_path:
				enemy_type = "assassin"
			elif "golem" in script_path:
				enemy_type = "golem"
			elif "ghost" in script_path:
				enemy_type = "ghost"
			_spawn_enemy(enemy_type, new_pos, {})
		# Recount
		enemies_remaining = 0
		for child in get_children():
			if child.is_in_group("enemy"):
				enemies_remaining += 1
	
	# glass_cannon: player 50% HP, 2× damage
	if "glass_cannon" in modifiers:
		if player:
			player.max_health = int(player.max_health * 0.5)
			player.health = min(player.health, player.max_health)
			player._update_label()
			player.attack_damage = int(player.attack_damage * 2.0)
	
	# armored_foes: enemies +50% HP
	if "armored_foes" in modifiers:
		for child in get_children():
			if child.is_in_group("enemy") and not child.is_dead:
				child.max_health = int(child.max_health * 1.5)
				child.health = child.max_health
	
	# elite_patrol: upgrade all enemies to captains
	if "elite_patrol" in modifiers:
		for child in get_children():
			if child.is_in_group("enemy") and not child.is_dead:
				child.max_health = int(child.max_health * 1.3)
				child.health = child.max_health
				child.attack_damage = int(child.attack_damage * 1.3) if child.get("attack_damage") != null else 12
				child.speed = child.speed * 1.1 if child.get("speed") != null else 55.0
	
	# no_dodge: disable dodge roll
	if "no_dodge" in modifiers:
		if player and player.has_method("set_dodge_enabled"):
			player.set_dodge_enabled(false)

var _daily_poison_timer: float = 0.0
var _daily_speed_timer: float = 0.0

func _process_daily_modifiers(delta: float):
	"""Process runtime daily challenge modifiers each frame."""
	var modifiers := GameState.active_daily_modifiers
	
	# speed_run: auto-fail if time exceeds 90 seconds
	if "speed_run" in modifiers:
		_daily_speed_timer += delta
		if _daily_speed_timer > 90.0:
			# Time's up — fail the challenge
			print("DAILY CHALLENGE: Speed run failed! Time exceeded 90s")
			GameState.is_daily_challenge_run = false
			GameState.active_daily_modifiers = []
			# Reload the scene (fail state)
			get_tree().reload_current_scene()
			return
		# Show timer in objective
		var remaining := 90.0 - _daily_speed_timer
		$Objective.text = "⚔ DAILY ⏱ %.0fs remaining" % remaining
	
	# poison_swamp: 1 poison tick every 3 seconds
	if "poison_swamp" in modifiers:
		_daily_poison_timer += delta
		if _daily_poison_timer >= 3.0:
			_daily_poison_timer = 0.0
			if player and player.health > 1:
				player.take_damage(1)

func _process(_delta):
	# Check chapter complete condition
	if chapter_data.is_empty():
		return
	if not dialogue_triggered.get("start", false):
		return  # Wait for start dialogue to finish
	
	# Daily challenge runtime modifiers
	if GameState.is_daily_challenge_run:
		_process_daily_modifiers(_delta)
	
	# Update ghost HUD
	if ghost_active:
		_update_ghost_hud()
	
	# Update combo counter HUD
	_update_combo_hud()
	
	# Wave system: check if current wave is cleared
	if total_waves > 0:
		_process_waves(_delta)
	
	if chapter_data.get("type", "combat") == "combat":
		var live_enemies := 0
		for child in get_children():
			if child.is_in_group("enemy") and not child.is_dead:
				live_enemies += 1
		
		# Wave mode: don't complete chapter until all waves done
		if total_waves > 0:
			if live_enemies == 0 and wave_spawned and current_wave >= total_waves:
				enemies_remaining = 0
				_objective_complete()
		elif live_enemies == 0 and enemies_remaining > 0:
			# Legacy mode
			# For ch004, wait for gate opening rather than auto-completing
			var ch_id = chapter_data.get("chapter_id", "")
			if ch_id == "act01_ch004":
				enemies_remaining = 0
				$Objective.text = "The defenders are dead. Open the gate!"
			else:
				enemies_remaining = 0
				_objective_complete()

func _on_gate_opened():
	# Called by IronGate when player opens it with key
	print("Gate opened! Completing chapter...")
	_objective_complete()

func _objective_complete():
	# Handle "objective_complete" dialogue trigger
	var dlg = get_node("DialogueManager")
	var dialogue = chapter_data.get("dialogue", [])
	var has_completion_dialogue = false
	for entry in dialogue:
		if entry.get("trigger", "") == "objective_complete":
			has_completion_dialogue = true
			break
	
	if has_completion_dialogue and dlg:
		dlg.load_dialogue(dialogue)
		dlg.play_dialogue_for_trigger("objective_complete")
		dlg.dialogue_ended.connect(_on_objective_dialogue_done, CONNECT_ONE_SHOT)
	else:
		_finish_chapter_complete()

func _on_objective_dialogue_done():
	_finish_chapter_complete()

func _finish_chapter_complete():
	# Merchant heal if ally present
	var allies = chapter_data.get("allies", [])
	if not allies.is_empty():
		player.heal(25)
	
	# Complete daily challenge if this was a challenge run
	if GameState.is_daily_challenge_run:
		GameState.complete_daily_challenge()
		GameState.is_daily_challenge_run = false
		GameState.active_daily_modifiers = []
	
	print("Chapter complete! Transitioning...")
	AudioManager.play_sfx("level_complete")
	
	# Capture rewards BEFORE completing (GameState clears them after)
	var rewards = ChapterDatabase.get_current_chapter().get("rewards", {})
	var xp_gained: int = rewards.get("xp", 0)
	var gold_gained: int = rewards.get("gold", 0)
	var reward_weapon: String = rewards.get("unlock_weapon", "")
	var reward_skill: String = rewards.get("unlock_skill", "")
	
	# Capture rested XP BEFORE completing (it gets consumed in add_xp)
	var rested_xp_before := GameState.rested_xp
	var rested_bonus := mini(rested_xp_before, xp_gained)
	
	GameState.complete_current_chapter()
	
	# Stop ghost recording and save if best time
	var recording := GhostRecorder.stop_recording()
	var chapter_id_for_ghost := "act%02d_ch%03d" % [GameState.current_act, GameState.current_chapter]
	var elapsed := (Time.get_ticks_msec() / 1000.0) - GameState.chapter_start_time
	
	# Capture ghost data BEFORE clearing state
	var ghost_time_for_victory := ghost_best_time if ghost_active else -1.0
	ghost_active = false
	var ghost_hud = get_node_or_null("GhostHUD")
	if ghost_hud:
		ghost_hud.text = ""
	
	if recording.size() > 0:
		var is_new_best := GhostRecorder.save_ghost(chapter_id_for_ghost, recording, elapsed)
		if is_new_best:
			# Check ghost hunter achievement: beat your ghost
			if GhostRecorder.get_best_time(chapter_id_for_ghost) > 0:
				GameState.check_ghost_achievement(chapter_id_for_ghost, elapsed)
	
	# Get stars earned this chapter
	var chapter_id := "act%02d_ch%03d" % [GameState.current_act, GameState.current_chapter]
	var stars: int = GameState.get_stars(chapter_id)
	
	# Show victory screen instead of instant reload
	victory_screen = victory_screen_scene.instantiate()
	add_child(victory_screen)
	
	var has_next = not chapter_data.get("next_chapter", "").is_empty()
	victory_screen._has_next_chapter = has_next
	
	victory_screen.show_victory(
		chapter_data.get("title", "Chapter Complete"),
		xp_gained,
		gold_gained,
		reward_weapon,
		reward_skill,
		stars,
		ghost_time_for_victory,
		elapsed,
		rested_bonus
	)
	
	victory_screen.next_chapter_pressed.connect(_on_victory_next)
	victory_screen.chapter_select_pressed.connect(_on_victory_select)
	victory_screen.title_screen_pressed.connect(_on_victory_title)

func _on_victory_next():
	var next = chapter_data.get("next_chapter", "")
	if not next.is_empty():
		ChapterDatabase.set_current_chapter(next)
		ScreenFader.fade_to_black(0.5)
		await get_tree().create_timer(0.5).timeout
		get_tree().reload_current_scene()

func _on_victory_select():
	victory_screen.hide_victory()
	# Player can press C to open chapter manager, or continue playing

func _on_victory_title():
	ScreenFader.fade_to_black(0.5)
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if pause_menu and pause_menu.is_paused:
			pause_menu._resume()
		get_tree().reload_current_scene()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if pause_menu:
			pause_menu.toggle()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		if pause_menu and pause_menu.is_paused:
			return
		var chm = get_node_or_null("ChapterManager")
		if chm:
			chm.visible = not chm.visible
			if chm.visible:
				chm.show_manager()
			else:
				chm.hide_manager()
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		AudioManager.set_volume(0.0 if AudioManager.master_volume > 0.0 else 0.8)
		if pause_menu:
			pause_menu._update_mute_label()