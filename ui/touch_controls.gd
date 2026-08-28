extends CanvasLayer

@onready var run_manager: Node = get_parent().get_node("RunManager")
@onready var safe_area: Control = $SafeArea
@onready var joystick: Control = $SafeArea/LeftCluster/VirtualJoystick
@onready var left_cluster: Control = $SafeArea/LeftCluster
@onready var right_cluster: Control = $SafeArea/RightCluster
@onready var local_settings: LocalSettings = get_parent().get_node("LocalSettings")

var menu_blocked := false


func _ready() -> void:
	# Keep this development overlay out of desktop builds that have no touch input.
	visible = false
	run_manager.state_changed.connect(_refresh_visibility)
	get_viewport().size_changed.connect(_apply_safe_area)
	local_settings.settings_changed.connect(_apply_control_scale)
	$SafeArea/PauseButton.pressed.connect(_open_pause_menu)
	$SafeArea/WeaponButton.pressed.connect(_switch_weapon)
	_apply_safe_area()
	_apply_control_scale()
	_refresh_visibility()


func _refresh_visibility() -> void:
	var should_be_visible: bool = not menu_blocked and _touchscreen_is_available() and bool(run_manager.is_gameplay_context_active())
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


func _apply_control_scale() -> void:
	var control_scale: float = local_settings.touch_control_scale
	var scale_delta: float = control_scale - 1.0
	left_cluster.pivot_offset = left_cluster.size * 0.5
	right_cluster.pivot_offset = right_cluster.size * 0.5
	left_cluster.scale = Vector2.ONE * control_scale
	right_cluster.scale = Vector2.ONE * control_scale
	left_cluster.offset_top = -202.0 - maxf(scale_delta, 0.0) * 100.0
	left_cluster.offset_bottom = -2.0 - maxf(scale_delta, 0.0) * 100.0
	right_cluster.offset_left = -424.0 - maxf(scale_delta, 0.0) * 190.0
	right_cluster.offset_right = -24.0 - maxf(scale_delta, 0.0) * 190.0
	right_cluster.offset_top = -326.0 - maxf(scale_delta, 0.0) * 145.0
	right_cluster.offset_bottom = -36.0 - maxf(scale_delta, 0.0) * 145.0


func _open_pause_menu() -> void:
	var pause_menu := get_tree().get_first_node_in_group("pause_menu")
	if pause_menu != null and pause_menu.has_method("toggle_menu"):
		pause_menu.toggle_menu()


func _switch_weapon() -> void:
	Input.action_press(&"switch_weapon")
	await get_tree().physics_frame
	Input.action_release(&"switch_weapon")


func set_menu_blocked(value: bool) -> void:
	menu_blocked = value
	_refresh_visibility()
