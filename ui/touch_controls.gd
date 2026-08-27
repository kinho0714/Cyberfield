extends CanvasLayer

@onready var run_manager: Node = get_parent().get_node("RunManager")
@onready var safe_area: Control = $SafeArea
@onready var joystick: Control = $SafeArea/LeftCluster/VirtualJoystick


func _ready() -> void:
	# Keep this development overlay out of desktop builds that have no touch input.
	visible = false
	run_manager.state_changed.connect(_refresh_visibility)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_refresh_visibility()


func _refresh_visibility() -> void:
	var should_be_visible: bool = _touchscreen_is_available() and bool(run_manager.get("run_active"))
	if visible and not should_be_visible and joystick.has_method("release_input"):
		joystick.release_input()
	visible = should_be_visible


func _touchscreen_is_available() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _apply_safe_area() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_position := Vector2.ZERO
	var safe_end := viewport_size
	if OS.has_feature("mobile"):
		var display_size := Vector2(DisplayServer.screen_get_size())
		var display_safe_area := DisplayServer.get_display_safe_area()
		if display_size.x > 0.0 and display_size.y > 0.0 and display_safe_area.size.x > 0 and display_safe_area.size.y > 0:
			var display_to_viewport := viewport_size / display_size
			safe_position = Vector2(display_safe_area.position) * display_to_viewport
			safe_end = Vector2(display_safe_area.end) * display_to_viewport

	# SafeArea uses full-rect anchors. These offsets inset its edges from notches,
	# rounded corners and system bars while keeping all children anchor-based.
	safe_area.offset_left = clampf(safe_position.x, 0.0, viewport_size.x)
	safe_area.offset_top = clampf(safe_position.y, 0.0, viewport_size.y)
	safe_area.offset_right = clampf(safe_end.x, 0.0, viewport_size.x) - viewport_size.x
	safe_area.offset_bottom = clampf(safe_end.y, 0.0, viewport_size.y) - viewport_size.y
