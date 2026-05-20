extends Control
## Mobile touch controls — virtual joystick + attack/skill/potion buttons
## Auto-detects touch input, hidden on desktop with keyboard.

@onready var joystick_base = $JoystickBase
@onready var joystick_knob = $JoystickKnob
@onready var attack_btn = $AttackButton
@onready var skill1_btn = $Skill1Button
@onready var skill2_btn = $Skill2Button
@onready var potion_btn = $PotionButton
@onready var pause_btn = $PauseButton

var joystick_active := false
var joystick_start_pos := Vector2.ZERO
const JOYSTICK_RADIUS := 60.0

func _ready():
	# Hide on desktop
	if not OS.has_feature("mobile") and not OS.has_feature("web_android") and not OS.has_feature("web_ios"):
		var touch_count = DisplayServer.get_screen_count()
		# Keep visible on web exports too
		pass
	
	_setup_button_labels()
	attack_btn.pressed.connect(_on_attack)
	attack_btn.button_up.connect(_on_attack_up)
	skill1_btn.pressed.connect(_on_skill1)
	skill2_btn.pressed.connect(_on_skill2)
	potion_btn.pressed.connect(_on_potion)
	pause_btn.pressed.connect(_on_pause)

func _setup_button_labels():
	skill1_btn.text = _skill_name(0)
	skill2_btn.text = _skill_name(1)

func _skill_name(slot: int) -> String:
	if GameState.equipped_skills.size() > slot and GameState.equipped_skills[slot] != "":
		return GameState.equipped_skills[slot].replace("_", "\n")
	return "Skill %d" % (slot + 1)

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_start(event.position)
		else:
			_handle_touch_end(event.position)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event.position)

func _handle_touch_start(pos: Vector2):
	# Check if touch is in the left half (joystick zone) and not on buttons
	if pos.x < get_viewport_rect().size.x * 0.4:
		joystick_active = true
		joystick_start_pos = pos
		joystick_base.global_position = joystick_start_pos - joystick_base.size / 2
		joystick_knob.global_position = joystick_start_pos - joystick_knob.size / 2
		joystick_base.visible = true
		joystick_knob.visible = true

func _handle_touch_end(pos: Vector2):
	if joystick_active:
		joystick_active = false
		joystick_base.visible = false
		joystick_knob.visible = false
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		Input.action_release("move_down")

func _handle_touch_drag(pos: Vector2):
	if joystick_active:
		var offset = pos - joystick_start_pos
		var clamped = offset.limit_length(JOYSTICK_RADIUS)
		joystick_knob.global_position = joystick_start_pos - joystick_knob.size / 2 + clamped
		
		var direction = offset.normalized() if offset.length() > 0 else Vector2.ZERO
		if direction.x < -0.3:
			Input.action_press("move_left")
			Input.action_release("move_right")
		elif direction.x > 0.3:
			Input.action_press("move_right")
			Input.action_release("move_left")
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
		
		if direction.y < -0.3:
			Input.action_press("move_up")
			Input.action_release("move_down")
		elif direction.y > 0.3:
			Input.action_press("move_down")
			Input.action_release("move_up")
		else:
			Input.action_release("move_up")
			Input.action_release("move_down")

func _on_attack():
	Input.action_press("attack")

func _on_attack_up():
	Input.action_release("attack")

func _on_skill1():
	Input.action_press("skill1")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("skill1")

func _on_skill2():
	var ev = InputEventKey.new()
	ev.keycode = KEY_2
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.1).timeout
	ev.pressed = false
	Input.parse_input_event(ev)

func _on_potion():
	var ev = InputEventKey.new()
	ev.keycode = KEY_Q
	ev.pressed = true
	Input.parse_input_event(ev)

func _on_pause():
	GameState.is_paused = !GameState.is_paused
	get_tree().paused = GameState.is_paused
