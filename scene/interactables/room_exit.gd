extends Area2D

@export_file("*.tscn") var target_room_path: String
@export var target_entry_id: StringName = &"start"
@export var requires_current_room_completed := false

var _used := false


func interact(interactor: Node2D = null) -> void:
	if _used:
		return

	var manager := get_tree().get_first_node_in_group("room_manager")

	if manager == null or manager.is_transitioning:
		return

	if not manager.can_use_exit(self, interactor):
		return

	if requires_current_room_completed:
		var run_manager := get_tree().get_first_node_in_group("run_manager")
		var room_id: StringName = run_manager.get_current_room_id()

		if not run_manager.room_states[room_id].completed:
			return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var room_id: StringName = run_manager.get_current_room_id()
	if run_manager.is_room_exit_locked(room_id):
		return

	_used = true
	run_manager.collect_all_room_money(room_id)
	manager.request_room_change(target_room_path, target_entry_id)
