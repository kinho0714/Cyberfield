extends SceneTree

const MAIN_SCENE := preload("res://scene/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var lobby: Node = main.get_node("LanLobby")
	var session := main.get_node("LanSession") as LanSession
	lobby.open()
	_touch(lobby, lobby.get_node("Overlay/Center/MainPage/Create") as Control)
	await process_frame
	assert(session.is_host() and session.get_player_count() == 1)
	assert((lobby.get("host_page") as Control).visible)
	var difficulty := lobby.get_node("Overlay/Center/HostPage/Difficulty") as OptionButton
	var first_selection := difficulty.selected
	_touch(lobby, difficulty)
	assert(difficulty.selected != first_selection)
	assert(not difficulty.get_popup().visible)

	for peer_id in [21, 35, 49]:
		session._on_peer_connected(peer_id)
		await process_frame
		var previous_selection := difficulty.selected
		_touch(lobby, difficulty)
		assert(difficulty.selected != previous_selection)
		assert(not difficulty.get_popup().visible)
	assert(session.get_player_count() == 4)
	assert(lobby.has_method("_handle_touch_pressed"))
	session.shutdown()
	main.free()
	print("PHASE8_LAN_LOBBY_TOUCH_SMOKE_TEST_PASSED")
	quit(0)


func _touch(lobby: Node, control: Control) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 81
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	lobby._input(event)
