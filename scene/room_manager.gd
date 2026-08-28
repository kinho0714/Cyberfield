extends Node2D

signal coop_waiting_changed(visible: bool)

const ROOM_BOUNDS := Rect2(0.0, 0.0, 1280.0, 720.0)
const BOUNDARY_THICKNESS := 48.0
const PLAYER_SCENE := preload("res://entities/player.tscn")
const LABORATORY_HUB_SCENE := preload("res://scene/laboratory_hub.tscn")
const LOWER_CITY_BIOME_SCENE := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")
const BOSS_STAGE_SCENE := preload("res://scene/biomes/boss_stage.tscn")
const COOP_SPAWN_OFFSET := 22.0
const EXIT_GROUP_DISTANCE := 96.0
const TELEPORT_GROUP_DISTANCE := 128.0
const COOP_SAFE_DISTANCE := 480.0
const COOP_SOFT_LIMIT := 720.0
const COOP_HARD_LIMIT := 1050.0
const CAMERA_ZOOM_MIN := 0.78
const CAMERA_ZOOM_MAX := 1.22

@export_file("*.tscn") var initial_room_path := "res://scene/levels/cyberfield_area_01.tscn"
@export var initial_entry_id := &"start"
@export_range(0.05, 2.0, 0.05) var fade_duration := 0.25

@onready var room_container: Node2D = $RoomContainer
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var run_manager: Node = $RunManager
@onready var mode_select: CanvasLayer = $ModeSelect
@onready var gameplay_camera: Camera2D = $Camera2D
@onready var lan_session: LanSession = $LanSession
@onready var lan_lobby: CanvasLayer = $LanLobby
@onready var local_settings: LocalSettings = $LocalSettings

var current_room: Node = null
var is_transitioning := false
var mode_selected := false
var current_is_hub := false
var current_is_generated_biome := false
var generated_biome_bounds := Rect2()
var fast_travel_vote_origin: StringName
var fast_travel_vote_destination: StringName
var fast_travel_confirmations: Dictionary = {}


func _ready() -> void:
	add_to_group("room_manager")
	run_manager.add_to_group("run_manager")
	fade_rect.modulate.a = 0.0
	$RunDebugHUD.visible = false
	mode_select.run_requested.connect(start_configured_run)
	mode_select.lan_requested.connect(_show_lan_lobby)
	lan_lobby.close_requested.connect(_show_mode_selection)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _process(delta: float) -> void:
	if not current_is_generated_biome or is_transitioning:
		return
	var active_players := get_players().filter(func(player: Node) -> bool: return player.visible and not player.is_downed)
	if active_players.is_empty():
		return
	var target := Vector2.ZERO
	for player in active_players:
		target += player.global_position
	target /= float(active_players.size())
	var half_view := get_viewport_rect().size * 0.5
	target.x = clampf(target.x, generated_biome_bounds.position.x + half_view.x, generated_biome_bounds.end.x - half_view.x)
	target.y = clampf(target.y, generated_biome_bounds.position.y + half_view.y, generated_biome_bounds.end.y - half_view.y)
	gameplay_camera.global_position = target
	_update_coop_camera(active_players, delta)
	if active_players.size() >= 2 and (not lan_session.is_network_game() or lan_session.is_host()):
		_apply_coop_distance_limits(active_players)


