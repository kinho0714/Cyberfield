extends Node

## Menu-only face-button confirmation fallback for gamepads with working D-pad
## navigation but no native GUI activation. Runs before GUI dispatch.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_ui_button(&"ui_accept", JOY_BUTTON_A)
	_register_ui_button(&"ui_cancel", JOY_BUTTON_B)


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton):
		return
	var joy_event := event as InputEventJoypadButton
	if not joy_event.pressed or joy_event.is_echo() or joy_event.button_index != JOY_BUTTON_A:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree() or focused.focus_mode == Control.FOCUS_NONE:
		return
	var room_manager := get_parent()
	var run_manager := room_manager.get_node_or_null("RunManager")
	if run_manager != null and room_manager.mode_selected and run_manager.game_mode == &"coop" and joy_event.device == run_manager.p2_joypad_device_id:
		# P2 uses its own input profile for attribute choices and gameplay.
		return
	if focused is OptionButton:
		if not (focused as OptionButton).disabled:
			(focused as OptionButton).show_popup()
			get_viewport().set_input_as_handled()
	elif focused is BaseButton:
		var button := focused as BaseButton
		if button.disabled:
			return
		if button.toggle_mode:
			button.button_pressed = not button.button_pressed
		else:
			button.pressed.emit()
		get_viewport().set_input_as_handled()


func _register_ui_button(action: StringName, button_index: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for bound_event: InputEvent in InputMap.action_get_events(action):
		if bound_event is InputEventJoypadButton and bound_event.device == -1 and bound_event.button_index == button_index:
			return
	var joy_event := InputEventJoypadButton.new()
	joy_event.device = -1
	joy_event.button_index = button_index
	InputMap.action_add_event(action, joy_event)
