class_name BiomeModuleDefinition
extends Resource

@export var module_id: StringName
@export var display_name := "Module"
@export_enum("standard", "upper_lower", "lower_upper") var route_style := "standard"
@export var bounds := Rect2(0.0, 0.0, 960.0, 540.0)
@export var connectors: Array[StringName] = []
@export var platform_rects: Array[Rect2] = []
@export var enemy_sockets: Array[Vector2] = []
@export var loot_sockets: Array[Vector2] = []
@export var attribute_sockets: Array[Vector2] = []
@export var exit_sockets: Array[Vector2] = []
@export var custom_scene: PackedScene


func supports(required_connectors: Array[StringName]) -> bool:
	for direction in required_connectors:
		if not connectors.has(direction):
			return false
	return true
