extends CanvasLayer
# DialogueManager — Displays chapter dialogue overlays with speaker portraits
# Tap/click to advance through dialogue triggers

signal dialogue_started
signal dialogue_ended
signal dialogue_mid_trigger(trig: String)

@onready var panel = $Panel
@onready var speaker_label = $Panel/Speaker
@onready var text_label = $Panel/Text
@onready var advance_hint = $Panel/AdvanceHint

# Speaker portrait mapping
const SPEAKER_PORTRAITS := {
	"JIN": "res://assets/art/npcs/jin_portrait.webp",
	"INNKEEPER": "res://assets/art/npcs/innkeeper_portrait.webp",
	"MERCHANT": "res://assets/art/npcs/merchant_portrait.webp",
	"CRIMSON_FANG": "res://assets/art/npcs/crimson_fang_portrait.webp",
	"GATE_WARDEN": "res://assets/art/npcs/gate_warden_portrait.webp",
}

var portrait_rect: TextureRect = null

var current_queue: Array = []
var current_index := 0
var is_playing := false
var typing_speed := 0.03  # seconds per character
var typing_tween: Tween

func _ready():
	hide_dialogue()
	# Create portrait TextureRect (wired into panel)
	portrait_rect = TextureRect.new()
	portrait_rect.name = "SpeakerPortrait"
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.custom_minimum_size = Vector2(64, 64)
	portrait_rect.visible = false
	# Insert before speaker label so portrait appears on the left
	var speaker_idx = panel.get_children().find(speaker_label)
	if speaker_idx >= 0:
		panel.add_child(portrait_rect)
		panel.move_child(portrait_rect, speaker_idx)
	else:
		panel.add_child(portrait_rect)

func show_dialogue(speaker: String, text: String):
	is_playing = true
	panel.show()
	advance_hint.hide()
	speaker_label.text = speaker
	text_label.text = ""  # Typewriter effect starts empty
	
	# Load speaker portrait
	var portrait_path = SPEAKER_PORTRAITS.get(speaker, "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait_rect.texture = load(portrait_path)
		portrait_rect.visible = true
	else:
		portrait_rect.visible = false
	
	# Typewriter effect
	var chars = text.length()
	typing_tween = create_tween()
	typing_tween.set_speed_scale(1.0 / typing_speed)
	for i in range(chars):
		typing_tween.tween_callback(_append_char.bind(text[i]))
	typing_tween.finished.connect(_on_typing_done)

func _append_char(c: String):
	text_label.text += c

func _on_typing_done():
	advance_hint.show()
	advance_hint.text = "[TAP TO CONTINUE]" if DisplayServer.is_touchscreen_available() else "[PRESS SPACE / CLICK]"

func hide_dialogue():
	panel.hide()
	is_playing = false
	current_queue.clear()
	current_index = 0
	advance_hint.hide()
	if portrait_rect:
		portrait_rect.visible = false

func load_dialogue(chapter_dialogue: Array):
	current_queue = chapter_dialogue.duplicate(true)
	current_index = 0

func play_dialogue_for_trigger(trigger: String):
	var filtered := []
	for entry in current_queue:
		if entry.get("trigger", "") == trigger:
			filtered.append(entry)
	if filtered.is_empty():
		return
	current_queue = filtered
	current_index = 0
	_show_current()

func _show_current():
	if current_index < current_queue.size():
		var entry = current_queue[current_index]
		var speaker = entry.get("speaker", "")
		var text = entry.get("text", "")
		show_dialogue(speaker, text)
	else:
		finish_dialogue()

func advance():
	if typing_tween and typing_tween.is_running():
		# Skip to end
		typing_tween.kill()
		text_label.text = current_queue[current_index].get("text", "")
		_on_typing_done()
	else:
		current_index += 1
		_show_current()

func finish_dialogue():
	hide_dialogue()
	dialogue_ended.emit()

func _input(event):
	if not is_playing:
		return
	
	# Touch tap or mouse click or space
	var should_advance = false
	if event is InputEventScreenTouch and event.pressed:
		should_advance = true
	elif event is InputEventMouseButton and event.pressed:
		should_advance = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		should_advance = true
	
	if should_advance:
		advance()

# Legacy: trigger a mid-combat line
func trigger_mid_combat(dialogue_entry: Dictionary):
	# For ally mid-combat lines, push a temporary mid-combat line
	var speaker = dialogue_entry.get("speaker", "")
	var text = dialogue_entry.get("text", "")
	show_dialogue(speaker, text)
	# Auto-dismiss after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_playing and text_label.text == text:
		finish_dialogue()
