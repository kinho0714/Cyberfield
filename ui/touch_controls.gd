extends CanvasLayer

@onready var run_manager: Node = get_parent().get_node("RunManager")
@onready var safe_area: Control = $SafeArea
@onready var pause_button: Button = $SafeArea/PauseButton
@onready var joystick: Control = $SafeArea/LeftCluster/VirtualJoystick
@onready var left_cluster: Control = $SafeArea/LeftCluster
@onready var right_cluster: Control = $SafeArea/RightCluster
@onready var local_settings: LocalSettings = get_parent().get_node("LocalSettings")
@onready var action_buttons: Array[Node] = [
	$SafeArea/LeftCluster/Heal,
	$SafeArea/RightCluster/Dash,
	$SafeArea/RightCluster/Jump,
	$SafeArea/RightCluster/Attack1,
	$SafeArea/RightCluster/Attack2,
	$SafeArea/RightCluster/Interact,
]

var menu_blocked := false


func _ready() -> void:
	# Keep this development overlay out of desktop builds that have no touch input.
	visible = false
	run_manager.state_changed.connect(_refresh_visibility)
	get_viewport().size_changed.connect(_apply_safe_area)
	local_settings.settings_changed.connect(_apply_control_scale)
	pause_button.pressed.connect(_open_pause_menu)
	_apply_safe_area()
	_apply_control_scale()
	_refresh_visibility()


func _input(event: InputEvent) -> void:
	if (
		visible
		and not menu_blocked
		and event is InputEventScreenTouch
		and event.pressed
		and pause_button.get_global_rect().has_point(event.position)
	):
		_open_pause_menu()
		get_viewport().set_input_as_handled()


func _refresh_visibility() -> void:
	var should_be_visible: bool = not menu_blocked and _touchscreen_is_available() and bool(run_manager.is_gameplay_context_active())
	_set_touch_input_active(should_be_visible)
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


func _apply_control_scale() -> void:
	var control_scale: float = local_settings.touch_control_scale
	# Scale inward/upward while keeping the safe-area corners fixed.
	left_cluster.pivot_offset = Vector2(0.0, left_cluster.size.y)
	right_cluster.pivot_offset = right_cluster.size
	left_cluster.scale = Vector2.ONE * control_scale
	right_cluster.scale = Vector2.ONE * control_scale


func _open_pause_menu() -> void:
	var pause_menu := get_tree().get_first_node_in_group("pause_menu")
	if pause_menu != null and pause_menu.has_method("toggle_menu"):
		pause_menu.toggle_menu()


func set_menu_blocked(value: bool) -> void:
	menu_blocked = value
	_refresh_visibility()


func _set_touch_input_active(value: bool) -> void:
	if not value:
		if joystick.has_method("release_input"):
			joystick.release_input()
		for button in action_buttons:
			if button.has_method("release_input"):
				button.release_input()
	joystick.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	for button in action_buttons:
		button.set_process_input(value)
