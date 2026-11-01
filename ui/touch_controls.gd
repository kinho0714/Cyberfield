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
## 01/11/2026: dois botões dos slots ativos (acessórios), criados aqui para não mexer
## na cena; o ícone acompanha o acessório equipado no jogador local.
const GADGET_FRAME := preload("res://assets/ui/gameplay_hud/assets/mobile/actions/action_frame_magenta.png")
const GADGET_POSITIONS := [Vector2(190, 38), Vector2(305, 38)]
var gadget_buttons: Array[Node2D] = []


func _ready() -> void:
	# Touch directional input must not release a held keyboard/gamepad action.
	for touch_action: StringName in [&"touch_left", &"touch_right", &"touch_down"]:
		if not InputMap.has_action(touch_action):
			InputMap.add_action(touch_action, 0.0)
	var pause_style := StyleBoxTexture.new()
	pause_style.texture = preload("res://assets/ui/gameplay_hud/assets/shared/hud/pause_button_frame.png")
	for state in ["normal", "hover", "pressed", "focus"]:
		pause_button.add_theme_stylebox_override(state, pause_style)
	add_child(preload("res://ui/mobile_presentation_feedback.gd").new())
	_build_gadget_buttons()
	# Keep this development overlay out of desktop builds that have no touch input.
	visible = false
	run_manager.state_changed.connect(_refresh_visibility)
	get_viewport().size_changed.connect(_apply_safe_area)
	local_settings.settings_changed.connect(_apply_control_scale)
	pause_button.pressed.connect(_open_pause_menu)
	_apply_safe_area()
	_apply_control_scale()
	_refresh_visibility()


func _build_gadget_buttons() -> void:
	for slot in GADGET_POSITIONS.size():
		var button := preload("res://ui/mobile_action_button.gd").new() as Node2D
		button.name = "Gadget%d" % (slot + 1)
		button.set("action", StringName("gadget_%d" % (slot + 1)))
		button.set("touch_radius", 38.0)
		button.position = GADGET_POSITIONS[slot]
		var frame := Sprite2D.new()
		frame.name = "Visual"
		frame.texture = GADGET_FRAME
		frame.scale = Vector2(0.72, 0.72)
		button.add_child(frame)
		var icon := Sprite2D.new()
		icon.name = "Icon"
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.scale = Vector2(1.4, 1.4)
		button.add_child(icon)
		var label := Label.new()
		label.name = "Label"
		label.text = "ITEM %d" % (slot + 1)
		label.position = Vector2(-40, 30)
		label.size = Vector2(80, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 14)
		button.add_child(label)
		right_cluster.add_child(button)
		gadget_buttons.append(button)
		action_buttons.append(button)


func _process(_delta: float) -> void:
	if not visible or gadget_buttons.is_empty():
		return
	var local_player: Node = null
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate.get("input_profile") == "p1" and not bool(candidate.get("network_remote_replica")):
			local_player = candidate
			break
	var gadgets: PlayerGadgets = local_player.get("gadgets") if local_player != null else null
	for slot in gadget_buttons.size():
		var accessory_id: StringName = gadgets.slots[slot] if gadgets != null else &""
		var button := gadget_buttons[slot]
		button.visible = not accessory_id.is_empty()
		if accessory_id.is_empty():
			continue
		(button.get_node("Icon") as Sprite2D).texture = AccessoryCatalog.icon(accessory_id)
		button.modulate = Color.WHITE if gadgets.charges[slot] > 0 else Color(0.5, 0.5, 0.55, 0.8)
		(button.get_node("Label") as Label).text = "%s %d" % [AccessoryCatalog.get_definition(accessory_id).get("short", "ITEM"), gadgets.charges[slot]]


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
