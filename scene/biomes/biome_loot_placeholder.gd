extends Area2D

@export var loot_id: StringName
@export var amount := 20

var _collected := false


func _ready() -> void:
	add_to_group("biome_loot")
	collision_mask = 1
	var label := get_node_or_null("Label") as Label
	if label == null:
		return
	label.visible = false
	body_entered.connect(func(body: Node) -> void: if body.is_in_group("player"): label.visible = true)
	body_exited.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			label.visible = get_overlapping_bodies().any(func(candidate: Node) -> bool: return candidate != body and candidate.is_in_group("player")))


func interact(_interactor: Node2D = null) -> void:
	if _collected:
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager == null or not run_manager.collect_biome_loot(loot_id, amount):
		return
	_collected = true
	queue_free()
