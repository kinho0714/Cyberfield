extends SceneTree

const PLAYER_SCENE := preload("res://entities/player.tscn")
const LAN_SESSION_SCRIPT := preload("res://scene/network/lan_session.gd")
const ROOM_MANAGER_SCRIPT := preload("res://scene/room_manager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_authoritative_epoch_contract()
	await _test_transition_target_reset()
	await _test_collision_safe_reconciliation()
	await _test_one_way_platform_reconciliation()
	await _test_safe_hard_snap()
	_test_reconciliation_is_not_in_process()
	await _test_participant_uniqueness_guard()
	print("PHASE_B_LAN_TRANSITION_RECONCILIATION_SMOKE_TEST_PASSED")
	quit(0)


func _test_authoritative_epoch_contract() -> void:
	var session := LAN_SESSION_SCRIPT.new() as LanSession
	session.role = LanSession.Role.HOST
	assert(session.advance_world_epoch_authoritative() == 1)
	assert(session.advance_world_epoch_authoritative() == 2)
	session.role = LanSession.Role.CLIENT
	assert(session.adopt_authoritative_world_epoch(2))
	assert(session.world_epoch == 2)
	assert(not session.adopt_authoritative_world_epoch(1))
	assert(session.world_epoch == 2)
	assert(session.is_snapshot_epoch_current(2))
	assert(not session.is_snapshot_epoch_current(1))
	assert(not session.is_snapshot_epoch_current(3))
	session.queue_free()


func _test_transition_target_reset() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame
	player.network_target_position = Vector2(40.0, 50.0)
	player.network_target_velocity = Vector2(100.0, 20.0)
	player.network_correction_velocity = Vector2(80.0, 30.0)
	player.network_has_pending_snap = true
	var spawn := Vector2(320.0, 240.0)
	player.reset_network_presentation(spawn, Vector2.ZERO, 7)
	assert(player.global_position == spawn)
	assert(player.network_target_position == spawn)
	assert(player.network_target_velocity == Vector2.ZERO)
	assert(player.network_correction_velocity == Vector2.ZERO)
	assert(not player.network_has_pending_snap)
	assert(player.network_world_epoch == 7)
	player.queue_free()
	await process_frame


func _test_collision_safe_reconciliation() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.network_prediction_only = true
	player.input_enabled = false
	root.add_child(player)
	var wall := _make_static_box(Vector2(400.0, 300.0), Vector2(24.0, 240.0))
	await physics_frame
	player.global_position = Vector2(350.0, 300.0)
	player.network_correction_velocity = Vector2(1200.0, 0.0)
	for frame_index in 12:
		await physics_frame
	assert(player.global_position.x < 388.0)
	assert(player.test_move(player.global_transform, Vector2(24.0, 0.0)))
	wall.queue_free()
	player.queue_free()
	await process_frame


func _test_safe_hard_snap() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.network_prediction_only = true
	player.input_enabled = false
	root.add_child(player)
	var solid := _make_static_box(Vector2(650.0, 300.0), Vector2(80.0, 120.0))
	await physics_frame
	player.global_position = Vector2(100.0, 300.0)
	player.apply_network_state({"position": Vector2(650.0, 300.0), "velocity": Vector2.ZERO}, true, 3)
	assert(player.network_has_pending_snap)
	await physics_frame
	assert(player.global_position != Vector2(650.0, 300.0))
	assert(not player.network_has_pending_snap)
	player.apply_network_state({"position": Vector2(300.0, 300.0), "velocity": Vector2.ZERO}, true, 3)
	await physics_frame
	assert(player.global_position == Vector2(300.0, 300.0))
	solid.queue_free()
	player.queue_free()
	await process_frame


func _test_one_way_platform_reconciliation() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.network_prediction_only = true
	player.input_enabled = false
	root.add_child(player)
	var platform := _make_static_box(Vector2(500.0, 320.0), Vector2(180.0, 8.0), true)
	await physics_frame
	player.global_position = Vector2(500.0, 270.0)
	player.network_correction_velocity = Vector2(0.0, 1200.0)
	for frame_index in 12:
		await physics_frame
	assert(player.global_position.y < 320.0)
	platform.queue_free()
	player.queue_free()
	await process_frame


func _test_reconciliation_is_not_in_process() -> void:
	var source := FileAccess.get_file_as_string("res://entities/player.gd")
	var process_start := source.find("func _process(delta: float) -> void:")
	var physics_start := source.find("func _physics_process(delta: float) -> void:")
	var process_source := source.substr(process_start, physics_start - process_start)
	assert(not process_source.contains("network_correction_velocity * delta"))
	assert(not process_source.contains("global_position += correction_step"))
	assert(source.contains("move_and_collide(correction_step"))


func _test_participant_uniqueness_guard() -> void:
	var manager := ROOM_MANAGER_SCRIPT.new()
	var first := PLAYER_SCENE.instantiate()
	first.participant_id = &"player_1"
	var second := PLAYER_SCENE.instantiate()
	second.participant_id = &"player_1"
	assert(manager.find_duplicate_participant_ids([first, second]) == [&"player_1"])
	second.participant_id = &"player_2"
	assert(manager.find_duplicate_participant_ids([first, second]).is_empty())
	first.free()
	second.free()
	manager.queue_free()
	await process_frame


func _make_static_box(center: Vector2, size: Vector2, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.one_way_collision = one_way
	body.add_child(collision)
	root.add_child(body)
	return body
