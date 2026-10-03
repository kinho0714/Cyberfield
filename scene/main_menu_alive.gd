extends VBoxContainer

const WHITE := Color("f2f7ff")
const DIM := Color("6c8596")
const CYAN := Color("39dff2")
const TRANSITION_TIME := 0.18

@export var compact := false
@export var draw_frame := true
@export var options_legibility := false

var selection_style: StyleBoxFlat
var page_tween: Tween
var stick_direction := 0
var stick_repeat := 0.0
var stick_device := -1
var stick_armed := false
var modal_option: OptionButton
var popup_mouse_override := false
var previous_mouse_emulation := false
var awaiting_popup_release := false
var popup_touch_index := -1


func _ready() -> void:
	selection_style = StyleBoxFlat.new()
	selection_style.bg_color = Color(0.025, 0.16, 0.21, 0.35)
	selection_style.border_color = CYAN
	selection_style.set_border_width_all(2)
	# Sorting only invalidates the drawing; geometry is read later in _draw().
	sort_children.connect(queue_redraw)
	add_theme_constant_override("separation", 8 if compact else 10)
	for child in get_children():
		if child is Label:
			var label := child as Label
			label.add_theme_font_size_override("font_size", 28 if child.name == &"Title" else 22)
			label.add_theme_color_override("font_color", CYAN if child.name == &"Title" else (WHITE if options_legibility else Color("aabcca")))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			var label_margin := StyleBoxEmpty.new()
			label_margin.content_margin_left = 26.0
			label_margin.content_margin_right = 24.0
			label.add_theme_stylebox_override("normal", label_margin)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = custom_minimum_size.x
			if child.name == &"Title":
				label.custom_minimum_size.y = 44.0
			else:
				label.max_lines_visible = -1
		if not (child is Control) or child.focus_mode == Control.FOCUS_NONE:
			continue
		var control := child as Control
		control.mouse_entered.connect(_focus_control.bind(control))
		control.focus_entered.connect(_refresh)
		control.focus_exited.connect(_defer_refresh)
		control.resized.connect(_defer_refresh)
		control.item_rect_changed.connect(queue_redraw)
		control.add_theme_font_size_override("font_size", 24 if compact else 26)
		if control is BaseButton or control is LineEdit or control is HSlider:
			control.custom_minimum_size.y = 52.0 if compact else 56.0
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 26.0
		empty.content_margin_right = 24.0
		empty.content_margin_top = 8.0
		empty.content_margin_bottom = 8.0
		if control is BaseButton:
			for state in ["normal", "hover", "focus", "pressed", "disabled", "hover_pressed"]:
				control.add_theme_stylebox_override(state, empty)
			control.add_theme_color_override("font_color", Color("bbccd9"))
			for state in ["font_hover_color", "font_focus_color", "font_pressed_color"]:
				control.add_theme_color_override(state, WHITE)
			control.add_theme_color_override("font_disabled_color", DIM)
			(control as Button).alignment = HORIZONTAL_ALIGNMENT_LEFT
		else:
			# Keep native editing/list/slider behavior and functional surfaces.
			control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if control is LineEdit or control is ItemList:
			var surface := StyleBoxFlat.new()
			surface.bg_color = Color(0.005, 0.015, 0.03, 0.25)
			surface.content_margin_left = 26.0
			surface.content_margin_right = 24.0
			control.add_theme_stylebox_override("panel" if control is ItemList else "normal", surface)
		if control is OptionButton:
			_style_dropdown(control.get_popup())
			control.get_popup().about_to_popup.connect(_popup_opening.bind(control))
			control.get_popup().popup_hide.connect(_popup_closed)
			control.get_popup().window_input.connect(_popup_window_input)
	visibility_changed.connect(_visibility_changed)
	resized.connect(_defer_refresh)
	call_deferred("_visibility_changed")


