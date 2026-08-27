extends Area2D

@export var exit_id: StringName
@export var destination_id: StringName

var _used := false


func interact(interactor: Node2D = null) -> void:
	if _used or interactor == null or bool(interactor.get("is_downed")):
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if room_manager == null or run_manager == null or room_manager.is_transitioning:
		return
	if not room_manager.can_use_exit(self, interactor):
		return
	_used = true
	room_manager.request_biome_advance(exit_id, destination_id)
