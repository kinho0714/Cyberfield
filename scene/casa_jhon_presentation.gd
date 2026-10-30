extends Node2D
## Operação Renascimento (30/10/2026): original Casa Jhon stage-0 composition
## (tools/visual/hub_art.py), drawn at 2x. Replaces the temporary painter renderer.
## Geometry, spawns, portal, terminal and progression remain in the unchanged hub scene;
## lights and motion live in scene/fx/hub_atmosphere.gd.
const ROOM_ART := preload("res://assets/environment/hub/hub_stage0_back.png")
const FLOOR_Y := 643.0
@export var visual_stage_id: StringName = &"hub_stage_00"
var progression_state: Dictionary = {}


func set_progression_state(value: Dictionary) -> void:
	progression_state = value.duplicate(true)
	queue_redraw()


func _ready() -> void:
	z_index = -20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	# Native row 322 is the walkable edge: drawn at 2x with a -1 offset it lands on y=643.
	draw_texture_rect(ROOM_ART, Rect2(0.0, -1.0, 2560.0, 768.0), false)
	_draw_progression_deltas()


func _draw_progression_deltas() -> void:
	var house_stage := clampi(int(progression_state.get("house_stage", 0)), 0, 3)
	var blueprint_count := int(progression_state.get("blueprint_count", 0))
	var recovered_count := int(progression_state.get("recovered_model_count", 0))
	var axes: Dictionary = progression_state.get("axes", {}) as Dictionary
	for stage_step in house_stage:
		var stage_y := 314.0 + float(stage_step) * 12.0
		draw_line(Vector2(1210, stage_y), Vector2(1900, stage_y), Color(0.20, 0.72, 0.78, 0.30), 2)
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
