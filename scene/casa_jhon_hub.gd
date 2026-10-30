extends Node2D
## The evolving house. Layout/anchors come from the official bundle and are the same in
## every stage; MetaProgression.house_stage (0-3) only selects the room art and lights.

const STAGE := 0
const BOUNDS := Rect2(0.0, 0.0, 2560.0, 768.0)


func get_hub_bounds() -> Rect2:
	return BOUNDS


const HUB_ATMOSPHERE := preload("res://scene/fx/hub_atmosphere.gd")
const PRESENTATION := preload("res://scene/casa_jhon_presentation.gd")


func _ready() -> void:
	# Keep authored anchors/geometry and archival instances, replace presentation only.
	$Environment.hide()
	var meta := get_tree().get_first_node_in_group("meta_progression") as MetaProgression
	var progression: Dictionary = meta.get_hub_progression_snapshot() if meta != null else {}
	var house_stage := PRESENTATION.house_stage_of(progression)
	var glow := 1.0 + 0.15 * float(house_stage)
	var atmosphere := HUB_ATMOSPHERE.new()
	atmosphere.room = BOUNDS.size
	atmosphere.lights_texture = load(PRESENTATION.STAGE_LIGHTS[house_stage]) as Texture2D
	atmosphere.washes = [[Vector2(300, 430), Color("ffb347"), 0.10 * glow], [Vector2(1120, 470), Color("39dff2"), 0.12 * glow],
		[Vector2(1900, 380), Color("ff4fb4"), 0.10 * glow]]
	add_child(atmosphere)
	var presentation := PRESENTATION.new()
	presentation.set_progression_state(progression)
	add_child(presentation)
