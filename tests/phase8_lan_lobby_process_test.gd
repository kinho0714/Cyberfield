extends SceneTree

const MAIN_SCENE := preload("res://scene/main.tscn")

var role_name := ""
var started_at_msec := 0
var main: Node
var lobby: Node
var session: LanSession
var manager: Node
var last_host_count := 0
var run_requested := false
var run_started_at_msec := 0
var routed_participant_index := 2
var last_route_at_msec := 0


func _initialize() -> void:
	role_name = OS.get_environment("CYBERFIELD_LAN_LOBBY_TEST_ROLE")
	started_at_msec = Time.get_ticks_msec()
	call_deferred("_start")


func _start() -> void:
	main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	lobby = main.get_node("LanLobby")
	session = main.get_node("LanSession") as LanSession
	manager = main
	lobby.open()
	await process_frame
	if role_name == "host":
		_touch(lobby.get_node("Overlay/Center/MainPage/Create") as Control)
	else:
		_touch(lobby.get_node("Overlay/Center/MainPage/DirectIp") as Control)
		await process_frame
		(lobby.get_node("Overlay/Center/IpPage/IpInput") as LineEdit).text = "127.0.0.1"
		_touch(lobby.get_node("Overlay/Center/IpPage/Join") as Control)


func _process(_delta: float) -> bool:
	if session == null:
		return false
	var elapsed := float(Time.get_ticks_msec() - started_at_msec) / 1000.0
	if role_name == "host":
		_test_host_flow()
	else:
		_test_client_flow()
	if elapsed > 30.0:
		push_error("LAN_LOBBY_PROCESS_TIMEOUT_%s_COUNT_%d" % [role_name, session.get_player_count()])
		quit(1)
	return false


func _test_host_flow() -> void:
	var player_count := session.get_player_count()
	if session.is_host() and not run_requested and player_count != last_host_count:
		last_host_count = player_count
		var difficulty := lobby.get_node("Overlay/Center/HostPage/Difficulty") as OptionButton
		var previous_selection := difficulty.selected
		_touch(difficulty)
		assert(difficulty.selected != previous_selection and not difficulty.get_popup().visible)
	if player_count == LanSession.MAX_PLAYERS and not run_requested:
		run_requested = true
		_touch(lobby.get_node("Overlay/Center/HostPage/Start") as Control)
	if not run_requested or not bool(manager.mode_selected) or not manager.run_manager.run_active:
		return
	if run_started_at_msec == 0:
		run_started_at_msec = Time.get_ticks_msec()
		return
	var now := Time.get_ticks_msec()
	if now - run_started_at_msec < 1000:
		return
	if routed_participant_index <= LanSession.MAX_PLAYERS and now - last_route_at_msec >= 500:
		var participant_id := StringName("player_%d" % routed_participant_index)
		var remote_player: Node2D = manager._find_player(participant_id) as Node2D
		var teleporters := get_nodes_in_group("biome_teleporter")
		var full_map := get_first_node_in_group("full_map") as Control
		var host_player: Node = manager._find_player(&"player_1")
		assert(remote_player != null and not teleporters.is_empty())
		assert(full_map != null and not full_map.visible)
		assert(host_player != null and bool(host_player.get("input_enabled")))
		manager.open_teleporter_menu(StringName(teleporters[0].teleporter_id), remote_player)
		assert(not full_map.visible and bool(host_player.get("input_enabled")))
		last_route_at_msec = now
		routed_participant_index += 1
		return
	if routed_participant_index > LanSession.MAX_PLAYERS and now - last_route_at_msec >= 1000:
		print("PHASE8_LAN_LOBBY_PROCESS_HOST_PASSED_REMOTE_INTERACTIONS")
		quit(0)


func _test_client_flow() -> void:
	if session.is_client() and (lobby.get("host_page") as Control).visible:
		assert((lobby.get_node("Overlay/Center/HostPage/Difficulty") as OptionButton).disabled)
	if bool(manager.mode_selected) and manager.run_manager.run_active:
		assert(session.get_local_participant_id() != &"player_1")
		var full_map := get_first_node_in_group("full_map") as Control
		if full_map != null and full_map.visible:
			var local_player: Node = manager._find_player(session.get_local_participant_id())
			assert(not StringName(full_map.get("source_teleporter_id")).is_empty())
			assert(local_player != null and not bool(local_player.get("input_enabled")))
			full_map.close_map()
			assert(bool(local_player.get("input_enabled")))
			print("PHASE8_LAN_LOBBY_PROCESS_CLIENT_PASSED_REMOTE_INTERACTION_%s" % session.get_local_participant_id())
			quit(0)


func _touch(control: Control) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 91
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	lobby._input(event)
