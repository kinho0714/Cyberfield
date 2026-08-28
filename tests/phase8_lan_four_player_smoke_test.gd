extends SceneTree

const MAIN_SCENE := preload("res://scene/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var lan := main.get_node("LanSession") as LanSession
	var manager := main as Node2D

	assert(LanSession.MAX_PLAYERS == 4)
	assert(LanSession.PROTOCOL_VERSION == 3)
	lan.role = LanSession.Role.HOST
	for peer_id in [21, 35, 49]:
		lan._on_peer_connected(peer_id)
	assert(lan.get_player_count() == 4)
	assert(lan.get_participant_for_peer(21) == &"player_2")
	assert(lan.get_participant_for_peer(35) == &"player_3")
	assert(lan.get_participant_for_peer(49) == &"player_4")
	lan._apply_remote_input(&"player_3", {"left": 0.75, "jump": true})
	assert(Input.get_action_strength(&"p3_left") == 0.75)
	assert(Input.is_action_pressed(&"p3_jump"))
	lan._release_remote_player_inputs(&"player_3")
	assert(not Input.is_action_pressed(&"p3_left") and not Input.is_action_pressed(&"p3_jump"))

	for player_count in range(1, LanSession.MAX_PLAYERS + 1):
		manager._create_network_players(player_count)
		await process_frame
		var players: Array[Node] = manager.get_players()
		assert(players.size() == player_count)
		manager.run_manager.configure_run(&"lan", &"normal", -1, player_count)
		assert(manager.run_manager.player_count == player_count)
		for index in player_count:
			assert(players[index].participant_id == StringName("player_%d" % (index + 1)))

	lan.local_participant_id = &"player_4"
	manager._configure_client_player_prediction()
	var local_count := 0
	for player in manager.get_players():
		if player.participant_id == &"player_4":
			assert(player.input_profile == "p1")
			assert(player.network_prediction_only)
			local_count += 1
		else:
			assert(player.network_remote_replica)
	assert(local_count == 1)

	lan._on_peer_disconnected(35)
	assert(lan.get_player_count() == 3)
	assert(lan.get_participant_for_peer(35).is_empty())
	assert(lan.get_participant_for_peer(21) == &"player_2")
	assert(lan.get_participant_for_peer(49) == &"player_4")

	print("PHASE8_LAN_FOUR_PLAYER_SMOKE_TEST_PASSED")
	quit(0)
