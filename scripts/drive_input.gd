class_name DriveInput
extends Node

var steering := 0.0
var throttle := 0.0
var brake := 0.0
var enabled := true
var injected := false
var held := {"left": false, "right": false, "gas": false, "brake": false}

func _ready() -> void:
	bind("drive_left", [KEY_A, KEY_LEFT])
	bind("drive_right", [KEY_D, KEY_RIGHT])
	bind("drive_gas", [KEY_W, KEY_UP])
	bind("drive_brake", [KEY_S, KEY_DOWN, KEY_SPACE])
	bind("pause_game", [KEY_ESCAPE, KEY_P])
	bind("recover_car", [KEY_R])
	bind("reset_camera", [KEY_C])

func bind(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func sample() -> void:
	if injected:
		return
	if not enabled:
		steering = 0
		throttle = 0
		brake = 0
		return
	steering = float(held.right or Input.is_action_pressed("drive_right")) - float(held.left or Input.is_action_pressed("drive_left"))
	throttle = float(held.gas or Input.is_action_pressed("drive_gas"))
	brake = float(held.brake or Input.is_action_pressed("drive_brake"))

func clear() -> void:
	for key in held:
		held[key] = false
	steering = 0
	throttle = 0
	brake = 0
