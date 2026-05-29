extends CharacterBody2D
# GhostRunner — Replays a recorded ghost path on top of the level
# v0.81 — Ghost HUD indicator, time comparison, finish effects

const GHOST_ALPHA := 0.35
const GHOST_COLOR_RIGHT := Color(0.3, 0.8, 1.0, GHOST_ALPHA)  # Cyan-ish ghost
const GHOST_COLOR_LEFT := Color(0.3, 0.8, 1.0, GHOST_ALPHA)

var snapshots: Array = []
var playback_time := 0.0
var is_playing := false
var snapshot_index := 0
var ghost_finished := false
var ghost_best_time := 0.0  # Best time for this chapter (from ghost file)

@onready var sprite = $AnimatedSprite2D

func _ready():
	# Make ghost semi-transparent
	modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	# Set z-index above enemies but below player
	z_index = 5
	# Disable collision
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	visible = false

func start_playback(recording: Array, best_time: float = 0.0):
	"""Start playing back a ghost recording."""
	if recording.is_empty():
		queue_free()
		return
	
	snapshots = recording
	snapshot_index = 0
	playback_time = 0.0
	is_playing = true
	ghost_finished = false
	ghost_best_time = best_time
	visible = true
	
	# Set initial position
	if snapshots.size() > 0:
		var first = snapshots[0]
		global_position = Vector2(first.x, first.y)
		sprite.flip_h = not first.get("fr", true)
	
	print("[GhostRunner] Playback started — %d snapshots, best time: %.1fs" % [snapshots.size(), best_time])

func stop_playback():
	"""Stop the ghost playback."""
	is_playing = false
	visible = false

func get_progress_ratio() -> float:
	"""How far through the ghost recording we are (0.0 to 1.0)."""
	if snapshots.is_empty():
		return 0.0
	return float(snapshot_index) / float(snapshots.size() - 1)

func get_elapsed_time() -> float:
	"""Current playback time of the ghost."""
	return playback_time

func is_ghost_done() -> bool:
	"""Whether the ghost has finished its run."""
	return ghost_finished

func _process(delta):
	if not is_playing or snapshots.is_empty():
		return
	
	playback_time += delta
	
	# Find the snapshot closest to current playback time
	# Snapshots are ordered by time, so we advance forward
	while snapshot_index < snapshots.size() - 1:
		var next_snapshot = snapshots[snapshot_index + 1]
		if next_snapshot.t <= playback_time:
			snapshot_index += 1
		else:
			break
	
	# Interpolate between current and next snapshot for smooth movement
	var current = snapshots[snapshot_index]
	var target_pos = Vector2(current.x, current.y)
	
	# If we have a next snapshot, interpolate
	if snapshot_index < snapshots.size() - 1:
		var next = snapshots[snapshot_index + 1]
		var time_diff = next.t - current.t
		if time_diff > 0:
			var t = clampf((playback_time - current.t) / time_diff, 0.0, 1.0)
			target_pos = Vector2(
				lerpf(current.x, next.x, t),
				lerpf(current.y, next.y, t)
			)
	
	global_position = target_pos
	
	# Update facing direction
	var facing_right = current.get("fr", true)
	sprite.flip_h = not facing_right
	
	# Update animation state
	var is_attacking = current.get("atk", false)
	if is_attacking:
		if sprite.animation != "attack":
			sprite.play("attack")
	else:
		if sprite.animation != "idle" and sprite.animation != "run":
			sprite.play("run")
		# Use run animation if moving, idle if standing still
		if snapshot_index > 0:
			var prev = snapshots[snapshot_index - 1]
			var moved = absf(current.x - prev.x) > 2.0 or absf(current.y - prev.y) > 2.0
			if moved and sprite.animation != "attack":
				sprite.play("run")
			elif not moved and sprite.animation != "attack":
				sprite.play("idle")
	
	# Check if we've reached the end
	if snapshot_index >= snapshots.size() - 1 and playback_time > snapshots[-1].t + 1.0:
		ghost_finished = true
		# Fade out ghost
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
		is_playing = false