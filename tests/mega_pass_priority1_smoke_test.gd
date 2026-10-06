extends SceneTree

const BIOME_SCENE := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")
const INDUSTRIAL_SCENE := preload("res://scene/biomes/industrial/industrial_biome.tscn")
const LAB_SCENE := preload("res://scene/biomes/lab/lab_biome.tscn")
const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const AUDIO_SERVICE_SCRIPT := preload("res://scene/audio_service.gd")
const META_SCRIPT := preload("res://scene/meta_progression.gd")
const ENVIRONMENT_CYCLE := preload("res://scene/temporary_environment/environment_cycle.gd")
const SAMPLES := 100


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var signatures := {}
	var saw_vertical := false
	var first_intent_profile := ""
	var saw_multiple_intent_profiles := false
	for sample in SAMPLES:
		var test_seed := 910000 + sample * 7919
		var manager := RUN_MANAGER_SCRIPT.new()
		root.add_child(manager)
		manager.configure_run(&"solo", &"normal")
		manager.prepare_new_run(test_seed)
		var biome := BIOME_SCENE.instantiate()
		assert(biome.generate(test_seed, manager))
		root.add_child(biome)
		var report: Dictionary = biome.get_generation_report()
		assert(not bool(report.fallback))
		assert(int(report.module_count) >= 15 and int(report.module_count) <= 25)
		assert(int(report.row_count) >= 3)
		assert(int(report.max_vertical_chain) <= 4)
		assert(float(report.vertical_edge_ratio) <= 0.5001)
		assert(int(report.horizontal_edge_count) > 0)
		assert(int((report.director_intents as Dictionary).get("special_encounter", 0)) >= 1)
		assert(int(report.trap_chest_count) >= 1, "Special encounter without trap for seed %d // graph=%s" % [test_seed, JSON.stringify(biome.get_map_graph())])
		saw_vertical = saw_vertical or int(report.vertical_edge_count) > 0
		var repeated := BIOME_SCENE.instantiate()
		assert(repeated.generate(test_seed, manager))
		assert(repeated.get_generation_report().signature == report.signature)
		signatures[report.signature] = true
		var intent_profile := JSON.stringify(report.director_intents)
		if first_intent_profile.is_empty():
			first_intent_profile = intent_profile
		elif intent_profile != first_intent_profile:
			saw_multiple_intent_profiles = true
		repeated.free()
		biome.free()
		manager.free()
	assert(saw_vertical)
	assert(signatures.size() >= 60)
	assert(saw_multiple_intent_profiles)
	_test_runtime_biome(INDUSTRIAL_SCENE, &"biome_02", 920000)
	_test_runtime_biome(LAB_SCENE, &"biome_03", 930000)
	_test_environment_cycle()

	assert(is_equal_approx(GameplayProgressionFoundation.affinity_bonus(3), 0.09))
	assert(is_equal_approx(GameplayProgressionFoundation.hybrid_bonus(0, 0), 0.0))
	assert(is_equal_approx(GameplayProgressionFoundation.hybrid_bonus(2, 2), 0.08))
	assert(is_equal_approx(GameplayProgressionFoundation.hybrid_bonus(1, 3), 0.04))
	assert(GameplayProgressionFoundation.loadout_limit(&"melee") == 1)
	assert(GameplayProgressionFoundation.loadout_limit(&"ranged") == 1)
	assert(GameplayProgressionFoundation.loadout_limit(&"gadgets") == 2)
	assert(GameplayProgressionFoundation.MAX_NORMAL_WEAPON_BUFFS == 2)
	assert(GameplayProgressionFoundation.is_supported_cyberware_slot(&"head_neural"))
	assert(not GameplayProgressionFoundation.is_supported_quality(GameplayProgressionFoundation.FUTURE_SPECIAL_QUALITY))

	var audio := AUDIO_SERVICE_SCRIPT.new() as AudioService
	root.add_child(audio)
	await process_frame
	assert(not audio.play_event(&"player_jump"))
	assert(not audio.set_music_context(&"operation"))
	assert(audio.current_music_context == &"operation")
	audio.queue_free()

	var meta := META_SCRIPT.new() as MetaProgression
	meta.save_path = "user://mega_pass_priority1_meta_test.json"
	root.add_child(meta)
	await process_frame
	meta.record_run({
		"run_id": "mega-pass-test",
		"completed": true,
		"money_earned": 0,
		"stage_index": 0,
		"boss_defeated": false,
		"weapons_found": {&"player_1": [&"breaker_maul"]},
	})
	assert(meta.recovered_models.has(&"breaker_maul"))
	assert(meta.study_blueprint(&"breaker_maul"))
	assert(meta.blueprints.has(&"breaker_maul"))
	assert(not meta.study_blueprint(&"breaker_maul"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(meta.save_path))
	meta.queue_free()
	await process_frame

	print("MEGA_PASS_PRIORITY1_SMOKE_TEST_OK")
	quit(0)


func _test_runtime_biome(scene: PackedScene, expected_content_id: StringName, seed_base: int) -> void:
	for sample in 12:
		var seed := seed_base + sample * 3571
		var manager := RUN_MANAGER_SCRIPT.new()
		root.add_child(manager)
		manager.configure_run(&"solo", &"normal")
		manager.prepare_new_run(seed)
		var biome := scene.instantiate()
		assert(biome.generate(seed, manager))
		root.add_child(biome)
		var report: Dictionary = biome.get_generation_report()
		assert(not bool(report.fallback))
		assert(ContentRegistry.biome_id(StringName(report.biome_id)) == expected_content_id)
		assert(int((report.director_intents as Dictionary).get("special_encounter", 0)) >= 1)
		assert(int(report.trap_chest_count) >= 1)
		biome.free()
		manager.free()


func _test_environment_cycle() -> void:
	assert(TemporaryEnvironmentCycle.snapshot(0.0).phase == &"dawn")
	assert(TemporaryEnvironmentCycle.snapshot(60.0).phase == &"day")
	assert(TemporaryEnvironmentCycle.snapshot(165.0).phase == &"sunset")
	assert(TemporaryEnvironmentCycle.snapshot(210.0).phase == &"night")
	assert(TemporaryEnvironmentCycle.snapshot(270.0).phase == &"late_night")
	assert(TemporaryEnvironmentCycle.snapshot(300.0).phase == &"dawn")
	assert(TemporaryEnvironmentCycle.SUPPORTED_WEATHER_STATES.has(&"rain"))
