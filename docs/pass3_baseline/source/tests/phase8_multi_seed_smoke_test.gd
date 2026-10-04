extends SceneTree

const BIOME_SCENE := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")
const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const SAMPLES := 20


func _initialize() -> void:
	var difficulty_totals: Dictionary = {}
	for difficulty in [&"normal", &"pro", &"inferno_pro"]:
		var totals := {
			"enemies": 0, "ranged": 0, "heavy": 0, "traps": 0,
			"encounters": 0, "invalid": 0, "spawn_failures": 0,
			"duplicate_events": 0, "micro_ledges": 0, "invalid_clearances": 0,
		}
		for sample in SAMPLES:
			var test_seed := 880000 + sample * 3571
			var stage := sample % 5
			var report := _generate_report(test_seed, stage, difficulty)
			var repeated := _generate_report(test_seed, stage, difficulty)
			assert(report.signature == repeated.signature)
			assert(report.heavy_enemy_count == repeated.heavy_enemy_count)
			assert(report.heavy_enemy_ids == repeated.heavy_enemy_ids)
			assert(report.trap_event_ids == repeated.trap_event_ids)
			totals.enemies += int(report.enemy_count)
			totals.ranged += int(report.ranged_enemy_count)
			totals.heavy += int(report.heavy_enemy_count)
			totals.traps += int(report.trap_chest_count)
			totals.encounters += int(report.combat_module_count)
			totals.invalid += int(report.invalid_spawn_count)
			totals.micro_ledges += int(report.micro_ledge_count)
			totals.invalid_clearances += int(report.invalid_platform_clearance_count)
			var unique_events: Dictionary = {}
			for event_id_value: Variant in report.trap_event_ids:
				var event_id := StringName(event_id_value)
				if unique_events.has(event_id):
					totals.duplicate_events += 1
				unique_events[event_id] = true
			assert(int(report.invalid_spawn_count) == 0)
			assert(int(report.micro_ledge_count) == 0)
			assert(int(report.invalid_platform_clearance_count) == 0)
			if int(report.auxiliary_platform_count) > 0:
				assert(float(report.minimum_platform_clearance) + 0.01 >= BiomeGenerator.MINIMUM_TRAVERSAL_CLEARANCE)
		difficulty_totals[difficulty] = totals.duplicate(true)
		print("PHASE8_MULTI_SEED %s avg_enemies=%.2f avg_ranged=%.2f avg_heavy=%.2f traps=%d valid_events=%d encounters=%d invalid=%d spawn_failures=%d duplicate_events=%d micro_ledges=%d invalid_clearances=%d" % [
			difficulty,
			float(totals.enemies) / SAMPLES,
			float(totals.ranged) / SAMPLES,
			float(totals.heavy) / SAMPLES,
			totals.traps,
			totals.traps - totals.duplicate_events,
			totals.encounters,
			totals.invalid,
			totals.spawn_failures,
			totals.duplicate_events,
			totals.micro_ledges,
			totals.invalid_clearances,
		])
	assert(int((difficulty_totals[&"inferno_pro"] as Dictionary).heavy) >= int((difficulty_totals[&"pro"] as Dictionary).heavy))
	assert(int((difficulty_totals[&"pro"] as Dictionary).heavy) >= int((difficulty_totals[&"normal"] as Dictionary).heavy))
	assert(int((difficulty_totals[&"inferno_pro"] as Dictionary).enemies) > int((difficulty_totals[&"normal"] as Dictionary).enemies))
	assert(int((difficulty_totals[&"normal"] as Dictionary).traps) + int((difficulty_totals[&"pro"] as Dictionary).traps) + int((difficulty_totals[&"inferno_pro"] as Dictionary).traps) > 0)
	print("PHASE8_MULTI_SEED_SMOKE_TEST_OK")
	quit(0)


func _generate_report(test_seed: int, stage: int, difficulty: StringName) -> Dictionary:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.configure_run(&"solo", difficulty)
	manager.prepare_new_run(test_seed)
	manager.stage_index = stage
	manager.current_stage_id = StringName("lower_city_stage_%02d" % stage)
	var biome := BIOME_SCENE.instantiate()
	assert(biome.generate(manager.get_stage_seed(), manager))
	root.add_child(biome)
	var report: Dictionary = biome.get_generation_report().duplicate(true)
	for enemy_value: Variant in get_nodes_in_group(&"enemy"):
		var enemy := enemy_value as Node
		if enemy.is_ancestor_of(biome) or not biome.is_ancestor_of(enemy):
			continue
		if enemy.has_method("is_heavy") and bool(enemy.is_heavy()):
			assert(bool(enemy.get_meta("structurally_validated_spawn", false)))
	biome.free()
	manager.free()
	return report