func _update_coop_camera(players: Array, delta: float) -> void:
	var base_zoom := local_settings.get_camera_zoom_base()
	var desired_zoom := base_zoom
	if players.size() >= 2:
		var separation := _maximum_player_separation(players)
		var separation_ratio := clampf((separation - COOP_SAFE_DISTANCE) / (COOP_HARD_LIMIT - COOP_SAFE_DISTANCE), 0.0, 1.0)
		desired_zoom = lerpf(base_zoom, CAMERA_ZOOM_MIN, separation_ratio)
	desired_zoom = clampf(desired_zoom, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	var current_zoom := gameplay_camera.zoom.x
	var next_zoom := lerpf(current_zoom, desired_zoom, 1.0 - exp(-4.5 * delta))
	gameplay_camera.zoom = Vector2.ONE * next_zoom


func _apply_coop_distance_limits(players: Array) -> void:
	for player_value: Variant in players:
		var player := player_value as CharacterBody2D
		var leader := _nearest_other_player(player, players)
		if leader == null:
			continue
		var separation := player.global_position.distance_to(leader.global_position)
		if separation > COOP_SOFT_LIMIT:
			var strength := clampf((separation - COOP_SOFT_LIMIT) / (COOP_HARD_LIMIT - COOP_SOFT_LIMIT), 0.0, 1.0)
			var away := (player.global_position - leader.global_position).normalized()
			if player.velocity.dot(away) > 0.0:
				player.velocity *= 1.0 - strength * 0.85
		if separation > COOP_HARD_LIMIT:
			player.global_position = _find_safe_tether_position(player, leader)
			player.velocity = Vector2.ZERO


func _maximum_player_separation(players: Array) -> float:
	var maximum := 0.0
	for first_index in players.size():
		for second_index in range(first_index + 1, players.size()):
			maximum = maxf(maximum, players[first_index].global_position.distance_to(players[second_index].global_position))
	return maximum


func _nearest_other_player(player: CharacterBody2D, players: Array) -> CharacterBody2D:
	var nearest: CharacterBody2D = null
	var nearest_distance := INF
	for candidate_value: Variant in players:
		var candidate := candidate_value as CharacterBody2D
		if candidate == player:
			continue
		var distance := player.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _find_safe_tether_position(player: CharacterBody2D, leader: CharacterBody2D) -> Vector2:
	var direction := signf(player.global_position.x - leader.global_position.x)
	if direction == 0.0:
		direction = -1.0
	var candidates: Array[Vector2] = [
		leader.global_position + Vector2(direction * 96.0, -40.0),
		leader.global_position + Vector2(-direction * 96.0, -40.0),
		leader.global_position + Vector2(direction * 144.0, -64.0),
	]
	var collision_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return candidates[0]
	for candidate_value: Variant in candidates:
		var candidate: Vector2 = candidate_value
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision_shape.shape
		query.transform = Transform2D(0.0, candidate + collision_shape.position)
		query.collision_mask = player.collision_mask
		query.exclude = [player.get_rid(), leader.get_rid()]
		if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return leader.global_position + Vector2(0.0, -80.0)


func start_game_mode(mode: StringName) -> void:
	start_configured_run(mode, &"normal", _first_connected_joypad() if mode == &"coop" else -1)


func start_configured_run(mode: StringName, difficulty: StringName, joypad_device_id: int) -> void:
	if mode_selected or is_transitioning:
		return
	if mode == &"coop" and not Input.get_connected_joypads().has(joypad_device_id):
		mode_select.focus_default()
		return

	is_transitioning = true
	await _fade_to(1.0)
	run_manager.configure_run(mode, difficulty, joypad_device_id)
	run_manager.prepare_hub()
	_create_players(mode == &"coop", joypad_device_id)
	for candidate in get_players():
		run_manager.register_participant(candidate.participant_id, true)
	if not _load_laboratory_hub():
		await _clear_run_and_show_menu()
		return
	mode_selected = true
	mode_select.visible = false
	$RunDebugHUD.visible = true
	await _fade_to(0.0)
	_set_all_player_input(true)
	is_transitioning = false


func start_lan_run(config: Dictionary, host_authority: bool) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	await _fade_to(1.0)
	var network_difficulty := StringName(config.get("difficulty", "normal"))
	var network_seed := int(config.get("seed", 0))
	var network_player_count := clampi(int(config.get("player_count", 2)), 1, LanSession.MAX_PLAYERS)
	run_manager.configure_run(&"lan", network_difficulty, -1, network_player_count)
	run_manager.configure_run_weapon_pool(config.get("weapon_pool", []) as Array)
	run_manager.prepare_new_run(network_seed, true)
	_create_network_players(network_player_count)
	for candidate in get_players():
		candidate.reset_for_new_run()
		run_manager.register_participant(candidate.participant_id, true)
	if not _load_lower_city_biome(network_seed):
		await _clear_run_and_show_menu()
		return
	run_manager.activate_run()
	mode_selected = true
	mode_select.visible = false
	lan_lobby.close_for_run()
	$RunDebugHUD.visible = true
	if not host_authority:
		_configure_client_player_prediction()
		_set_client_world_passive()
	await get_tree().process_frame
	await _fade_to(0.0)
	if host_authority:
		_set_all_player_input(true)
	is_transitioning = false


func handle_lan_host_disconnected() -> void:
	if is_transitioning:
		return
	await _clear_run_and_show_menu()
	lan_lobby.show_connection_error("O HOST DESCONECTOU")
	mode_select.visible = false


func _show_lan_lobby() -> void:
	mode_select.visible = false
	lan_lobby.open()


func _show_mode_selection() -> void:
	mode_select.visible = true
	mode_select.focus_default()


func _set_client_world_passive() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.network_target_position = enemy.global_position
		enemy.set_physics_process(false)


func _configure_client_player_prediction() -> void:
	for player in get_players():
		if player.participant_id == lan_session.get_local_participant_id():
			player.input_profile = "p1"
			player.network_prediction_only = true
			player.network_remote_replica = false
			player.set_input_enabled(true)
		else:
			player.network_prediction_only = false
			player.network_remote_replica = true
			player.network_target_position = player.global_position
			player.set_input_enabled(false)


func request_start_run_from_hub(portal: Area2D, interactor: Node2D) -> void:
	if is_transitioning or not can_start_run_from_hub(portal, interactor):
		return
	is_transitioning = true
	coop_waiting_changed.emit(false)
	_set_all_player_input(false)
	await _fade_to(1.0)
	run_manager.prepare_new_run()
	for candidate in get_players():
		candidate.reset_for_new_run()
		run_manager.register_participant(candidate.participant_id, true)
	if not _load_lower_city_biome():
		run_manager.prepare_hub()
		_load_laboratory_hub()
		await _fade_to(0.0)
		_set_all_player_input(true)
		is_transitioning = false
		return
	run_manager.activate_run()
	await get_tree().process_frame
	await _fade_to(0.0)
	_set_all_player_input(true)
	is_transitioning = false


func request_biome_advance(exit_id: StringName, destination_id: StringName) -> void:
	if is_transitioning or not run_manager.run_active:
		return
	is_transitioning = true
	_set_all_player_input(false)
	await _fade_to(1.0)
	if not run_manager.advance_stage(exit_id, destination_id):
		await _fade_to(0.0)
		_set_all_player_input(true)
		is_transitioning = false
		return
	var stage_seed: int = run_manager.get_stage_seed()
	if lan_session.is_host():
		lan_session.broadcast_stage_transition(exit_id, destination_id, stage_seed)
	if not _load_current_stage(stage_seed):
		push_error("Could not load placeholder stage for %s" % destination_id)
		await _fade_to(0.0)
		_set_all_player_input(true)
		is_transitioning = false
		return
	await get_tree().process_frame
	await _fade_to(0.0)
	_set_all_player_input(true)
	is_transitioning = false


func apply_lan_stage_transition(exit_id: StringName, destination_id: StringName, stage_seed: int) -> void:
	if is_transitioning or not lan_session.is_network_game():
		return
	is_transitioning = true
	await _fade_to(1.0)
	if not run_manager.advance_stage(exit_id, destination_id) or not _load_current_stage(stage_seed):
		push_error("Client could not apply LAN stage transition")
		await _fade_to(0.0)
		is_transitioning = false
		return
	_configure_client_player_prediction()
	_set_client_world_passive()
	await get_tree().process_frame
	await _fade_to(0.0)
	is_transitioning = false


func can_start_run_from_hub(portal: Area2D, interactor: Node2D) -> bool:
	if not mode_selected or not current_is_hub or run_manager.run_active:
		return false
	if interactor == null or interactor.is_downed or not portal.overlaps_body(interactor):
		return false
	for candidate in get_players():
		var player_body := candidate as CharacterBody2D
		if player_body == null or candidate.is_downed or not portal.overlaps_body(player_body):
			coop_waiting_changed.emit(run_manager.is_coop())
			return false
	coop_waiting_changed.emit(false)
	return true


func return_to_laboratory() -> void:
	if is_transitioning or not mode_selected:
		return
	if lan_session.is_client():
		lan_session.request_return_to_laboratory()
		return
	if lan_session.is_host():
		lan_session.broadcast_return_to_laboratory()
	await _return_to_laboratory_local()


func apply_network_return_to_laboratory() -> void:
	if lan_session.is_client() and not is_transitioning and mode_selected:
		await _return_to_laboratory_local()


func _return_to_laboratory_local() -> void:
	is_transitioning = true
	_set_all_player_input(false)
	await _fade_to(1.0)
	run_manager.prepare_hub()
	for candidate in get_players():
		candidate.reset_for_new_run()
		run_manager.register_participant(candidate.participant_id, true)
	if not _load_laboratory_hub():
		await _clear_run_and_show_menu()
		return
	coop_waiting_changed.emit(false)
	$RunDebugHUD.visible = true
	await get_tree().process_frame
	await _fade_to(0.0)
	_set_all_player_input(true)
	is_transitioning = false
	_show_latest_run_results()


func abandon_current_run() -> void:
	if is_transitioning or not mode_selected:
		return
	if lan_session.is_network_game():
		lan_session.shutdown()
		run_manager.configure_run(&"solo", run_manager.difficulty)
		for candidate in get_players():
			if candidate.participant_id != &"player_1":
				candidate.queue_free()
			else:
				candidate.input_profile = "p1"
				candidate.network_prediction_only = false
				candidate.network_remote_replica = false
		await get_tree().process_frame
	await return_to_laboratory()


func return_to_mode_selection() -> void:
	return_to_main_menu()


func return_to_main_menu() -> void:
	if is_transitioning:
		return
	await _clear_run_and_show_menu()


func _clear_run_and_show_menu() -> void:
	is_transitioning = true
	_set_all_player_input(false)
	await _fade_to(1.0)
	if is_instance_valid(current_room):
		current_room.queue_free()
		current_room = null
	for candidate in get_players():
		candidate.queue_free()
	await get_tree().process_frame
	lan_session.shutdown()
	run_manager.clear_run()
	current_is_hub = false
	current_is_generated_biome = false
	_reset_camera_for_room()
	mode_selected = false
	coop_waiting_changed.emit(false)
	$RunDebugHUD.visible = false
	mode_select.visible = true
	mode_select.focus_default()
	await _fade_to(0.0)
	is_transitioning = false


func request_room_change(room_path: String, entry_id: StringName) -> void:
	if is_transitioning or room_path.is_empty():
		return
	is_transitioning = true
	_set_all_player_input(false)
	await _fade_to(1.0)
	if not _load_room(room_path, entry_id):
		await _fade_to(0.0)
		_set_all_player_input(true)
		is_transitioning = false
		return
	await get_tree().process_frame
	await _fade_to(0.0)
	_set_all_player_input(run_manager.run_active)
	is_transitioning = false


func restart_current_run() -> void:
	return_to_laboratory()


func _load_room(room_path: String, entry_id: StringName) -> bool:
	var packed_room := load(room_path) as PackedScene
	if packed_room == null:
		push_error("Could not load room: %s" % room_path)
		return false
	var new_room := packed_room.instantiate()
	var room_id: StringName = run_manager.enter_room_by_path(room_path)
	run_manager.prepare_room(room_id, new_room)
	_add_room_safety(new_room)
	room_container.add_child(new_room)
	var entry_point := _find_entry_point(new_room, entry_id)
	if entry_point == null:
		push_error("Entry '%s' was not found in room: %s" % [entry_id, room_path])
		new_room.queue_free()
		return false
	if is_instance_valid(current_room):
		current_room.queue_free()
	current_room = new_room
	current_is_hub = false
	current_is_generated_biome = false
	_reset_camera_for_room()
	_position_players(entry_point.global_position)
	return true


func _load_lower_city_biome(generation_seed: int = 0) -> bool:
	var generated_biome := LOWER_CITY_BIOME_SCENE.instantiate()
	var seed_to_use: int = run_manager.seed_value if generation_seed == 0 else generation_seed
	if not generated_biome.generate(seed_to_use, run_manager):
		push_error("Lower City generation and fallback both failed")
		generated_biome.queue_free()
		return false
	var report: Dictionary = generated_biome.get_generation_report()
	run_manager.enter_generated_biome(report)
	room_container.add_child(generated_biome)
	run_manager.prepare_generated_biome(generated_biome)
	if is_instance_valid(current_room):
		current_room.queue_free()
	current_room = generated_biome
	current_is_hub = false
	current_is_generated_biome = true
	generated_biome_bounds = generated_biome.get_generated_bounds()
	_configure_camera_for_biome(generated_biome_bounds, generated_biome.get_start_position())
	_position_players_in_biome(generated_biome.get_start_position())
	refresh_teleporter_states()
	return true


func _load_current_stage(generation_seed: int) -> bool:
	if run_manager.stage_index == 5:
		return _load_boss_stage()
	return _load_lower_city_biome(generation_seed)


func _load_boss_stage() -> bool:
	var boss_stage := BOSS_STAGE_SCENE.instantiate()
	room_container.add_child(boss_stage)
	run_manager.enter_boss_stage()
	boss_stage.setup(run_manager)
	run_manager.prepare_boss_stage(boss_stage)
	if is_instance_valid(current_room):
		current_room.queue_free()
	current_room = boss_stage
	current_is_hub = false
	current_is_generated_biome = true
	generated_biome_bounds = boss_stage.get_generated_bounds()
	_configure_camera_for_biome(generated_biome_bounds, boss_stage.get_start_position())
	_position_players_in_biome(boss_stage.get_start_position())
	return true


func _load_laboratory_hub() -> bool:
	var new_hub := LABORATORY_HUB_SCENE.instantiate()
	room_container.add_child(new_hub)
	var p1_spawn := new_hub.get_node_or_null("Gameplay/P1Spawn") as Marker2D
	var p2_spawn := new_hub.get_node_or_null("Gameplay/P2Spawn") as Marker2D
	if p1_spawn == null or p2_spawn == null:
		push_error("Laboratory Hub is missing P1Spawn or P2Spawn")
		new_hub.queue_free()
		return false
	if is_instance_valid(current_room):
		current_room.queue_free()
	current_room = new_hub
	current_is_hub = true
	current_is_generated_biome = false
	_reset_camera_for_room()
	_position_players_in_hub(p1_spawn.global_position, p2_spawn.global_position)
	return true


func _show_latest_run_results() -> void:
	var result_ui := get_tree().get_first_node_in_group("run_result_ui")
	if result_ui != null:
		result_ui.show_latest_results()


func get_players() -> Array[Node]:
	var result: Array[Node] = []
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate.get_parent() == self:
			result.append(candidate)
	result.sort_custom(func(a: Node, b: Node) -> bool: return String(a.participant_id) < String(b.participant_id))
	return result


func request_teleporter_activation(teleporter_id: StringName, interactor: Node2D) -> void:
	if not current_is_generated_biome or interactor == null:
		return
	if lan_session.is_client():
		lan_session.request_teleporter_activation(teleporter_id)
		return
	activate_teleporter_authoritative(teleporter_id, interactor.participant_id)


func activate_teleporter_authoritative(teleporter_id: StringName, participant_id: StringName) -> bool:
	var teleporter := _find_teleporter(teleporter_id)
	var interactor := _find_player(participant_id)
	if teleporter == null or interactor == null or interactor.global_position.distance_to(teleporter.global_position) > TELEPORT_GROUP_DISTANCE:
		return false
	run_manager.activate_map_teleporter(teleporter_id)
	teleporter.set_active(true)
	return true


func open_teleporter_menu(origin_id: StringName, interactor: Node2D) -> void:
	if interactor == null:
		return
	var participant_id := StringName(interactor.get("participant_id"))
	if lan_session.is_host() and participant_id != lan_session.get_local_participant_id():
		lan_session.request_remote_teleporter_menu(participant_id, origin_id)
		return
	if lan_session.is_client() and participant_id != lan_session.get_local_participant_id():
		return
	open_local_teleporter_menu(origin_id)


func open_local_teleporter_menu(origin_id: StringName) -> void:
	var full_map := get_tree().get_first_node_in_group("full_map")
	if full_map != null:
		full_map.open_map(origin_id)


func request_fast_travel(origin_id: StringName, destination_id: StringName, participant_id: StringName = &"") -> void:
	var requester := participant_id if not participant_id.is_empty() else lan_session.get_local_participant_id()
	if lan_session.is_client():
		lan_session.request_fast_travel(origin_id, destination_id)
		return
	submit_fast_travel_confirmation(requester, origin_id, destination_id)


func submit_fast_travel_confirmation(participant_id: StringName, origin_id: StringName, destination_id: StringName) -> bool:
	if not run_manager.run_active or is_transitioning or not _valid_fast_travel_pair(origin_id, destination_id):
		return false
	var active_ids := get_active_teleport_participant_ids()
	if not active_ids.has(participant_id):
		return false
	if fast_travel_vote_origin != origin_id or fast_travel_vote_destination != destination_id:
		fast_travel_vote_origin = origin_id
		fast_travel_vote_destination = destination_id
		fast_travel_confirmations.clear()
	fast_travel_confirmations[participant_id] = true
	_publish_fast_travel_vote(active_ids)
	if active_ids.all(func(id: StringName) -> bool: return fast_travel_confirmations.has(id)):
		if perform_fast_travel_authoritative(origin_id, destination_id):
			_clear_fast_travel_vote(false)
			if lan_session.is_host():
				lan_session.broadcast_fast_travel_applied(destination_id)
			return true
	return false


func cancel_fast_travel_confirmation(participant_id: StringName) -> void:
	if fast_travel_vote_origin.is_empty() or not get_active_teleport_participant_ids().has(participant_id):
		return
	# A close action is an explicit decline of the current proposal. Abort the
	# collective vote for everyone so no peer remains blocked waiting for a player
	# who has already returned to gameplay.
	_clear_fast_travel_vote(true)


func handle_teleport_participant_removed(participant_id: StringName) -> void:
	fast_travel_confirmations.erase(participant_id)
	if fast_travel_vote_origin.is_empty():
		return
	var active_ids := get_active_teleport_participant_ids()
	if active_ids.is_empty():
		_clear_fast_travel_vote(true)
		return
	_publish_fast_travel_vote(active_ids)
	if active_ids.all(func(id: StringName) -> bool: return fast_travel_confirmations.has(id)):
		if perform_fast_travel_authoritative(fast_travel_vote_origin, fast_travel_vote_destination):
			var destination_id := fast_travel_vote_destination
			_clear_fast_travel_vote(false)
			if lan_session.is_host():
				lan_session.broadcast_fast_travel_applied(destination_id)


func get_active_teleport_participant_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for player in get_players():
		if player.visible and not player.is_downed and bool(run_manager.participants.get(player.participant_id, true)):
			result.append(player.participant_id)
	return result


func _publish_fast_travel_vote(active_ids: Array[StringName]) -> void:
	var confirmed_ids: Array[StringName] = []
	for participant_value: Variant in fast_travel_confirmations:
		confirmed_ids.append(StringName(participant_value))
	confirmed_ids.sort()
	var full_map := get_tree().get_first_node_in_group("full_map")
	if full_map != null and active_ids.has(lan_session.get_local_participant_id()):
		full_map.apply_fast_travel_vote(fast_travel_vote_origin, fast_travel_vote_destination, confirmed_ids, active_ids)
	if lan_session.is_host():
		lan_session.broadcast_fast_travel_vote(fast_travel_vote_origin, fast_travel_vote_destination, confirmed_ids, active_ids)


func _clear_fast_travel_vote(notify_interfaces: bool) -> void:
	fast_travel_vote_origin = &""
	fast_travel_vote_destination = &""
	fast_travel_confirmations.clear()
	if notify_interfaces:
		var full_map := get_tree().get_first_node_in_group("full_map")
		if full_map != null:
			full_map.clear_fast_travel_vote()
		if lan_session.is_host():
			lan_session.broadcast_fast_travel_vote(&"", &"", [], [])


func _valid_fast_travel_pair(origin_id: StringName, destination_id: StringName) -> bool:
	var state: BiomeMapState = run_manager.get_current_map_state()
	return origin_id != destination_id and _find_teleporter(origin_id) != null and _find_teleporter(destination_id) != null and state.active_teleporter_ids.has(origin_id) and state.active_teleporter_ids.has(destination_id)


func perform_fast_travel_authoritative(origin_id: StringName, destination_id: StringName) -> bool:
	if not run_manager.run_active or is_transitioning:
		return false
	var origin: BiomeTeleporter = _find_teleporter(origin_id)
	var destination: BiomeTeleporter = _find_teleporter(destination_id)
	if origin == null or destination == null or not _valid_fast_travel_pair(origin_id, destination_id):
		return false
	var players: Array = get_players().filter(func(player: Node) -> bool: return player.visible and not player.is_downed and bool(run_manager.participants.get(player.participant_id, true)))
	for index in players.size():
		players[index].global_position = destination.arrival_position + Vector2((index * 2 - players.size() + 1) * COOP_SPAWN_OFFSET, 0)
		players[index].velocity = Vector2.ZERO
	gameplay_camera.position_smoothing_enabled = false
	gameplay_camera.global_position = destination.arrival_position
	get_tree().process_frame.connect(func() -> void: gameplay_camera.position_smoothing_enabled = true, CONNECT_ONE_SHOT)
	coop_waiting_changed.emit(false)
	var full_map := get_tree().get_first_node_in_group("full_map")
	if full_map != null:
		full_map.close_map(false)
	return true


func apply_network_fast_travel(destination_id: StringName) -> void:
	var full_map := get_tree().get_first_node_in_group("full_map")
	if full_map != null:
		full_map.close_map(false)
	var destination: BiomeTeleporter = _find_teleporter(destination_id)
	if destination == null:
		return
	gameplay_camera.position_smoothing_enabled = false
	gameplay_camera.global_position = destination.arrival_position
	get_tree().process_frame.connect(func() -> void: gameplay_camera.position_smoothing_enabled = true, CONNECT_ONE_SHOT)


func refresh_teleporter_states() -> void:
	var state: BiomeMapState = run_manager.get_current_map_state()
	for teleporter in get_tree().get_nodes_in_group("biome_teleporter"):
		teleporter.set_active(state.active_teleporter_ids.has(teleporter.teleporter_id))


func _find_teleporter(teleporter_id: StringName) -> BiomeTeleporter:
	for candidate in get_tree().get_nodes_in_group("biome_teleporter"):
		if candidate.teleporter_id == teleporter_id:
			return candidate as BiomeTeleporter
	return null


func _find_player(participant_id: StringName) -> Node:
	for player in get_players():
		if player.participant_id == participant_id:
			return player
	return null


func can_use_exit(exit: Area2D, interactor: Node2D) -> bool:
	if interactor == null or interactor.is_downed:
		return false
	if not run_manager.is_coop():
		return true
	for candidate in get_players():
		if candidate.is_downed or candidate.global_position.distance_to(exit.global_position) > EXIT_GROUP_DISTANCE:
			coop_waiting_changed.emit(true)
			return false
	coop_waiting_changed.emit(false)
	return true


func _create_players(coop: bool, joypad_device_id: int) -> void:
	_create_player_count(2 if coop else 1, joypad_device_id)


func _create_network_players(player_count: int) -> void:
	_create_player_count(clampi(player_count, 1, LanSession.MAX_PLAYERS), -1)


func _create_player_count(player_count: int, joypad_device_id: int) -> void:
	for candidate in get_players():
		candidate.queue_free()
	var created_players: Array[CharacterBody2D] = []
	var colors: Array[Color] = [Color.WHITE, Color(0.45, 0.8, 1.0), Color(1.0, 0.65, 0.35), Color(0.7, 0.5, 1.0)]
	for index in player_count:
		var player := PLAYER_SCENE.instantiate() as CharacterBody2D
		var slot := index + 1
		player.name = "Player" if slot == 1 else "Player%d" % slot
		player.participant_id = StringName("player_%d" % slot)
		player.input_profile = "p%d" % slot
		player.joypad_device_id = joypad_device_id if slot == 2 and player_count == 2 else -1
		add_child(player)
		player.anim.modulate = colors[index]
		for existing: CharacterBody2D in created_players:
			player.add_collision_exception_with(existing)
			existing.add_collision_exception_with(player)
		created_players.append(player)


func _position_players(entry_position: Vector2) -> void:
	var active_players := get_players()
	for index in active_players.size():
		var offset := (float(index) - float(active_players.size() - 1) * 0.5) * COOP_SPAWN_OFFSET * 2.0
		active_players[index].global_position = Vector2(clampf(entry_position.x + offset, 16.0, 1264.0), entry_position.y)
		active_players[index].velocity = Vector2.ZERO
		active_players[index].visible = true


func _position_players_in_hub(p1_position: Vector2, p2_position: Vector2) -> void:
	var players := get_players()
	for index in players.size():
		var candidate := players[index]
		var base_position: Vector2 = p1_position if index == 0 else p2_position
		candidate.global_position = base_position + Vector2(float(maxi(index - 1, 0)) * COOP_SPAWN_OFFSET * 2.0, 0.0)
		candidate.velocity = Vector2.ZERO
		candidate.visible = true


func _position_players_in_biome(start_position: Vector2) -> void:
	var active_players := get_players()
	for index in active_players.size():
		var offset := (float(index) - float(active_players.size() - 1) * 0.5) * COOP_SPAWN_OFFSET * 2.0
		active_players[index].global_position = start_position + Vector2(offset, 0.0)
		active_players[index].velocity = Vector2.ZERO
		active_players[index].visible = true


func _configure_camera_for_biome(bounds: Rect2, start_position: Vector2) -> void:
	gameplay_camera.position_smoothing_enabled = true
	gameplay_camera.position_smoothing_speed = 6.0
	gameplay_camera.limit_left = floori(bounds.position.x)
	gameplay_camera.limit_top = floori(bounds.position.y)
	gameplay_camera.limit_right = ceili(bounds.end.x)
	gameplay_camera.limit_bottom = ceili(bounds.end.y)
	gameplay_camera.global_position = start_position
	var base_zoom := clampf(local_settings.get_camera_zoom_base(), CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	gameplay_camera.zoom = Vector2.ONE * base_zoom


func _reset_camera_for_room() -> void:
	gameplay_camera.position_smoothing_enabled = false
	gameplay_camera.limit_left = 0
	gameplay_camera.limit_top = 0
	gameplay_camera.limit_right = 1280
	gameplay_camera.limit_bottom = 720
	gameplay_camera.global_position = Vector2(640.0, 360.0)
	gameplay_camera.zoom = Vector2.ONE


func _set_all_player_input(enabled: bool) -> void:
	if not enabled:
		var choice_ui := get_tree().get_first_node_in_group("attribute_choice_ui")
		if choice_ui:
			choice_ui.cancel_selection()
	for candidate in get_players():
		candidate.set_input_enabled(enabled)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	if not mode_selected or not run_manager.is_coop():
		return
	var connected := Input.get_connected_joypads()
	if connected.has(run_manager.p2_joypad_device_id) or connected.is_empty():
		run_manager.state_changed.emit()
		return
	var new_device: int = connected[0]
	run_manager.p2_joypad_device_id = new_device
	run_manager.p2_joypad_name = Input.get_joy_name(new_device)
	for candidate in get_players():
		if candidate.input_profile == "p2":
			candidate.joypad_device_id = new_device
			LocalCoopInput.ensure_player_two_actions(new_device)
	run_manager.state_changed.emit()


func _first_connected_joypad() -> int:
	var connected := Input.get_connected_joypads()
	return connected[0] if not connected.is_empty() else -1


func _add_room_safety(room: Node2D) -> void:
	var boundaries := StaticBody2D.new()
	boundaries.name = "RoomBoundaries"
	room.add_child(boundaries)
	_add_boundary_shape(boundaries, Vector2(-BOUNDARY_THICKNESS * 0.5, ROOM_BOUNDS.size.y * 0.5), Vector2(BOUNDARY_THICKNESS, ROOM_BOUNDS.size.y + BOUNDARY_THICKNESS * 2.0))
	_add_boundary_shape(boundaries, Vector2(ROOM_BOUNDS.size.x + BOUNDARY_THICKNESS * 0.5, ROOM_BOUNDS.size.y * 0.5), Vector2(BOUNDARY_THICKNESS, ROOM_BOUNDS.size.y + BOUNDARY_THICKNESS * 2.0))
	var kill_zone := Area2D.new()
	kill_zone.name = "FallKillZone"
	kill_zone.collision_layer = 0
	kill_zone.collision_mask = 1
	var kill_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(ROOM_BOUNDS.size.x + BOUNDARY_THICKNESS * 2.0, 80.0)
	kill_shape.shape = rectangle
	kill_shape.position = Vector2(ROOM_BOUNDS.size.x * 0.5, ROOM_BOUNDS.end.y + 100.0)
	kill_zone.add_child(kill_shape)
	kill_zone.body_entered.connect(_on_fall_kill_zone_body_entered)
	room.add_child(kill_zone)
	for title_name in [&"Title", &"RoomLabel"]:
		var world_title := room.get_node_or_null(NodePath(String(title_name))) as CanvasItem
		if world_title:
			world_title.visible = false


func _add_boundary_shape(body: StaticBody2D, position: Vector2, size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	collision.position = position
	body.add_child(collision)


func _on_fall_kill_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("enter_downed"):
		body.enter_downed()


func _find_entry_point(room: Node, entry_id: StringName) -> Marker2D:
	for node in get_tree().get_nodes_in_group("room_entry"):
		if room.is_ancestor_of(node) and node.name == entry_id:
			return node as Marker2D
	return null


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_rect, "modulate:a", alpha, fade_duration)
	await tween.finished
