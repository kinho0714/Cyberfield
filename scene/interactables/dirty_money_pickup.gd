extends Area2D

@export var drop_id: StringName
@export var room_id: StringName
@export var amount := 0
@export var attraction_range := 140.0
@export var attraction_speed := 360.0
var collected := false

func _physics_process(delta: float) -> void:
	if collected:
		return
	var nearest: Node2D = null
	var nearest_distance := attraction_range
	for player in get_tree().get_nodes_in_group("player"):
		if player.visible and not player.is_downed:
			var distance := global_position.distance_to(player.global_position)
			if distance < nearest_distance:
				nearest = player
				nearest_distance = distance
	if nearest:
		global_position = global_position.move_toward(nearest.global_position, attraction_speed * delta)
		if global_position.distance_to(nearest.global_position) <= 14.0:
			collect()

func collect() -> void:
	if collected:
		return
	collected = true
	var manager := get_tree().get_first_node_in_group("run_manager")
	if manager:
		manager.collect_money_drop(room_id, drop_id)
	queue_free()
