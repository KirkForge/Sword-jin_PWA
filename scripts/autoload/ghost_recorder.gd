extends Node
# GhostRecorder — Records player position snapshots for ghost run replay
# v0.80 — Ghost runs + local leaderboard

const GHOST_DIR := "user://ghosts/"
const SNAPSHOT_INTERVAL := 0.05  # 20 snapshots per second (50ms)

var is_recording := false
var current_recording: Array = []  # Array of {t, x, y, facing_right, attacking}
var recording_start_time := 0.0
var _snapshot_timer := 0.0

func _ready():
	# Ensure ghost directory exists
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("ghosts"):
		dir.make_dir("ghosts")

func _process(delta):
	if not is_recording:
		return
	
	_snapshot_timer += delta
	if _snapshot_timer >= SNAPSHOT_INTERVAL:
		_snapshot_timer -= SNAPSHOT_INTERVAL
		_take_snapshot()

func start_recording():
	"""Begin recording player movement for the current chapter."""
	is_recording = true
	current_recording = []
	recording_start_time = Time.get_ticks_msec() / 1000.0
	_snapshot_timer = 0.0
	print("[GhostRecorder] Recording started")

func stop_recording() -> Array:
	"""Stop recording and return the recording data."""
	is_recording = false
	print("[GhostRecorder] Recording stopped — %d snapshots" % current_recording.size())
	return current_recording

func _take_snapshot():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	
	var t := (Time.get_ticks_msec() / 1000.0) - recording_start_time
	var snapshot := {
		"t": snappedf(t, 0.01),
		"x": snappedf(player.global_position.x, 1.0),
		"y": snappedf(player.global_position.y, 1.0),
		"fr": player.sprite.flip_h == false,  # facing right
		"atk": player.is_attacking,
	}
	current_recording.append(snapshot)

func save_ghost(chapter_id: String, recording: Array, completion_time: float) -> bool:
	"""Save a ghost recording if it's a new best time for this chapter."""
	var best := get_best_time(chapter_id)
	
	# Only save if this is a new best (or first run)
	if best <= 0 or completion_time < best:
		var path := GHOST_DIR + chapter_id + ".ghost"
		var data := {
			"chapter_id": chapter_id,
			"time": completion_time,
			"snapshots": recording,
			"timestamp": Time.get_unix_time_from_system(),
		}
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("[GhostRecorder] Failed to save ghost: " + path)
			return false
		file.store_string(JSON.stringify(data))
		file.close()
		print("[GhostRecorder] Ghost saved for %s (%.1fs)" % [chapter_id, completion_time])
		return true
	return false

func load_ghost(chapter_id: String) -> Array:
	"""Load a ghost recording for a chapter. Returns empty array if none."""
	var path := GHOST_DIR + chapter_id + ".ghost"
	if not FileAccess.file_exists(path):
		return []
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("[GhostRecorder] Failed to parse ghost: " + path)
		return []
	
	var data := json.data
	if data is Dictionary and data.has("snapshots"):
		return data["snapshots"]
	return []

func get_best_time(chapter_id: String) -> float:
	"""Get the best completion time for a chapter from ghost data."""
	var path := GHOST_DIR + chapter_id + ".ghost"
	if not FileAccess.file_exists(path):
		return -1.0
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1.0
	var text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(text) != OK:
		return -1.0
	
	var data := json.data
	if data is Dictionary and data.has("time"):
		return float(data["time"])
	return -1.0

func get_ghost_info(chapter_id: String) -> Dictionary:
	"""Get full ghost info (time, age) for a chapter."""
	var path := GHOST_DIR + chapter_id + ".ghost"
	if not FileAccess.file_exists(path):
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	
	var data := json.data
	if data is Dictionary:
		return {
			"time": data.get("time", 0.0),
			"timestamp": data.get("timestamp", 0),
			"snapshots": data.get("snapshots", []).size(),
		}
	return {}

func has_ghost(chapter_id: String) -> bool:
	"""Check if a ghost recording exists for a chapter."""
	return FileAccess.file_exists(GHOST_DIR + chapter_id + ".ghost")

func delete_ghost(chapter_id: String) -> bool:
	"""Delete a ghost recording."""
	var path := GHOST_DIR + chapter_id + ".ghost"
	if FileAccess.file_exists(path):
		var dir := DirAccess.open(GHOST_DIR)
		if dir:
			dir.remove(chapter_id + ".ghost")
			print("[GhostRecorder] Ghost deleted for %s" % chapter_id)
			return true
	return false