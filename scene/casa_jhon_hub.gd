extends Node2D
## Stage 0 of the same evolving house. Layout/anchors come from the official bundle.
## Later stages remain documentary data until progression is implemented explicitly.

const STAGE := 0
const BOUNDS := Rect2(0.0, 0.0, 2560.0, 768.0)


func get_hub_bounds() -> Rect2:
	return BOUNDS


const HUB_ATMOSPHERE := preload("res://scene/fx/hub_atmosphere.gd")
const HUB_LIGHTS := preload("res://assets/environment/hub/hub_stage0_lights.png")


func _ready() -> void:
	# Keep authored anchors/geometry and archival instances, replace presentation only.
	$Environment.hide()
	var atmosphere := HUB_ATMOSPHERE.new()
	atmosphere.room = BOUNDS.size
	atmosphere.lights_texture = HUB_LIGHTS
	atmosphere.washes = [[Vector2(300, 430), Color("ffb347"), 0.10], [Vector2(1120, 470), Color("39dff2"), 0.12],
		[Vector2(1900, 380), Color("ff4fb4"), 0.10]]
	add_child(atmosphere)
	var presentation := preload("res://scene/casa_jhon_presentation.gd").new()
	var meta := get_tree().get_first_node_in_group("meta_progression") as MetaProgression
	if meta != null and presentation.has_method("set_progression_state"):
		presentation.set_progression_state(meta.get_hub_progression_snapshot())
	add_child(presentation)