func _input(event: InputEvent) -> void:
	if awaiting_popup_release:
		# An outside press can dismiss the popup before its release. Keep that gesture
		# modal, including its emulated mouse release, instead of clicking the page.
		_popup_window_input(event)
		call_deferred("_finish_popup_input")
		get_viewport().set_input_as_handled()
		return
	if not is_visible_in_tree() or not (event is InputEventJoypadMotion):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or focus.get_parent() != self or event.axis != JOY_AXIS_LEFT_Y:
		return
	if focus is OptionButton and focus.get_popup().visible:
		stick_direction = 0
		return
	# Rearm at neutral on every page: a held stick must not skip the initial item.
	if absf(event.axis_value) < 0.30:
		stick_armed = true
		stick_direction = 0
	elif stick_armed and absf(event.axis_value) >= 0.55:
		var direction := 1 if event.axis_value > 0.0 else -1
		if direction != stick_direction:
			stick_direction = direction
			stick_device = event.device
			stick_repeat = 0.35
			_move_focus(direction)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Also catch text/theme changes and position-only updates. No cached rectangle.
	if is_visible_in_tree():
		queue_redraw()
	if not is_visible_in_tree() or stick_direction == 0:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or focus.get_parent() != self or not Input.get_connected_joypads().has(stick_device):
		stick_direction = 0
		return
	if focus is OptionButton and focus.get_popup().visible:
		stick_direction = 0
		return
	if absf(Input.get_joy_axis(stick_device, JOY_AXIS_LEFT_Y)) < 0.30:
		stick_direction = 0
		return
	stick_repeat -= delta
	if stick_repeat <= 0.0:
		stick_repeat = 0.20
		_move_focus(stick_direction)


func _move_focus(direction: int) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or focus.get_parent() != self:
		return
	if focus is OptionButton and focus.get_popup().visible:
		# The native popup owns selection while open; never change its value behind it.
		return
	var neighbor: Control = focus.find_valid_focus_neighbor(SIDE_BOTTOM if direction > 0 else SIDE_TOP)
	if neighbor != null and neighbor != focus:
		neighbor.grab_focus()
		return
	var items: Array[Control] = []
	for child in get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL and child.is_visible_in_tree():
			if child is BaseButton and child.disabled:
				continue
			items.append(child)
	if not items.is_empty():
		var index := items.find(focus)
		items[wrapi(index + direction, 0, items.size())].grab_focus()


func _focus_control(control: Control) -> void:
	if popup_mouse_override:
		return
	if control is BaseButton and control.disabled:
		return
	if control.is_visible_in_tree():
		control.grab_focus()


func _defer_refresh() -> void:
	call_deferred("_refresh")


func _visibility_changed() -> void:
	if not is_visible_in_tree() and is_instance_valid(modal_option):
		modal_option.get_popup().hide()
	queue_redraw()
	stick_direction = 0
	stick_armed = true
	for device in Input.get_connected_joypads():
		if absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)) >= 0.30:
			stick_armed = false
	if page_tween != null:
		page_tween.kill()
	# Hidden pages cannot retain an interrupted fade on their next entry.
	modulate.a = 1.0
	if is_visible_in_tree():
		# Only page roots resize the shared right-anchored container.
		if get_parent() is MarginContainer:
			get_parent().offset_left = -48.0 - get_combined_minimum_size().x
		modulate.a = 0.35
		page_tween = create_tween()
		page_tween.tween_property(self, "modulate:a", 1.0, TRANSITION_TIME)
		call_deferred("_refresh")


func _refresh() -> void:
	queue_redraw()
	if not is_visible_in_tree():
		return
	var selected: Control = get_viewport().gui_get_focus_owner()
	if selected != null and (selected.get_parent() != self or not selected.is_visible_in_tree()):
		selected = null
	if selected is BaseButton and selected.disabled:
		selected = null
	for child in get_children():
		if child is BaseButton:
			var text_color: Color = WHITE if child == selected or options_legibility else Color("92aabb")
			child.add_theme_color_override("font_color", text_color)
			child.add_theme_color_override("font_hover_color", text_color)


