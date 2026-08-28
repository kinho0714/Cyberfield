extends SceneTree

const BIOME_SCENE := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")


func _initialize() -> void:
	assert(EnemyFallDamage.calculate(140.0, 100) == 0)
	assert(EnemyFallDamage.calculate(500.0, 100) > 0)
	assert(EnemyFallDamage.calculate(1000.0, 100) >= 100)
	assert(InputMap.has_action(&"open_inventory"))
	assert(InputMap.has_action(&"pause_menu"))
	for difficulty in [&"normal", &"pro", &"inferno_pro"]:
		var totals := 0
		var combat_modules := 0
		var widest_empty_sequence := 0
		var auxiliary_platforms := 0
		for sample in 20:
			var manager := preload("res://scene/run_manager.gd").new()
			root.add_child(manager)
			manager.configure_run(&"solo", difficulty)
			manager.run_active = true
			manager.current_stage_id = StringName("phase7_%s_%02d" % [difficulty, sample])
			manager.current_biome_id = manager.current_stage_id
			manager.room_states[manager.current_stage_id] = manager._new_room_state()
			var biome := BIOME_SCENE.instantiate()
			root.add_child(biome)
			assert(biome.generate(710000 + sample, manager))
			assert(biome.spawned_enemy_count >= 12)
			totals += biome.spawned_enemy_count
			var report: Dictionary = biome.get_generation_report()
			combat_modules += int(report.combat_module_count)
			widest_empty_sequence = maxi(widest_empty_sequence, int(report.max_empty_sequence))
			auxiliary_platforms += int(report.auxiliary_platform_count)
			assert(int(report.invalid_spawn_count) == 0)
			biome.free()
			manager.free()
		print("PHASE7_DENSITY %s enemies=%d avg=%.2f combat_modules=%d max_empty=%d auxiliary_platforms=%d" % [difficulty, totals, totals / 20.0, combat_modules, widest_empty_sequence, auxiliary_platforms])
	print("PHASE7_CONSOLIDATED_SMOKE_TEST_OK")
	quit()
