extends SceneTree

const MAIN_SCENE := preload("res://scene/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var touch: Node = main.get_node("TouchControls")
	var right := touch.get_node("SafeArea/RightCluster") as Control
	var left := touch.get_node("SafeArea/LeftCluster") as Control
	assert(not touch.has_node("SafeArea/WeaponButton"))
	assert(not touch.has_node("SafeArea/MapButton"))
	assert(not touch.has_node("SafeArea/InventoryButton"))
	assert(left.has_node("Heal") and left.has_node("VirtualJoystick"))
	assert(right.has_node("Dash") and right.has_node("Jump"))
	assert(right.has_node("Attack1") and right.has_node("Attack2"))
	var heal := left.get_node("Heal") as Node2D
	var joystick := left.get_node("VirtualJoystick") as Control
	assert(StringName(right.get_node("Attack1").get("action")) == &"attack_slot_1")
	assert(StringName(right.get_node("Attack2").get("action")) == &"attack_slot_2")
	assert((right.get_node("Dash") as Node2D).position.y < (right.get_node("Jump") as Node2D).position.y)
	assert((right.get_node("Attack2") as Node2D).position.y < (right.get_node("Attack1") as Node2D).position.y)
	assert((right.get_node("Dash") as Node2D).position.x < (right.get_node("Attack2") as Node2D).position.x)
	assert((right.get_node("Jump") as Node2D).position.x < (right.get_node("Attack1") as Node2D).position.x)
	assert(heal.position.y + float(heal.get("touch_radius")) < joystick.position.y)
	_assert_no_action_overlap(right)
	for control_scale: float in [0.8, 1.0, 1.5]:
		left.scale = Vector2.ONE * control_scale
		right.scale = Vector2.ONE * control_scale
		_assert_action_buttons_inside_viewport(touch, root.get_visible_rect().size)
	assert(not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)))
	for action in [&"attack_slot_1", &"attack_slot_2", &"open_map", &"open_inventory", &"pause_menu"]:
		assert(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty())
	var pause: Node = main.get_node("PauseMenu")
	assert(pause.process_mode == Node.PROCESS_MODE_ALWAYS)
	assert(pause.has_method("_handle_screen_touch_pressed"))
	assert(pause.has_node("Overlay/Center/MainPage/Inventory"))
	_assert_pause_settings_touch(pause)
	var minimap := main.get_node("MinimapLayer/BiomeMinimap") as Control
	assert(minimap.mouse_filter == Control.MOUSE_FILTER_STOP)
	var full_map: Node = main.get_node("FullMapLayer/FullMap")
	var inventory: Node = main.get_node("InventoryUI")
	assert(full_map.has_method("_touch_hits"))
	assert(inventory.has_method("_touch_hits"))
	_assert_modal_close_touch(full_map, full_map.get("_close_button") as Button, "visible")
	_assert_modal_close_touch(inventory, inventory.get("_close_button") as Button, "overlay")
	touch.call("_set_touch_input_active", false)
	assert(left.get_node("VirtualJoystick").mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var action_buttons := touch.get("action_buttons") as Array
	for button_value: Variant in action_buttons:
		var inactive_button := button_value as Node
		assert(not inactive_button.is_processing_input() and int(inactive_button.get("active_touch_index")) == -1)
	touch.call("_set_touch_input_active", true)
	for button_value: Variant in action_buttons:
		var active_button := button_value as Node
		assert(active_button.is_processing_input())
	main.free()
	print("ANDROID_TOUCH_HUD_MODAL_HOTFIX_SMOKE_TEST_OK")
	quit(0)


func _assert_pause_settings_touch(pause: Node) -> void:
	var overlay := pause.get_node("Overlay") as Control
	var main_page := pause.get_node("Overlay/Center/MainPage") as Control
	var settings_page := pause.get_node("Overlay/Center/SettingsPage") as Control
	var slider := pause.get_node("Overlay/Center/SettingsPage/TouchScale") as HSlider
	var back := pause.get_node("Overlay/Center/SettingsPage/Back") as Button
	overlay.visible = true
	pause.call("_show_settings")
	var slider_position := slider.get_global_rect().position + Vector2(slider.size.x * 0.75, slider.size.y * 0.5)
	pause.call("_input", _screen_touch(41, slider_position, true))
	assert(slider.value > slider.min_value)
	pause.call("_input", _screen_touch(41, slider_position, false))
	pause.call("_input", _screen_touch(42, back.get_global_rect().get_center(), true))
	assert(main_page.visible and not settings_page.visible)
	overlay.visible = false


func _assert_modal_close_touch(modal: Node, close_button: Button, visibility_property: StringName) -> void:
	if visibility_property == &"visible":
		modal.set("visible", true)
	else:
		(modal.get(visibility_property) as Control).visible = true
	modal.call("_input", _screen_touch(51, close_button.get_global_rect().get_center(), true))
	if visibility_property == &"visible":
		assert(not bool(modal.get("visible")))
	else:
		assert(not (modal.get(visibility_property) as Control).visible)


func _screen_touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _assert_no_action_overlap(right: Control) -> void:
	var buttons: Array[Node] = [
		right.get_node("Dash"),
		right.get_node("Jump"),
		right.get_node("Attack1"),
		right.get_node("Attack2"),
		right.get_node("Interact"),
	]
	for first_index in buttons.size():
		for second_index in range(first_index + 1, buttons.size()):
			var first := buttons[first_index] as Node2D
			var second := buttons[second_index] as Node2D
			assert(first.position.distance_to(second.position) > float(first.get("touch_radius")) + float(second.get("touch_radius")))


func _assert_action_buttons_inside_viewport(touch: Node, viewport_size: Vector2) -> void:
	var action_buttons := touch.get("action_buttons") as Array
	for button_value: Variant in action_buttons:
		var button := button_value as Node2D
		var transform: Transform2D = button.get_global_transform_with_canvas()
		var center: Vector2 = transform * Vector2.ZERO
		var radius: float = float(button.get("touch_radius")) * transform.get_scale().x
		assert(center.x - radius >= 0.0 and center.x + radius <= viewport_size.x)
		assert(center.y - radius >= 0.0 and center.y + radius <= viewport_size.y)
