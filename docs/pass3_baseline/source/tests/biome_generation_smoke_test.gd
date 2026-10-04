extends SceneTree

const BIOME_SCENE := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")
const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const TEST_SEEDS := [101, 20260827, 987654321]


func _initialize() -> void:
	var failure := ""
	for test_seed in TEST_SEEDS:
		failure = _validate_seed(test_seed)
		if not failure.is_empty():
			break
	if failure.is_empty():
		print("BIOME_GENERATION_SMOKE_TEST_OK")
		quit(0)
	else:
		push_error("BIOME_GENERATION_SMOKE_TEST_FAILED: %s" % failure)
		quit(1)


func _validate_seed(test_seed: int) -> String:
	var run_manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(run_manager)
	run_manager.configure_run(&"solo", &"normal")
	run_manager.prepare_new_run(test_seed)
	var first := BIOME_SCENE.instantiate()
	if not first.generate(test_seed, run_manager):
		return "generation failed for seed %d" % test_seed
	var first_report: Dictionary = first.get_generation_report()
	if first_report.module_count < 15 or first_report.module_count > 25:
		return "module count outside 15-25 for seed %d" % test_seed
	if first_report.exit_count != 2 or first_report.attribute_count != 2:
		return "required exits/attributes missing for seed %d" % test_seed
	if first_report.loot_count < 2 or first_report.loot_count > 3:
		return "loot count outside 2-3 for seed %d" % test_seed
	if first_report.enemy_count < 7:
		return "enemy sockets were not populated for seed %d" % test_seed
	var graph_failure := _validate_graph(first.get_map_graph(), test_seed)
	if not graph_failure.is_empty():
		return graph_failure
	var second := BIOME_SCENE.instantiate()
	if not second.generate(test_seed, run_manager):
		return "repeat generation failed for seed %d" % test_seed
	var second_report: Dictionary = second.get_generation_report()
	if first_report.signature != second_report.signature:
		return "generation is not deterministic for seed %d" % test_seed
	run_manager.enter_generated_biome(first_report)
	run_manager.activate_run()
	var original_stage_seed := run_manager.get_stage_seed()
	if not run_manager.advance_stage(&"exit_a", &"next_biome_a"):
		return "normal exit could not advance stage for seed %d" % test_seed
	if not run_manager.run_active or run_manager.run_is_completed:
		return "normal exit completed the run for seed %d" % test_seed
	if run_manager.get_stage_seed() == original_stage_seed:
		return "next stage did not derive a new seed for seed %d" % test_seed
	for stage in range(1, 5):
		if not run_manager.advance_stage(&"exit_a", &"next_biome_a"):
			return "stage %d could not advance for seed %d" % [stage + 1, test_seed]
	if run_manager.stage_index != 5:
		return "stage 5 did not lead to boss stage for seed %d" % test_seed
	if run_manager.advance_stage(&"exit_a", &"forbidden_stage_07"):
		return "stage 7 was generated for seed %d" % test_seed
	run_manager.enter_boss_stage()
	run_manager.apply_network_completion()
	if not run_manager.run_is_completed or run_manager.run_active:
		return "boss completion did not finish run for seed %d" % test_seed
	first.free()
	second.free()
	run_manager.free()
	return ""


func _validate_graph(graph: Dictionary, test_seed: int) -> String:
	var modules: Array = graph.get("modules", []) as Array
	if modules.size() < 15 or modules.size() > 25:
		return "graph module count outside 15-25 for seed %d" % test_seed
	var visited: Dictionary = {}
	var queue: Array[int] = [int(graph.get("start_module", 0))]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		var module: Dictionary = modules[current] as Dictionary
		var neighbors: Array = module.get("neighbors", []) as Array
		for neighbor_value: Variant in neighbors:
			var neighbor := int(neighbor_value)
			if not visited.has(neighbor):
				queue.append(neighbor)
	if visited.size() != modules.size():
		return "graph contains disconnected modules for seed %d" % test_seed
	var exits: Array = graph.get("exit_modules", []) as Array
	if exits.size() < 2 or not visited.has(int(exits[0])) or not visited.has(int(exits[1])):
		return "graph exits are not reachable for seed %d" % test_seed
	var content: Dictionary = graph.get("content_modules", {}) as Dictionary
	if (content.get("loot", []) as Array).size() < 2:
		return "graph has insufficient loot destinations for seed %d" % test_seed
	if (content.get("attribute", []) as Array).size() != 2:
		return "graph has no attribute reward per exit for seed %d" % test_seed
	var distinct_rows: Dictionary = {}
	var has_branch := false
	var maximum_x := -2147483648
	for module_value: Variant in modules:
		var module: Dictionary = module_value as Dictionary
		var grid: Vector2i = module.get("grid", Vector2i.ZERO)
		distinct_rows[grid.y] = true
		maximum_x = maxi(maximum_x, grid.x)
		has_branch = has_branch or (module.get("neighbors", []) as Array).size() >= 3
	if distinct_rows.size() < 3:
		return "graph has insufficient vertical variation for seed %d" % test_seed
	if not has_branch:
		return "graph has no structural bifurcation for seed %d" % test_seed
	var first_exit: Dictionary = modules[int(exits[0])] as Dictionary
	var second_exit: Dictionary = modules[int(exits[1])] as Dictionary
	var first_exit_grid: Vector2i = first_exit.get("grid", Vector2i.ZERO)
	var second_exit_grid: Vector2i = second_exit.get("grid", Vector2i.ZERO)
	if first_exit_grid.y == second_exit_grid.y or (first_exit_grid.x == maximum_x and second_exit_grid.x == maximum_x):
		return "exits do not represent distinct routes for seed %d" % test_seed
	return ""
