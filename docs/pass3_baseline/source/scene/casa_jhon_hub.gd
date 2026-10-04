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
	add_child(preload("res://scene/casa_jhon_presentation.gd").new())
