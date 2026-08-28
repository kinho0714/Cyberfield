extends SceneTree

const BIOME_SCENE := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")
const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const PLAYER_SCENE := preload("res://entities/player.tscn")
const TOUCH_SCENE := preload("res://ui/touch_controls.tscn")


func _initialize() -> void:
	var averages := {}
	for difficulty in [&"normal", &"pro", &"inferno_pro"]:
		var totals := {"modules": 0, "encounters": 0, "enemies": 0, "ranged": 0, "max_empty": 0, "platforms": 0, "rejected": 0, "rejected_micro": 0, "micro": 0, "rails": 0, "invalid": 0}
		for sample in 20:
			var manager := RUN_MANAGER_SCRIPT.new()
			root.add_child(manager)
			manager.configure_run(&"solo", difficulty)
			manager.prepare_new_run(711000 + sample * 7919)
			var biome := BIOME_SCENE.instantiate()
			root.add_child(biome)
			assert(biome.generate(711000 + sample * 7919, manager))
			var report: Dictionary = biome.get_generation_report()
			totals.modules += int(report.module_count)
			totals.encounters += int(report.combat_module_count)
			totals.enemies += int(report.enemy_count)
			totals.ranged += int(report.ranged_enemy_count)
			totals.max_empty = maxi(totals.max_empty, int(report.max_empty_sequence))
			totals.platforms += int(report.auxiliary_platform_count)
			totals.rejected += int(report.rejected_layout_count)
			totals.rejected_micro += int(report.rejected_micro_ledge_count)
			totals.micro += int(report.micro_ledge_count)
			totals.rails += int(report.guard_rail_count)
			totals.invalid += int(report.invalid_spawn_count)
			assert(int(report.micro_ledge_count) == 0 and int(report.invalid_spawn_count) == 0)
			biome.free()
			manager.free()
		averages[difficulty] = float(totals.enemies) / 20.0
		print("PHASE7_1 %s modules=%d encounters=%d enemies=%d ranged=%d max_empty=%d platforms=%d rejected=%d rejected_micro=%d micro=%d rails=%d invalid=%d" % [difficulty, totals.modules, totals.encounters, totals.enemies, totals.ranged, totals.max_empty, totals.platforms, totals.rejected, totals.rejected_micro, totals.micro, totals.rails, totals.invalid])
	assert(float(averages[&"inferno_pro"]) >= float(averages[&"pro"]) * 1.20)
	_test_dual_weapon_and_mobile_contract()
	print("PHASE7_1_STABILIZATION_SMOKE_TEST_OK")
	quit()


func _test_dual_weapon_and_mobile_contract() -> void:
	assert(InputMap.has_action(&"attack_slot_1") and InputMap.has_action(&"attack_slot_2"))
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	assert(player.equip_weapon(&"arc_emitter"))
	player.attack(1)
	assert(player.weapon_cooldowns[1] > 0.0 and player.weapon_cooldowns[0] == 0.0)
	var projectile_found := false
	for projectile in root.find_children("*", "CharacterBody2D", true, false):
		if projectile != player and projectile.get("target_group") == &"enemy":
			projectile_found = true
	assert(projectile_found)
	var touch := TOUCH_SCENE.instantiate()
	root.add_child(touch)
	assert(touch.has_node("SafeArea/RightCluster/Attack1"))
	assert(touch.has_node("SafeArea/RightCluster/Attack2"))
	assert(not touch.has_node("SafeArea/MapButton"))
	assert(not touch.has_node("SafeArea/InventoryButton"))
	touch.free()
	player.free()
