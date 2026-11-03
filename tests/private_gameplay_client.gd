extends SceneTree
const CLIENT := preload("res://scene/network/private_session_client.gd")
const BRIDGE := preload("res://scene/network/private_gameplay_bridge.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var game: Node = load("res://scene/main.tscn").instantiate()
	game.get_node("MetaProgression").save_path = String(fixture.root).path_join("unused_legacy.json")
	game.get_node("LocalSettings").settings_path = String(fixture.root).path_join("settings.cfg")
	root.add_child(game)
	await process_frame
	var client: PrivateSessionClient = CLIENT.new()
	client.backup_root = String(fixture.root).path_join("received")
	root.add_child(client)
	var certificate := X509Certificate.new()
	check(certificate.load(fixture.cert) == OK, "fixture certificate")
	DirAccess.make_dir_recursive_absolute(String(fixture.root))
	var host: bool = fixture.role == "host"
	check(client.connect_session(fixture.url, "create" if host else "join", fixture.token, String(fixture.get("room_id", "")), "f".repeat(32) if host else "", TLSOptions.client(certificate), int(fixture.get("count", 2))) == OK, "connect real WSS")
	var deadline: int = Time.get_ticks_msec() + 90000
	while client.peer_id == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	check(client.peer_id == 1 if host else client.peer_id in [2, 3, 4], "authorized seat")
	var authorized_peer: int = client.peer_id
	if host:
		var output := FileAccess.open(fixture.output, FileAccess.WRITE)
		output.store_string(JSON.stringify({"room_id": client.room_id, "tokens": client.invitations}))
		output.close()
		while client.lobby.get("connected", []).size() != int(fixture.get("count", 2)) and Time.get_ticks_msec() < deadline:
			await process_frame
		client.start_session()
	while client.status != "active" and Time.get_ticks_msec() < deadline:
		await process_frame
	var bridge: Node = BRIDGE.new()
	root.add_child(bridge)
	check(bridge.bind_gameplay(game, client) == OK, "bind existing game")
	var result: Error = await bridge.begin()
	check(result == OK, "begin existing gameplay")
	if host:
		await game._begin_run_from_hub(1947)
		var guest: Node = game.get_players()[1]
		var origin: Vector2 = guest.global_position
		var enemy: Node = get_first_node_in_group("enemy")
		enemy.health = 58
		enemy.take_damage(7)
		while guest.global_position.x <= origin.x + 20.0 and Time.get_ticks_msec() < deadline:
			await process_frame
		check(guest.global_position.x > origin.x + 20.0, "guest input moves actual host-simulated player")
	else:
		Input.action_press(&"right")
		while (bridge.last_applied <= 3 or not game.current_is_generated_biome or game.current_is_hub or not replicated_damage()) and Time.get_ticks_msec() < deadline:
			await process_frame
		await create_timer(0.5).timeout
		Input.action_release(&"right")
		check(bridge.last_applied > 3, "multiple authoritative snapshots applied")
		check(game.current_is_generated_biome and not game.current_is_hub, "host transition generated real client biome")
		check(client.publish_snapshot({}) == ERR_UNAUTHORIZED, "guest cannot publish state")
		var replicated := false
		for enemy in get_nodes_in_group("enemy"):
			if enemy.health == 51:
				replicated = true
		check(replicated, "actual host damage replicated to enemy")
		# Drop the real socket; client must resume the same server-authorized seat.
		var before_drop: int = bridge.last_applied
		client.socket.close(1000, "fixture_drop")
		var reconnect_deadline: int = Time.get_ticks_msec() + 30000
		while (client.status != "active" or bridge.last_applied <= before_drop) and Time.get_ticks_msec() < reconnect_deadline:
			await process_frame
		check(client.peer_id == authorized_peer and client.status == "active", "reconnect same authorized seat")
		check(bridge.last_applied > before_drop, "gameplay snapshots continue after reconnect")
	var ready_path: String = String(fixture.root).get_base_dir().path_join(String(fixture.role) + ".ready")
	var ready_file := FileAccess.open(ready_path, FileAccess.WRITE)
	ready_file.store_string("ready")
	ready_file.close()
	while not FileAccess.file_exists(String(fixture.root).get_base_dir().path_join("release")) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(game.campaigns.active.is_empty(), "private gameplay never enters solo campaign")
	await bridge.stop()
	client.leave()
	client.free()
	bridge.free()
	game.free()
	await process_frame
	print("PRIVATE_GAMEPLAY_REPORT role=", fixture.role, " failures=", failures)
	quit(0 if failures == 0 else 1)


func replicated_damage() -> bool:
	for enemy in get_nodes_in_group("enemy"):
		if enemy.health == 51:
			return true
	return false
