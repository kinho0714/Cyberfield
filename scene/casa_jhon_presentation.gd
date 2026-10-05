extends Node2D
## RECOMPOSITION: replaces the old decorative renderer completely.
## Geometry, spawns, portal, terminal and progression remain in the unchanged hub scene.
const TEMP_ENV = preload("res://scene/temporary_environment/painter.gd")
const FLOOR_Y := 643.0
@export var visual_stage_id: StringName = &"hub_stage_00"


func _ready() -> void:
	add_to_group("temporary_environment_view")
	z_index = -20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	TEMP_ENV.paint(self, "house")
	TEMP_ENV.surface(self, Rect2(0, FLOOR_Y, 2560, 125), "floor")
