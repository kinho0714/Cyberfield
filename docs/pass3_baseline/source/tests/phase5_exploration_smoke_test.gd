extends SceneTree

const MAP_STATE_SCRIPT := preload("res://scene/biomes/biome_map_state.gd")
const BIOME_SCENE := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")
const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")


func _initialize() -> void:
	var failure := _test_map_state()
	if failure.is_empty():
		failure = _test_generated_exploration_contract()
	if failure.is_empty():
		print("PHASE5_EXPLORATION_SMOKE_TEST_OK")
		quit(0)
	else:
		push_error("PHASE5_EXPLORATION_SMOKE_TEST_FAILED: %s" % failure)
		quit(1)


func _test_map_state() -> String:
	var state := MAP_STATE_SCRIPT.new(&"stage_a") as BiomeMapState
	if not state.discover_module(&"module_00"):
		return "first module discovery was ignored"
	state.discover_module(&"module_01", [&"module_00"])
	if not state.discovered_connections.has(BiomeMapState.connection_id(&"module_00", &"module_01")):
		return "connection discovery was not deterministic"
	state.discover_content(&"loot", &"loot_01")
	state.collect_content(&"loot", &"loot_01")
	state.activate_teleporter(&"teleporter_01")
	var copy := MAP_STATE_SCRIPT.new() as BiomeMapState
	copy.apply_dictionary(state.to_dictionary())
	if not copy.collected_loot_ids.has(&"loot_01") or not copy.active_teleporter_ids.has(&"teleporter_01"):
		return "MapState network round-trip lost data"
	return ""


func _test_generated_exploration_contract() -> String:
	var run_manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(run_manager)
	run_manager.configure_run(&"solo", &"normal")
	run_manager.prepare_new_run(20260827)
	var biome := BIOME_SCENE.instantiate()
	if not biome.generate(20260827, run_manager):
		return "biome generation failed"
	var graph: Dictionary = biome.get_map_graph()
	var modules: Array = graph.get("modules", []) as Array
	var teleporters: Array = graph.get("teleporters", []) as Array
	if teleporters.size() < 3 or teleporters.size() > 5:
		return "teleporter distribution is outside 3-5"
	var ids: Dictionary = {}
	for value: Variant in modules:
		var module := value as Dictionary
		if ids.has(module.instance_id):
			return "duplicate module instance ID"
		ids[module.instance_id] = true
	var rail_count := 0
	for node in biome.find_children("*", "StaticBody2D", true, false):
		if node.get_meta("collision_role", &"") == &"procedural_guard_rail":
			rail_count += 1
	if rail_count == 0:
		return "procedural guard rails were not generated"
	biome.free()
	run_manager.free()
	return ""
