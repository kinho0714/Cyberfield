extends SceneTree

const SCENES: Array[PackedScene] = [
	preload("res://scene/biomes/lower_city/lower_city_biome.tscn"),
	preload("res://scene/biomes/industrial/industrial_biome.tscn"),
	preload("res://scene/biomes/lab/lab_biome.tscn"),
]
const RUN_MANAGER = preload("res://scene/run_manager.gd")
const SEEDS: Array[int] = [101, 20260827, 987654321]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var inspected := 0
	for scene: PackedScene in SCENES:
		for seed: int in SEEDS:
			var manager := RUN_MANAGER.new()
			root.add_child(manager)
			manager.configure_run(&"solo", &"normal")
			manager.prepare_new_run(seed)
			var biome := scene.instantiate()
			assert(biome.generate(seed, manager), "Biome generation failed for seed %d" % seed)
			root.add_child(biome)
			await physics_frame
			for node: Node in biome.find_children("*", "Area2D", true, false):
				var name_string := String(node.name)
				if not name_string.begins_with("BiomeLoot") and not name_string.begins_with("ExitAttributeReward"):
					continue
				var chest := node as Node2D
				var query := PhysicsRayQueryParameters2D.create(chest.global_position, chest.global_position + Vector2(0.0, 90.0), 1)
				query.collide_with_areas = false
				var hit: Dictionary = biome.get_world_2d().direct_space_state.intersect_ray(query)
				if hit.is_empty():
					var module_index: int = biome.get_module_index_at(chest.global_position)
					var data: Dictionary = biome._nodes[module_index] if module_index >= 0 else {}
					var definition: BiomeModuleDefinition = data.get("definition") as BiomeModuleDefinition
					print("UNSUPPORTED_DEBUG name=", name_string, " position=", chest.global_position, " seed=", seed, " biome=", biome.name,
						" module=", module_index, " role=", data.get("role"), " type=", definition.module_id if definition else "unknown", " route=", definition.route_style if definition else "unknown", " connectors=", data.get("required_connectors"), " platforms=", definition.platform_rects if definition else [])
				assert(not hit.is_empty(), "%s unsupported in seed %d" % [name_string, seed])
				var distance := float(hit.position.y) - chest.global_position.y
				assert(distance >= 12.0 and distance <= 27.0, "%s floats/overlaps ground by %.2fpx (seed %d)" % [name_string, distance, seed])
				inspected += 1
			biome.free()
			manager.free()
			await physics_frame
	assert(inspected >= 27, "Too few chests generated for grounding inspection")
	print("FOCUSED_STABILIZATION_GROUNDING_TEST_OK checked=", inspected)
	quit(0)
