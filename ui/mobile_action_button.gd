extends Node2D

@export var action: StringName
@export_range(16.0, 96.0, 1.0) var touch_radius: float = 48.0

var active_touch_index: int = -1


func _ready() -> void:
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if (
			touch_event.pressed
			and is_visible_in_tree()
			and active_touch_index < 0
			and _contains_touch(touch_event.position)
		):
			active_touch_index = touch_event.index
			Input.action_press(action)
		elif not touch_event.pressed and touch_event.index == active_touch_index:
			release_input()


func _contains_touch(viewport_position: Vector2) -> bool:
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * viewport_position
	return local_position.length_squared() <= touch_radius * touch_radius


func release_input() -> void:
	active_touch_index = -1
	if action != &"" and InputMap.has_action(action):
		Input.action_release(action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_input()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release_input()


func _exit_tree() -> void:
	release_input()
