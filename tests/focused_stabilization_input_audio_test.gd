extends SceneTree

const MAIN = preload("res://scene/main.tscn")
const PLAYER = preload("res://entities/player.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame
	var touch := main.get_node("TouchControls")
	var joystick := main.get_node("TouchControls/SafeArea/LeftCluster/VirtualJoystick")
	var audio := main.get_node("AudioService")
	var mode := main.get_node("ModeSelect")
	var visual := main.get_node("MenuEnvironment/AnimatedMenuBackground")
	assert(InputMap.has_action(&"touch_left") and InputMap.has_action(&"touch_right"))
	assert(InputMap.has_action(&"ui_accept") and _has_ui_button(&"ui_accept", JOY_BUTTON_A))
	assert(_has_ui_button(&"ui_cancel", JOY_BUTTON_B))
	assert(mode.play_button.has_focus(), "Initial title menu must have visible focus")

	var player := PLAYER.instantiate()
	player.input_profile = "p1"
	root.add_child(player)
	await physics_frame
	# Hold the physical action across >2 seconds of physics frames and through
	# touch-UI visibility changes. Release of inactive touch must not cancel it.
	Input.action_press(&"right")
	for step in 150:
		if step % 17 == 0:
			touch.set_menu_blocked(step % 2 == 0)
		if step == 40:
			Input.action_press(&"dash")
		elif step == 42:
			Input.action_release(&"dash")
		elif step == 75:
			player.set_input_enabled(false)
		elif step == 79:
			player.set_input_enabled(true)
		assert(player.get_movement_direction() > 0.9, "Held direction lost at frame %d" % step)
		await physics_frame
		if step > 2 and player.input_enabled:
			assert(player.velocity.x > 0.0, "Movement velocity stalled while holding right at frame %d" % step)
	Input.action_release(&"dash")
	Input.action_press(&"touch_left")
	assert(player.get_movement_direction() < -0.9, "Active touch must override physical direction")
	joystick.release_input()
	assert(player.get_movement_direction() > 0.9, "Touch release erased physical held direction")
	Input.action_release(&"right")
	assert(is_zero_approx(player.get_movement_direction()))

	assert(audio.music_streams.get(&"main_menu") != null)
	assert((audio.music_streams[&"main_menu"] as AudioStreamOggVorbis).loop)
	assert(audio.get_node("MenuRain").bus == &"Ambience")
	assert(audio.get_node("MenuCity").bus == &"Ambience")
	assert((audio.get_node("MenuCity").stream as AudioStreamOggVorbis).loop)
	assert(AudioServer.get_bus_index(&"Ambience") >= 0)
	var thunder_count := [0]
	visual.lightning_struck.connect(func() -> void: thunder_count[0] += 1)
	assert(visual.is_visible_in_tree())
	visual.trigger_lightning()
	assert(thunder_count[0] == 1, "Visual lightning signal not emitted once")
	assert(audio.get_node_or_null("OneShot_menu_thunder") != null, "Thunder event did not trigger SFX")

	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.device = 4
	event.pressed = true
	# An unplugged simulated device is not dispatched by Godot's input backend
	# in headless mode; invoke the menu handler with the raw event directly.
	var menu_input := main.get_node("GamepadMenuInput")
	menu_input._input(event)
	await process_frame
	assert(mode.players_page.visible and mode.solo_button.has_focus(), "Gamepad A did not confirm focused menu button")
	var cancel_event := InputEventJoypadButton.new()
	cancel_event.device = 4
	cancel_event.button_index = JOY_BUTTON_B
	cancel_event.pressed = true
	# B / Circle is a gameplay dash; its UI-cancel binding must not open Pause.
	var pause := main.get_node("PauseMenu")
	main.mode_selected = true
	pause._input(cancel_event)
	assert(not pause.overlay.visible, "Dash button opened Pause during gameplay")
	main.mode_selected = false
	mode._input(cancel_event)
	assert(mode.main_page.visible and mode.play_button.has_focus(), "Gamepad B did not navigate back")
	menu_input._input(event)
	assert(mode.players_page.visible and mode.solo_button.has_focus())
	menu_input._input(event)
	assert(mode.difficulty_page.visible and mode.normal_button.has_focus(), "Solo choice not confirmed")
	var requested := [false]
	mode.run_requested.connect(func(_mode: StringName, _difficulty: StringName, _joypad: int) -> void: requested[0] = true)
	menu_input._input(event)
	assert(requested[0], "Gamepad-only title flow did not request the run")
	LocalCoopInput.ensure_player_two_actions(5)
	assert(_has_device_button(&"p2_attack_slot_2", JOY_BUTTON_RIGHT_SHOULDER, 5), "P2 secondary attack missing")
	assert(_has_device_button(&"p2_attack_slot_1", JOY_BUTTON_X, 5), "P2 primary attack missing")
	LocalCoopInput.ensure_player_one_actions(4)
	assert(_has_device_button(&"attack_slot_2", JOY_BUTTON_RIGHT_SHOULDER, 4), "P1 secondary attack missing")
	assert(_has_device_button(&"dash", JOY_BUTTON_B, 4), "P1 dash missing")
	LocalCoopInput.ensure_player_one_actions(-1)
	player.queue_free()
	main.queue_free()
	await process_frame
	await process_frame
	print("FOCUSED_STABILIZATION_INPUT_AUDIO_TEST_OK")
	quit(0)


func _has_ui_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false


func _has_device_button(action: StringName, button: JoyButton, device_id: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button and event.device == device_id:
			return true
	return false
