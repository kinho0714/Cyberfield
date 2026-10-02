extends SceneTree
## Godot runtime test; not equivalent to the offline contract checks.
const MENU_SCRIPT = preload("res://scene/main_menu_alive.gd")
var callback_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_emulation: bool = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = false
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var page: VBoxContainer = VBoxContainer.new()
	page.set_script(MENU_SCRIPT)
	page.position = Vector2(500, 200)
	page.custom_minimum_size = Vector2(400, 0)
	var option: OptionButton = OptionButton.new()
	for value: String in ["PRÓXIMO", "PADRÃO", "DISTANTE"]:
		option.add_item(value)
	option.item_selected.connect(func(_index: int) -> void: callback_count += 1)
	page.add_child(option)
	root.add_child(page)
	await process_frame
	await process_frame
	option.show_popup()
	await process_frame
	var popup: PopupMenu = option.get_popup()
	assert(popup.visible and Input.emulate_mouse_from_touch)
	# Middle of a three-row native popup: choose PADRÃO via real Input translation.
	var point: Vector2 = Vector2(popup.position) + Vector2(popup.size) * 0.5
	_touch(point, true)
	await process_frame
	_touch(point, false)
	await process_frame
	await process_frame
	assert(option.selected == 1 and callback_count == 1)
	assert(not popup.visible and not Input.emulate_mouse_from_touch)
	assert(root.gui_get_focus_owner() == option)
	option.show_popup()
	await process_frame
	# Outside dismissal must not leave emulation or a held mouse button behind.
	_touch(Vector2(10, 10), true)
	await process_frame
	_touch(Vector2(10, 10), false)
	await process_frame
	await process_frame
	assert(not popup.visible and not Input.emulate_mouse_from_touch)
	assert(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	option.show_popup()
	await process_frame
	assert(popup.visible)
	point = Vector2(popup.position) + Vector2(popup.size) * 0.5
	_touch(point, true)
	await process_frame
	page.free()
	await process_frame
	assert(not Input.emulate_mouse_from_touch)
	assert(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	Input.emulate_mouse_from_touch = original_emulation
	print("PASS6_DROPDOWN_MODAL_SMOKE_TEST_PASSED")
	quit(0)


func _touch(position: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
