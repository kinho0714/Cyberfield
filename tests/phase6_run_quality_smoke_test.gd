extends SceneTree

const BIOME_SCENE := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")
const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const PLAYER_SCENE := preload("res://entities/player.tscn")


func _initialize() -> void:
	var failure := _test_twenty_seeds()
	if failure.is_empty():
		failure = _test_build_foundations()
	if failure.is_empty():
		print("PHASE6_RUN_QUALITY_SMOKE_TEST_OK")
		quit(0)
	else:
		push_error("PHASE6_RUN_QUALITY_SMOKE_TEST_FAILED: %s" % failure)
		quit(1)


func _test_twenty_seeds() -> String:
	for seed_offset in 20:
		var test_seed := 600000 + seed_offset * 7919
		var run_manager := RUN_MANAGER_SCRIPT.new()
		root.add_child(run_manager)
		run_manager.configure_run(&"solo", &"normal")
		run_manager.prepare_new_run(test_seed)
		var biome := BIOME_SCENE.instantiate()
		if not biome.generate(test_seed, run_manager):
			return "generation failed for seed %d" % test_seed
		var report: Dictionary = biome.get_generation_report()
		if int(report.enemy_count) < 12:
			return "enemy density below 12 for seed %d" % test_seed
		var upper_bounds := 0
		var guard_rails := 0
		var one_way_platforms := 0
		for body in biome.find_children("*", "StaticBody2D", true, false):
			var role := StringName(body.get_meta("collision_role", &""))
			if role == &"procedural_upper_bound":
				upper_bounds += 1
			if role == &"procedural_guard_rail":
				guard_rails += 1
				var shape_node := body.get_child(0) as CollisionShape2D
				var shape := shape_node.shape as RectangleShape2D
				if shape.size.y <= shape.size.x:
					return "horizontal invisible guard rail for seed %d" % test_seed
			if role == &"one_way_platform":
				one_way_platforms += 1
		if upper_bounds != 1 or guard_rails == 0 or one_way_platforms == 0:
			return "bounds/platform invariant failed for seed %d" % test_seed
		var graph: Dictionary = biome.get_map_graph()
		var modules: Array = graph.get("modules", []) as Array
		for module_value: Variant in modules:
			var module := module_value as Dictionary
			for neighbor_value: Variant in module.neighbors:
				if int(neighbor_value) < 0 or int(neighbor_value) >= modules.size():
					return "invalid graph connection for seed %d" % test_seed
		biome.free()
		run_manager.free()
	return ""


func _test_build_foundations() -> String:
	var run_manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(run_manager)
	run_manager.configure_run(&"solo", &"normal")
	run_manager.start_new_run(606060)
	var saw_triple := false
	var categories_seen: Dictionary = {}
	for index in 20:
		var options := run_manager.get_chest_options(StringName("test_chest_%02d" % index))
		saw_triple = saw_triple or options.size() == 3
		for option in options:
			categories_seen[AttributeUpgradeCatalog.get_category(option)] = true
	if not saw_triple or categories_seen.size() != 3:
		return "attribute choices are not varied/fair"
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	if not player.equip_weapon(&"breaker_maul") or player.equipped_weapons[1] != &"breaker_maul":
		return "second weapon slot did not equip"
	if player.get_active_weapon_id() != &"breaker_maul":
		return "new weapon did not become active"
	player.switch_weapon()
	if player.get_active_weapon_id() != &"scrap_blade":
		return "weapon switching failed"
	if not player.add_upgrade(&"health_recovery") or not player.add_upgrade(&"strength_impact") or not player.add_upgrade(&"intellect_dash"):
		return "upgrade effects did not apply"
	run_manager.run_elapsed_time = 754.0
	if run_manager.format_run_time() != "12:34":
		return "run timer formatting failed"
	if bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)):
		return "touch still emulates mouse attack"
	player.free()
	run_manager.free()
	return ""
