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
	var namespace := "user://test_session_" + Crypto.new().generate_random_bytes(12).hex_encode()
	DirAccess.make_dir_recursive_absolute(namespace)
	game.get_node("MetaProgression").save_path = namespace.path_join("legacy.json")
	game.get_node("LocalSettings").settings_path = namespace.path_join("settings.cfg")
	root.add_child(game)
	await process_frame
	game.campaigns.store.root_path = namespace.path_join("campaigns")
	check(await game.campaigns.start_new("A"), "new campaign enters actual hub")
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
	game.get_node("LocalSettings").set_dev_mode_enabled(false)
	await process_frame
	check(player.health == 63 and game.run_manager.dirty_money == 0, "DEV restores life and run money")
	check(game.get_node("MetaProgression").credits == 42, "DEV restores campaign credits")
	check(game.campaigns.save_now(), "real slot writable after DEV rollback")
	await game._begin_run_from_hub(1947)
	game.run_manager.dirty_money = 37
	game.run_manager.scrap = 4
	player = game.get_players()[0]
	player.health = 59
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
	await game.return_to_main_menu()
	check(not FileAccess.file_exists(namespace.path_join("legacy.json")), "campaigns never write legacy profile")
	print("CAMPAIGN_SESSION_REPORT failures=", failures, " test_namespace=", namespace)
	quit(0 if failures == 0 else 1)
