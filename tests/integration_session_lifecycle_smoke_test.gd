extends SceneTree
## Failure/cleanup test on the real scene; protocol state is simulated, not network authentication.
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://scene/main.tscn").instantiate()
	var ns := "user://test_integration_lifecycle_" + Crypto.new().generate_random_bytes(12).hex_encode()
	DirAccess.make_dir_recursive_absolute(ns)
	game.get_node("MetaProgression").save_path = ns.path_join("legacy.json")
	game.get_node("LocalSettings").settings_path = ns.path_join("settings.cfg")
	root.add_child(game)
	await process_frame
	var controller: Node = game.campaigns
	controller.store.root_path = ns.path_join("campaigns")
	check(controller.profile.initialize(ns.path_join("profile")), "disposable local profile")
	controller.private_panel.settings_path = ns.path_join("private.cfg")
	var bridge: Node = controller.private_gameplay
	var client: Node = controller.private_session
	var meta: Node = game.get_node("MetaProgression")
	meta.credits = 83
	var path: String = meta.save_path
	check(bridge.bind_gameplay(game, client) == OK, "bind before failed begin")
	check(await bridge.begin() == ERR_UNAVAILABLE, "offline begin rejected")
	await bridge.stop()
	check(meta.save_path == path and meta.credits == 83, "failed begin preserves individual profile and save path")
	bridge.last_applied = 999
	bridge._world_key = "old_fixture_world"
	bridge._input_sequences[2] = 300
	check(bridge.bind_gameplay(game, client) == OK, "rebind same bridge")
	check(bridge.last_applied == 0 and bridge._world_key.is_empty() and bridge._input_sequences.is_empty(), "new session clears old revision/world/input sequence")
	await bridge.stop()
	client.status = "connecting"
	var opened: bool = await controller.start_new("Must not create")
	check(not opened, "pending private join blocks solo campaign creation")
	check(controller.active.is_empty(), "blocked campaign creation does not mutate a slot")
	client.status = "offline"
	check(await controller.start_new("Fixture solo"), "solo still starts after failed private session")
	var id: String = controller.active.campaign_id
	check(bridge.bind_gameplay(game, client) == ERR_ALREADY_IN_USE, "private bind refuses real solo campaign")
	check(controller.active.campaign_id == id and controller.save_now(), "solo save remains writable")
	await game.return_to_main_menu()
	game.free()
	await process_frame
	print("INTEGRATION_LIFECYCLE_REPORT failures=", failures)
	quit(0 if failures == 0 else 1)
