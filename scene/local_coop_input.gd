class_name LocalCoopInput
extends RefCounted


static func ensure_player_two_actions(device_id: int) -> void:
	if device_id < 0:
		push_error("Player 2 input requires a connected joypad device ID")
		return
	_add_action(&"p2_left", 0.25)
	_add_action(&"p2_right", 0.25)
	_add_action(&"p2_down", 0.25)
	_add_action(&"p2_jump")
	_add_action(&"p2_attack")
	_add_action(&"p2_dash")
	_add_action(&"p2_interact")
	_add_action(&"p2_heal")

	for action in [&"p2_left", &"p2_right", &"p2_down", &"p2_jump", &"p2_attack", &"p2_dash", &"p2_interact", &"p2_heal"]:
		InputMap.action_erase_events(action)

	_add_axis(&"p2_left", JOY_AXIS_LEFT_X, -1.0, device_id)
	_add_axis(&"p2_right", JOY_AXIS_LEFT_X, 1.0, device_id)
	_add_axis(&"p2_down", JOY_AXIS_LEFT_Y, 1.0, device_id)
	_add_button(&"p2_left", JOY_BUTTON_DPAD_LEFT, device_id)
	_add_button(&"p2_right", JOY_BUTTON_DPAD_RIGHT, device_id)
	_add_button(&"p2_down", JOY_BUTTON_DPAD_DOWN, device_id)
	_add_button(&"p2_jump", JOY_BUTTON_A, device_id)
	_add_button(&"p2_attack", JOY_BUTTON_X, device_id)
	_add_button(&"p2_dash", JOY_BUTTON_B, device_id)
	_add_button(&"p2_interact", JOY_BUTTON_Y, device_id)
	_add_button(&"p2_heal", JOY_BUTTON_LEFT_SHOULDER, device_id)


static func _add_action(action: StringName, deadzone := 0.2) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		InputMap.action_set_deadzone(action, deadzone)


static func _add_axis(action: StringName, axis: JoyAxis, value: float, device_id: int) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device_id
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)


static func _add_button(action: StringName, button: JoyButton, device_id: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device_id
	event.button_index = button
	InputMap.action_add_event(action, event)