func _draw() -> void:
	if draw_frame:
		_draw_compact_frame()
	# Canvas drawing uses the current layout, not the earlier focus callback geometry.
	if selection_style == null or not is_visible_in_tree():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null or focus.get_parent() != self or not focus.is_visible_in_tree():
		return
	# Only menu actions: titles, fields, sliders and toggles keep their own visuals.
	if focus.get_class() != "Button":
		return
	var button: Button = focus as Button
	if button.disabled:
		return
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_string_size(button.tr(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var normal: StyleBox = button.get_theme_stylebox("normal")
	var padding: Vector2 = Vector2(12.0, 8.0)
	var box_size: Vector2 = text_size + padding * 2.0
	# Buttons are left-aligned with symmetric vertical margins; both nodes share space.
	var box_position: Vector2 = button.position + Vector2(
		normal.get_content_margin(SIDE_LEFT) - padding.x,
		(button.size.y - box_size.y) * 0.5
	)
	# Never clamp to a stale Control width or interpolate through an old page/title.
	draw_style_box(selection_style, Rect2(box_position, box_size))


func _draw_compact_frame() -> void:
	# Pure presentation: drawing does not add Controls or intercept input.
	if not is_visible_in_tree():
		return
	var left: float = -8.0
	var right: float = size.x + 8.0
	var top: float = -10.0
	var bottom: float = size.y + 10.0
	var cut: float = 9.0
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(left + cut, top), Vector2(right, top),
		Vector2(right, bottom - cut), Vector2(right - cut, bottom),
		Vector2(left, bottom), Vector2(left, top + cut), Vector2(left + cut, top)
	])
	draw_colored_polygon(outline, Color(0.01, 0.035, 0.05, 0.82 if options_legibility else 0.10))
	draw_polyline(outline, Color(0.22, 0.87, 0.95, 0.78), 1.0, true)
	# Short rails/corner cuts give the frame structure without an opaque surface.
	draw_line(Vector2(left + cut, top - 3.0), Vector2(left + 64.0, top - 3.0), CYAN, 1.0)
	draw_line(Vector2(right + 3.0, top + 12.0), Vector2(right + 3.0, top + 40.0), CYAN, 1.0)
	draw_line(Vector2(right - 64.0, bottom + 3.0), Vector2(right - cut, bottom + 3.0), CYAN, 1.0)
	var title: Label = get_node_or_null("Title") as Label
	if title != null:
		var line_y: float = title.position.y + title.size.y + 3.0
		draw_line(Vector2(18.0, line_y), Vector2(size.x - 18.0, line_y), Color(0.22, 0.87, 0.95, 0.25), 1.0)


func _popup_opening(control: OptionButton) -> void:
	if popup_mouse_override:
		return
	modal_option = control
	previous_mouse_emulation = Input.emulate_mouse_from_touch
	popup_mouse_override = true
	popup_touch_index = -1
	stick_direction = 0
	# Godot 4.7.2 PopupMenu consumes mouse/key events, not raw ScreenTouch.
	# The project disables this globally for gameplay; enable only for the modal.
	Input.emulate_mouse_from_touch = true


func _popup_window_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and popup_touch_index < 0:
			popup_touch_index = event.index
		elif not event.pressed and event.index == popup_touch_index:
			popup_touch_index = -1


func _popup_closed() -> void:
	if not popup_mouse_override:
		return
	awaiting_popup_release = true
	call_deferred("_finish_popup_input")


func _finish_popup_input() -> void:
	if not awaiting_popup_release or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	# Event-driven: no frame polling. Selection closes on release; outside-click
	# dismissal waits for release so the engine clears its emulated pointer first.
	Input.emulate_mouse_from_touch = previous_mouse_emulation
	popup_mouse_override = false
	awaiting_popup_release = false
	popup_touch_index = -1
	stick_direction = 0
	if is_instance_valid(modal_option) and modal_option.is_visible_in_tree() and not modal_option.disabled:
		modal_option.grab_focus()
	modal_option = null


func _exit_tree() -> void:
	if not popup_mouse_override:
		return
	if is_instance_valid(modal_option):
		modal_option.get_popup().hide()
	# Complete any tracked synthetic mouse gesture before restoring the project
	# preference, even if the page is removed while a finger is still down.
	if popup_touch_index >= 0:
		var release := InputEventScreenTouch.new()
		release.index = popup_touch_index
		release.pressed = false
		release.canceled = true
		Input.parse_input_event(release)
	Input.emulate_mouse_from_touch = previous_mouse_emulation
	popup_mouse_override = false
	awaiting_popup_release = false


func _style_dropdown(popup: PopupMenu) -> void:
	# Shared presentation only: keep native selection, modal signals and input intact.
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.01, 0.035, 0.05, 0.94)
	panel.border_color = Color(CYAN, 0.8)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(3)
	panel.content_margin_left = 12.0
	panel.content_margin_right = 12.0
	panel.content_margin_top = 8.0
	panel.content_margin_bottom = 8.0
	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = Color(0.025, 0.25, 0.31, 0.65)
	hover.border_color = CYAN
	hover.border_width_left = 2
	hover.content_margin_left = 8.0
	hover.content_margin_right = 8.0
	popup.add_theme_stylebox_override("panel", panel)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_color_override("font_color", Color("bbccd9"))
	popup.add_theme_color_override("font_hover_color", WHITE)
	popup.add_theme_color_override("font_disabled_color", DIM)
	popup.add_theme_color_override("font_accelerator_color", CYAN)
	popup.add_theme_font_override("font", get_theme_font("font", "Button"))
	popup.add_theme_font_size_override("font_size", 28)
	popup.add_theme_constant_override("v_separation", 16)
