extends SceneTree
const CLIENT := preload("res://scene/network/private_session_client.gd")
const WIRE := preload("res://scene/network/gameplay_wire.gd")
var client: PrivateSessionClient
var latest_revision := 0
var latest_state: Dictionary = {}
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	client = CLIENT.new()
	root.add_child(client)
	client.backup_root = String(fixture.root).path_join("received")
	client.state_received.connect(_on_state)
	client.status_changed.connect(func() -> void: print("SIM_PEER_TRANSPORT role=", fixture.role, " status=", client.status, " error=", client.last_error))
	var certificate := X509Certificate.new()
	check(certificate.load(String(fixture.cert)) == OK, "simulation certificate loaded")
	var root_path := String(fixture.root)
	DirAccess.make_dir_recursive_absolute(root_path)
	check(client.connect_session(String(fixture.url), "join", String(fixture.token), String(fixture.room_id), "", TLSOptions.client(certificate), int(fixture.count)) == OK, "simulated participant opens TLS/WSS")
	var deadline := Time.get_ticks_msec() + 120000
	while (client.peer_id == 0 or client.status != "active") and Time.get_ticks_msec() < deadline:
		await physics_frame
	var authorized_peer := client.peer_id
	check(authorized_peer in [2, 3, 4] and client.status == "active", "simulated participant receives an authorized active seat; peer=" + str(client.peer_id) + " status=" + client.status)
	var last_revision_before_reconnect := 0
	var did_reconnect := false
	var reconnect_test := bool(fixture.get("reconnect_test", false))
	var next_input := Time.get_ticks_msec()
	while Time.get_ticks_msec() < deadline:
		if client.status == "active" and Time.get_ticks_msec() >= next_input:
			client.send_input({"right": true})
			next_input = Time.get_ticks_msec() + 100
		if _region_and_damage_ready():
			if reconnect_test and not did_reconnect:
				did_reconnect = true
				last_revision_before_reconnect = latest_revision
				if client.socket != null:
					client.socket.close(1000, "simulated_reconnect")
				else:
					check(false, "transport socket exists before reconnect fixture")
				var reconnect_deadline := Time.get_ticks_msec() + 120000
				while (client.status != "active" or latest_revision <= last_revision_before_reconnect) and Time.get_ticks_msec() < reconnect_deadline:
					await physics_frame
				check(client.peer_id == authorized_peer and client.status == "active", "simulated participant reconnects to the same seat; peer=" + str(client.peer_id) + " status=" + client.status)
				check(latest_revision > last_revision_before_reconnect, "authoritative world snapshot resumes after reconnect")
				deadline = Time.get_ticks_msec() + 1000
				continue
			if not reconnect_test or did_reconnect:
				break
		await physics_frame
	check(_region_and_damage_ready(), "host region and combat state reach simulated participant")
	if reconnect_test:
		check(did_reconnect, "reconnect path was exercised")
	var ready_path := root_path.get_base_dir().path_join(String(fixture.role) + ".ready")
	var ready_file := FileAccess.open(ready_path, FileAccess.WRITE)
	ready_file.store_string("ready")
	ready_file.close()
	var release_deadline := Time.get_ticks_msec() + 30000
	while not FileAccess.file_exists(root_path.get_base_dir().path_join("release")) and Time.get_ticks_msec() < release_deadline:
		await physics_frame
	client.leave()
	print("SIMULATED_GAMEPLAY_REPORT role=", fixture.role, " failures=", failures)
	quit(0 if failures == 0 else 1)

func _on_state(revision: int, state: Dictionary) -> void:
	if revision <= latest_revision:
		return
	latest_revision = revision
	latest_state = state

func _region_and_damage_ready() -> bool:
	if latest_state.get("world_state") is not Dictionary:
		return false
	var world: Dictionary = latest_state.world_state
	if bool(world.get("hub", true)) or String(world.get("signature", "")).is_empty():
		return false
	var enemies: Dictionary = world.get("enemies", {})
	for encoded: Variant in enemies.values():
		var enemy: Variant = WIRE.decode(encoded)
		if enemy is Dictionary and int(enemy.get("health", -1)) == 51:
			return true
	return false
