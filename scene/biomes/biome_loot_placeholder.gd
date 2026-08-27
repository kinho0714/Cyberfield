extends Area2D

@export var loot_id: StringName
@export var amount := 20

var _collected := false


func _ready() -> void:
	add_to_group("biome_loot")


func interact(_interactor: Node2D = null) -> void:
	if _collected:
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager == null or not run_manager.collect_biome_loot(loot_id, amount):
		return
	_collected = true
	queue_free()
