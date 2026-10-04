class_name BiomeDefinition
extends Resource

@export var biome_id: StringName
@export var display_name := "Biome"
@export var module_pool: Array[Resource] = []
@export_range(1, 100, 1) var min_modules := 15
@export_range(1, 100, 1) var max_modules := 25
@export_range(0, 20, 1) var loot_chest_count := 3
@export_range(0, 20, 1) var attribute_reward_count := 2
@export_range(0, 20, 1) var teleporter_count := 0
@export var possible_exits: Array[StringName] = []
@export var generation_rules: Dictionary = {}
@export var debug_draw_modules := true
@export var debug_draw_connectors := true
@export var debug_draw_sockets := false


func get_module_definitions() -> Array[BiomeModuleDefinition]:
	var result: Array[BiomeModuleDefinition] = []
	for resource in module_pool:
		var definition := resource as BiomeModuleDefinition
		if definition != null:
			result.append(definition)
	return result
