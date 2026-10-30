extends Node2D
## Operação Renascimento (30/10/2026): original Casa Jhon compositions for house stages
## 0-3 (tools/visual/hub_art.py, cumulative upgrades), drawn at 2x. Only the art of the
## current MetaProgression.house_stage is loaded. Replaces the temporary painter renderer.
## Geometry, spawns, portal, terminal and progression remain in the unchanged hub scene;
## lights and motion live in scene/fx/hub_atmosphere.gd.
const STAGE_ART := [
	"res://assets/environment/hub/hub_stage0_back.png",
	"res://assets/environment/hub/hub_stage1_back.png",
	"res://assets/environment/hub/hub_stage2_back.png",
	"res://assets/environment/hub/hub_stage3_back.png",
]
const STAGE_LIGHTS := [
	"res://assets/environment/hub/hub_stage0_lights.png",
	"res://assets/environment/hub/hub_stage1_lights.png",
	"res://assets/environment/hub/hub_stage2_lights.png",
	"res://assets/environment/hub/hub_stage3_lights.png",
]
const FLOOR_Y := 643.0
@export var visual_stage_id: StringName = &"hub_stage_00"
var progression_state: Dictionary = {}
var _room_art: Texture2D


static func house_stage_of(state: Dictionary) -> int:
	return clampi(int(state.get("house_stage", 0)), 0, STAGE_ART.size() - 1)


func set_progression_state(value: Dictionary) -> void:
	progression_state = value.duplicate(true)
	var stage := house_stage_of(progression_state)
	visual_stage_id = StringName("hub_stage_%02d" % stage)
	_room_art = load(STAGE_ART[stage]) as Texture2D
	queue_redraw()


func _ready() -> void:
	z_index = -20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	# Native row 322 is the walkable edge: drawn at 2x with a -1 offset it lands on y=643.
	if _room_art == null:
		_room_art = load(STAGE_ART[0]) as Texture2D
	draw_texture_rect(_room_art, Rect2(0.0, -1.0, 2560.0, 768.0), false)
	_draw_progression_deltas()


func _draw_progression_deltas() -> void:
	var blueprint_count := int(progression_state.get("blueprint_count", 0))
	var recovered_count := int(progression_state.get("recovered_model_count", 0))
	var axes: Dictionary = progression_state.get("axes", {}) as Dictionary
	for index in mini(blueprint_count, 6):
		draw_rect(Rect2(1390 + index * 18, 555, 12, 6), Color("39dff2"))
	for index in mini(recovered_count, 6):
		draw_rect(Rect2(1840 + index * 14, 570, 8, 8), Color("ffbe68"))
	var workshop_level := int(axes.get(&"workshop", axes.get("workshop", 0)))
	var infrastructure_level := int(axes.get(&"infrastructure", axes.get("infrastructure", 0)))
	var operations_level := int(axes.get(&"operations", axes.get("operations", 0)))
	var storage_level := int(axes.get(&"storage", axes.get("storage", 0)))
	var spark_level := int(axes.get(&"spark", axes.get("spark", 0)))
	if workshop_level > 0:
		draw_line(Vector2(1320, 548), Vector2(1580 + mini(workshop_level, 4) * 16, 548), Color("39dff2"), 3)
	if infrastructure_level > 0:
		draw_line(Vector2(1980, 326), Vector2(1980 + mini(infrastructure_level, 4) * 24, 326), Color(0.50, 0.86, 0.92, 0.70), 3)
	if operations_level > 0:
		for index in mini(operations_level, 4):
			draw_circle(Vector2(940 + index * 18, 520), 4.0, Color("39dff2"))
	if storage_level > 0:
		draw_line(Vector2(1800, 548), Vector2(1940 + mini(storage_level, 4) * 16, 548), Color("ffbe68"), 3)
	if spark_level > 0:
		draw_arc(Vector2(2220, 548), 18.0 + mini(spark_level, 4) * 3.0, -PI, 0.0, 16, Color(0.36, 0.82, 1.0, 0.75), 3.0)
