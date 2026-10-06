extends Node2D
## Stage 0 of the same evolving house. Layout/anchors come from the official bundle.
## Later stages remain documentary data until progression is implemented explicitly.

const STAGE := 0
const BOUNDS := Rect2(0.0, 0.0, 2560.0, 768.0)


func get_hub_bounds() -> Rect2:
	return BOUNDS


func _ready() -> void:
	# Keep authored anchors/geometry and archival instances, replace presentation only.
	$Environment.hide()
	var presentation := preload("res://scene/casa_jhon_presentation.gd").new()
	var meta := get_tree().get_first_node_in_group("meta_progression") as MetaProgression
	if meta != null and presentation.has_method("set_progression_state"):
		presentation.set_progression_state(meta.get_hub_progression_snapshot())
	add_child(presentation)
