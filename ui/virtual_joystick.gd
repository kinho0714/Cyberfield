extends Control

@export var left_action: StringName = &"left"
@export var right_action: StringName = &"right"
@export var down_action: StringName = &"down"
@export_range(0.0, 0.9, 0.01) var deadzone := 0.18
@export_range(0.5, 0.95, 0.01) var down_threshold := 0.72
@export_range(0.3, 0.9, 0.01) var down_release_threshold := 0.55
@export_range(16.0, 96.0, 1.0) var maximum_distance := 52.0
@export_range(16.0, 96.0, 1.0) var base_visual_radius := 56.0
@export_range(8.0, 64.0, 1.0) var knob_visual_radius := 24.0

var active_touch_index := -1
var knob_offset := Vector2.ZERO
var horizontal_strength := 0.0
var down_requested := false
var down_sequence_generation := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch_index < 0:
			active_touch_index = event.index
			_update_from_local_position(event.position)
			accept_event()
		elif not event.pressed and event.index == active_touch_index:
			release_input()
			accept_event()
	elif event is InputEventScreenDrag and event.index == active_touch_index:
		_update_from_local_position(event.position)
		accept_event()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, base_visual_radius, Color(0.055, 0.105, 0.18, 0.48))
	draw_arc(center, base_visual_radius, 0.0, TAU, 64, Color(0.49, 0.91, 1.0, 0.72), 3.0, true)
	draw_circle(center + knob_offset, knob_visual_radius, Color(0.18, 0.48, 0.62, 0.82))
	draw_arc(center + knob_offset, knob_visual_radius, 0.0, TAU, 48, Color(0.65, 0.96, 1.0, 0.9), 3.0, true)


func _update_from_local_position(local_position: Vector2) -> void:
	var displacement := local_position - size * 0.5
	knob_offset = displacement.limit_length(maximum_distance)
	_set_horizontal_strength(knob_offset.x / maximum_distance)
	_set_vertical_strength(knob_offset.y / maximum_distance)
	queue_redraw()


func _set_horizontal_strength(raw_strength: float) -> void:
	var clamped_strength := clampf(raw_strength, -1.0, 1.0)
	var magnitude := absf(clamped_strength)
	if magnitude <= deadzone:
		horizontal_strength = 0.0
		Input.action_release(left_action)
		Input.action_release(right_action)
		return

	horizontal_strength = signf(clamped_strength) * ((magnitude - deadzone) / (1.0 - deadzone))
	if horizontal_strength < 0.0:
		Input.action_release(right_action)
		Input.action_press(left_action, -horizontal_strength)
	else:
		Input.action_release(left_action)
		Input.action_press(right_action, horizontal_strength)


func _set_vertical_strength(raw_strength: float) -> void:
	if raw_strength >= down_threshold and not down_requested:
		down_requested = true
		down_sequence_generation += 1
		_pulse_down_action(down_sequence_generation)
	elif raw_strength <= down_release_threshold and down_requested:
		_release_down_action()


func _pulse_down_action(generation: int) -> void:
	Input.action_press(down_action)
	await get_tree().physics_frame
	if generation != down_sequence_generation or not down_requested:
		return
	await get_tree().physics_frame
	if generation != down_sequence_generation or not down_requested:
		return

	Input.action_release(down_action)
	await get_tree().physics_frame
	if generation != down_sequence_generation or not down_requested:
		return

	Input.action_press(down_action)


func _release_down_action() -> void:
	down_requested = false
	down_sequence_generation += 1
	Input.action_release(down_action)


func release_input() -> void:
	active_touch_index = -1
	knob_offset = Vector2.ZERO
	horizontal_strength = 0.0
	Input.action_release(left_action)
	Input.action_release(right_action)
	_release_down_action()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_input()


func _exit_tree() -> void:
	release_input()
