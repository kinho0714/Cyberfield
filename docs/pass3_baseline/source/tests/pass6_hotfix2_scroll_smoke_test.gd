extends SceneTree
## Runtime test: Godot --headless --path . --script res://tests/pass6_hotfix2_scroll_smoke_test.gd
const PAUSE = preload("res://scene/pause_menu.tscn")
const SETTINGS = preload("res://scene/local_settings.gd")
class Harness extends Node:
	var mode_selected: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var harness: Harness = Harness.new()
	root.add_child(harness)
	var settings: LocalSettings = SETTINGS.new()
	settings.name = "LocalSettings"
	settings.settings_path = "user://pass6_hotfix2_test.cfg"
	harness.add_child(settings)
	var pause: Node = PAUSE.instantiate()
	harness.add_child(pause)
	pause.overlay.visible = true
	pause._show_settings()
	await process_frame
	await process_frame
	var scroll: ScrollContainer = pause.settings_scroll
	var slider: HSlider = pause.touch_slider
	var value_before: float = slider.value
	var point: Vector2 = slider.get_global_rect().get_center()
	_touch(pause, point, true)
	assert(slider.value == value_before)
	_drag(pause, point - Vector2(0, 150))
	_touch(pause, point - Vector2(0, 150), false)
	assert(scroll.scroll_vertical > 0 and slider.value == value_before)
	point = scroll.get_global_rect().get_center()
	_touch(pause, point, true)
	_drag(pause, point - Vector2(0, 2000))
	_touch(pause, point - Vector2(0, 2000), false)
	await process_frame
	var dialogue: HSlider = pause.audio_sliders[3]
	assert(scroll.get_global_rect().intersects(dialogue.get_global_rect()))
	_touch(pause, point, true)
	_drag(pause, point + Vector2(0, 2000))
	_touch(pause, point + Vector2(0, 2000), false)
	assert(scroll.scroll_vertical == 0)
	await process_frame
	point = slider.get_global_rect().position + slider.size * 0.5
	_touch(pause, point, true)
	_drag(pause, point + Vector2(100, 0))
	_touch(pause, point + Vector2(100, 0), false)
	assert(slider.value != value_before)
	assert(pause.options_touch_index == -1)
	assert(scroll.follow_focus)
	harness.free()
	DirAccess.remove_absolute("user://pass6_hotfix2_test.cfg")
	print("PASS6_HOTFIX2_SCROLL_SMOKE_TEST_PASSED")
	quit(0)


func _touch(pause: Node, position: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	pause._input(event)


func _drag(pause: Node, position: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	pause._input(event)
