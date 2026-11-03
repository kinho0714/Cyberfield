extends SceneTree
const MISSIONS := preload("res://scene/missions/mission_ledger.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://scene/main.tscn").instantiate()
	var test_namespace := "user://test_gameplay_" + Crypto.new().generate_random_bytes(12).hex_encode()
	game.get_node("MetaProgression").save_path = test_namespace.path_join("legacy.json")
	game.get_node("LocalSettings").settings_path = test_namespace.path_join("settings.cfg")
	root.add_child(game)
	await process_frame
	game.campaigns.store.root_path = test_namespace.path_join("campaigns")
	check(await game.campaigns.start_new("Disposable gameplay fixture"), "create isolated campaign")
	var tracker: Node = game.campaigns.geography
	var definition: Dictionary = {"id": "fixture_survey", "prerequisites": [], "reward_credits": 7, "narrative_status": "test_only", "objectives": [{"id": "defeat", "event": "enemy_defeated", "target": "fixture_enemy", "count": 1}, {"id": "inspect", "event": "investigation", "target": "fixture_clue", "count": 1}]}
	check(tracker.register_mission(definition) and tracker.activate_mission("fixture_survey"), "register and activate objectives")
	check(tracker.register_mission({"id": "fixture_followup", "prerequisites": ["fixture_survey"], "objectives": [{"id": "talk", "event": "npc_interacted", "count": 1}]}), "prerequisite registered")
	check(not tracker.activate_mission("fixture_followup"), "blocked until prerequisite complete")
	await game._begin_run_from_hub(1947)
	var actor: Node = get_first_node_in_group("enemy")
	var enemy_id: StringName = actor.persistent_id
	actor.health = 51
	var source: String = tracker.remember_current_area()
	check(not source.is_empty(), "archive real generated area")
	game.run_manager.register_enemy_death(game.run_manager.current_biome_id, &"fixture_enemy")
	game.run_manager.register_enemy_death(game.run_manager.current_biome_id, &"fixture_enemy")
	tracker.record_gameplay_event("investigation", "fixture_unique_clue", {"target": "fixture_clue"})
	check(game.campaigns.active.world.missions.fixture_survey.state == "completed", "gameplay and investigation events complete mission")
	check(tracker.activate_mission("fixture_followup"), "prerequisite unlocked")
	await game.request_biome_advance(&"fixture_exit", &"next_biome_b")
	game.run_manager.dirty_money = 73
	game.get_players()[0].health = 61
	check(tracker.revisit_area(source), "return to archived generated area")
	check(game.run_manager.dirty_money == 73 and game.get_players()[0].health == 61, "return preserves current economy and player state")
	var restored: Node = null
	for enemy in get_nodes_in_group("enemy"):
		if enemy.persistent_id == enemy_id:
			restored = enemy
	check(restored != null and restored.health == 51, "return preserves enemy health")
	check(tracker.claim_mission_reward("fixture_survey"), "atomic unique reward claim")
	check(not tracker.claim_mission_reward("fixture_survey"), "duplicate reward refused")
	var id: String = game.campaigns.active.campaign_id
	await game.return_to_main_menu()
	check(await game.campaigns.continue_campaign(id), "reopen campaign")
	check(game.get_node("MetaProgression").credits == 7, "reward persisted exactly once")
	check(not tracker.claim_mission_reward("fixture_survey"), "receipt survives reload")
	check(game.campaigns.active.world.missions.fixture_survey.state == "completed", "mission state persisted")
	var w: Dictionary = game.campaigns.active.world
	check(MISSIONS.fail(w, "fixture_followup"), "failure transition")
	check(not MISSIONS.activate(w, "fixture_followup"), "unique failed mission does not auto repeat")
	await game.return_to_main_menu()
	game.free()
	await process_frame
	print("GAMEPLAY_PROGRESSION_REPORT failures=", failures)
	quit(0 if failures == 0 else 1)
