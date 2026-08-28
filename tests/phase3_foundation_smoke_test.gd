extends SceneTree

const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const ROOM_MANAGER_SCRIPT := preload("res://scene/room_manager.gd")
const LOCAL_SETTINGS_SCRIPT := preload("res://scene/local_settings.gd")
const MAIN_SCENE := preload("res://scene/main.tscn")
const PROJECTILE_SCENE := preload("res://entities/ranged_projectile.tscn")
const PLAYER_SCENE := preload("res://entities/player.tscn")
const ATTRIBUTE_CHEST_SCENE := preload("res://scene/interactables/attribute_chest.tscn")
const TEST_SETTINGS_PATH := "user://cyberfield_phase3_smoke_settings.cfg"

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_camera_contracts()
	_test_player_and_projectile_contracts()
	_test_participant_reward_ownership()
	_test_stage_limit()
	_test_settings_round_trip()
	await _test_lobby_selection_contract()
	_cleanup_settings_file()
	if failures.is_empty():
		print("PHASE3_FOUNDATION_SMOKE_TEST_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_camera_contracts() -> void:
	_check(ROOM_MANAGER_SCRIPT.CAMERA_ZOOM_MIN > 0.0, "camera minimum zoom must be positive")
	_check(ROOM_MANAGER_SCRIPT.CAMERA_ZOOM_MIN < ROOM_MANAGER_SCRIPT.CAMERA_ZOOM_MAX, "camera zoom bounds must be ordered")
	_check(ROOM_MANAGER_SCRIPT.COOP_SAFE_DISTANCE < ROOM_MANAGER_SCRIPT.COOP_SOFT_LIMIT, "safe distance must precede soft limit")
	_check(ROOM_MANAGER_SCRIPT.COOP_SOFT_LIMIT < ROOM_MANAGER_SCRIPT.COOP_HARD_LIMIT, "soft limit must precede hard limit")


func _test_player_and_projectile_contracts() -> void:
	var player := PLAYER_SCENE.instantiate()
	_check("network_prediction_only" in player, "Player must expose prediction mode")
	_check("network_remote_replica" in player, "Player must expose remote interpolation mode")
	_check(player.has_method("apply_network_state"), "Player must support authoritative reconciliation")
	player.free()
	var projectile := PROJECTILE_SCENE.instantiate()
	_check("network_id" in projectile, "ranged projectile must expose a network id")
	_check("network_visual_only" in projectile, "ranged projectile must support client visual replicas")
	projectile.free()


func _test_participant_reward_ownership() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.add_to_group("run_manager")
	manager.configure_run(&"lan", &"normal")
	manager.prepare_new_run(730031)
	manager.enter_boss_stage()
	var room_id: StringName = manager.get_current_room_id()
	var player_one := PLAYER_SCENE.instantiate()
	player_one.participant_id = &"player_1"
	root.add_child(player_one)
	var player_two := PLAYER_SCENE.instantiate()
	player_two.participant_id = &"player_2"
	root.add_child(player_two)
	var chest := ATTRIBUTE_CHEST_SCENE.instantiate()
	chest.chest_id = &"ownership_test"
	root.add_child(chest)
	_check(chest.apply_choice(player_one, &"strength"), "P1 reward choice must be accepted")
	_check(chest.apply_choice(player_two, &"intellect"), "P2 reward choice must be accepted independently")
	_check(manager.has_chest_choice(room_id, &"ownership_test", &"player_1"), "P1 reward ownership must be stored")
	_check(manager.has_chest_choice(room_id, &"ownership_test", &"player_2"), "P2 reward ownership must be stored")
	_check(player_one.strength == 1 and player_one.intellect == 0, "P1 must receive only its own attribute")
	_check(player_two.intellect == 1 and player_two.strength == 0, "P2 must receive only its own attribute")
	_check(not manager.record_chest_choice(room_id, &"ownership_test", &"player_2", &"intellect"), "one participant must not collect the same reward twice")
	chest.free()
	player_one.free()
	player_two.free()
	manager.free()


func _test_stage_limit() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.configure_run(&"solo", &"normal")
	manager.start_new_run(730032)
	manager.current_biome_id = &"lower_city"
	manager.room_states[&"lower_city"] = manager._new_room_state()
	for stage in 5:
		_check(manager.advance_stage(StringName("exit_%d" % stage), &"next_biome"), "stage %d must advance" % (stage + 1))
		if stage < 4:
			manager.current_biome_id = StringName("test_stage_%d" % stage)
			manager.room_states[manager.current_biome_id] = manager._new_room_state()
	_check(manager.stage_index == 5, "Stage 5 must lead to Stage 6 boss index")
	_check(not manager.advance_stage(&"exit_forbidden", &"stage_07"), "Stage 7 must never be generated")
	manager.enter_boss_stage()
	manager.finish_run()
	_check(manager.run_is_completed and not manager.run_active, "boss completion must finish the run")
	manager.free()


func _test_settings_round_trip() -> void:
	_cleanup_settings_file()
	var writer := LOCAL_SETTINGS_SCRIPT.new()
	writer.settings_path = TEST_SETTINGS_PATH
	root.add_child(writer)
	writer.set_camera_zoom_preference(&"close")
	writer.set_touch_control_scale(1.35)
	writer.set_debug_hud_visible(false)
	var reader := LOCAL_SETTINGS_SCRIPT.new()
	reader.settings_path = TEST_SETTINGS_PATH
	root.add_child(reader)
	reader.load_settings()
	_check(reader.camera_zoom_preference == &"close", "camera zoom preference must persist locally")
	_check(is_equal_approx(reader.touch_control_scale, 1.35), "mobile control scale must persist locally")
	_check(not reader.debug_hud_visible, "debug HUD preference must persist locally")
	writer.free()
	reader.free()


func _test_lobby_selection_contract() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var lobby := main.get_node("LanLobby")
	var session := main.get_node("LanSession")
	var join_button := lobby.get_node("Overlay/Center/SearchPage/Join") as Button
	_check(join_button.disabled, "LAN Enter button must start disabled")
	var discovered_rooms: Array[Dictionary] = [{"name": "Test Room", "address": "127.0.0.1", "port": session.GAME_PORT, "players": 1}]
	session.discovered_rooms = discovered_rooms
	lobby._refresh_rooms()
	lobby._select_room(0)
	_check(not join_button.disabled, "one tap must select a room and enable Enter")
	main.free()


func _cleanup_settings_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(absolute_path)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
