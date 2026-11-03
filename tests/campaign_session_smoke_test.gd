extends SceneTree
## Real main.tscn integration. Requires Godot + the project's actual assets.
const SNAPSHOT := preload("res://scene/persistence/session_snapshot.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var game: Node = load("res://scene/main.tscn").instantiate()
	var test_namespace := "user://test_session_" + Crypto.new().generate_random_bytes(12).hex_encode()
	DirAccess.make_dir_recursive_absolute(test_namespace)
	game.get_node("MetaProgression").save_path = test_namespace.path_join("legacy.json")
	game.get_node("LocalSettings").settings_path = test_namespace.path_join("settings.cfg")
	root.add_child(game)
	await process_frame
	game.campaigns.store.root_path = test_namespace.path_join("campaigns")
	check(await game.campaigns.start_new("A"), "new campaign enters actual hub")
	check(game.campaigns.profile.initialize(test_namespace.path_join("profile")), "profile uses disposable test namespace")
	game.campaigns.services.open()
	game.campaigns.services.show_profile()
	game.campaigns.services.show_private()
	game.campaigns.services.close()
	check(not paused, "service modal restores pause state")
	var first_id: String = game.campaigns.active.campaign_id
	var player: Node = game.get_players()[0]
	player.health = 63
	game.get_node("MetaProgression").credits = 42
	check(game.campaigns.save_now(), "save hub state")
	await game.return_to_main_menu()
	check(await game.campaigns.start_new("B"), "second independent campaign")
	check(game.get_node("MetaProgression").credits == 0, "second campaign starts clean")
	await game.return_to_main_menu()
	check(await game.campaigns.continue_campaign(first_id), "continue first campaign")
	player = game.get_players()[0]
	check(player.health == 63 and game.get_node("MetaProgression").credits == 42, "health and permanent credits restored")
	var dev: Node = game.get_node("DevMode")
	game.get_node("LocalSettings").set_dev_mode_enabled(true)
	dev.change_health(20)
	dev.change_run_money(100)
	dev.change_credits(100)
	check(not game.campaigns.save_now(), "DEV cannot overwrite real slot")
	var real_counter: int = int(game.campaigns.active.world.run_counter)
	var real_revision: int = int(game.campaigns.store.load_campaign(first_id).revision)
	await game._begin_run_from_hub()
	check(game.run_manager.dev_session, "run started inside DEV stays tainted")
	check(int(game.campaigns.active.world.run_counter) == real_counter, "DEV does not consume campaign run seeds")
	check(int(game.campaigns.store.load_campaign(first_id).revision) == real_revision, "DEV does not publish geography to real campaign")
	game.get_node("LocalSettings").set_dev_mode_enabled(false)
	await process_frame
	check(player.health == 63 and game.run_manager.dirty_money == 0, "DEV restores life and run money")
	check(game.get_node("MetaProgression").credits == 42, "DEV restores campaign credits")
	check(game.campaigns.save_now(), "real slot writable after DEV rollback")
	await game._begin_run_from_hub(1947)
	var opened_chest_id: StringName = &""
	var chest: Node = get_first_node_in_group("biome_loot")
	if chest != null:
		opened_chest_id = chest.loot_id
		chest.interact(game.get_players()[0])
	game.run_manager.dirty_money = 37
	game.run_manager.scrap = 4
	player = game.get_players()[0]
	player.health = 59
	check(player.equip_weapon(&"pulse_carbine", 1, &"uncommon"), "equip real ranged weapon")
	player.weapon_ammo[&"pulse_carbine"] = {"clip": 3, "reserve": 17}
	player.weapon_reload_timers[&"pulse_carbine"] = 0.75
	var enemy: Node = get_first_node_in_group("enemy")
	var enemy_id: StringName = enemy.persistent_id
	enemy.health = 51
	var position: Vector2 = player.global_position
	var snapshot := SNAPSHOT.capture(game)
	check(not snapshot.is_empty(), "capture actual procedural scene")
	check(game.campaigns.save_now(), "save active procedural run")
	await game.return_to_main_menu()
	check(await game.campaigns.continue_campaign(first_id), "continue procedural run")
	player = game.get_players()[0]
	check(game.run_manager.seed_value == 1947 and game.run_manager.dirty_money == 37 and game.run_manager.scrap == 4, "run seed and temporary economy restored")
	check(player.health == 59 and player.global_position.distance_to(position) < 2, "run position and life restored")
	check(not game.run_manager.run_is_lost, "interruption is not death")
	if not opened_chest_id.is_empty():
		check(game.run_manager.collected_biome_loot.has(opened_chest_id), "opened chest remains collected")
		for restored_chest in get_nodes_in_group("biome_loot"):
			check(restored_chest.loot_id != opened_chest_id, "opened chest does not respawn")
	check(player.owned_weapons.has(&"pulse_carbine") and player.weapon_ammo[&"pulse_carbine"].clip == 3, "equipment and ammunition restored")
	var restored_enemy: Node = null
	for actor in get_nodes_in_group("enemy"):
		if actor.persistent_id == enemy_id:
			restored_enemy = actor
	check(restored_enemy != null and restored_enemy.health == 51, "enemy state restored by stable ID")
	var expected_kind: StringName = game.run_manager.preview_exit_biome(&"next_biome_b")
	await game.request_biome_advance(&"test_exit_b", &"next_biome_b")
	check(game.run_manager.stage_index == 1 and game.run_manager.current_biome_kind == expected_kind, "route preview matches actual destination")
	check(game.campaigns.active.world.location.neighborhood_id.ends_with("neighborhood_002"), "alternative route enters second neighborhood")
	check(game.campaigns.save_now(), "save after regional transition")
	await game.return_to_main_menu()
	check(await game.campaigns.continue_campaign(first_id), "restore after regional transition")
	check(game.run_manager.stage_index == 1 and game.run_manager.current_biome_kind == expected_kind, "transition state restored")
	await game.return_to_main_menu()
	var incompatible: Dictionary = game.campaigns.store.load_campaign(first_id)
	incompatible.session.signature = "incompatible_test_signature"
	check(game.campaigns.store.save_campaign(incompatible), "write disposable semantically incompatible revision")
	check(await game.campaigns.continue_campaign(first_id), "recover previous compatible revision")
	check(bool(game.campaigns.recovery_status.get("used_backup", false)), "semantic backup recovery recorded")
	var distribution: Dictionary = game.campaigns.active.world.guard_distribution.duplicate(true)
	var meta: MetaProgression = game.get_node("MetaProgression")
	if not meta.blueprints.has(&"scrap_blade"):
		meta.blueprints.append(&"scrap_blade")
	meta.save_profile()
	game.run_manager.lose_run()
	await process_frame
	await game.return_to_laboratory()
	check(meta.blueprints.has(&"scrap_blade"), "blueprint survives defeat")
	check(game.campaigns.active.world.guard_distribution == distribution, "defeat does not redistribute guards")
	check(not game.get_players()[0].owned_weapons.has(&"pulse_carbine"), "temporary weapon follows existing run reset policy")
	var credits_before: int = meta.credits
	check(meta.record_run(game.run_manager.last_run_results) == 0 and meta.credits == credits_before, "result reward cannot be duplicated")
	await game.return_to_main_menu()
	check(not FileAccess.file_exists(test_namespace.path_join("legacy.json")), "campaigns never write legacy profile")
	print("CAMPAIGN_SESSION_REPORT failures=", failures, " test_namespace=", test_namespace)
	game.free()
	await process_frame
	quit(0 if failures == 0 else 1)
