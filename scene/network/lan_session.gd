class_name LanSession
extends Node

const NETWORK_PROJECTILE_SCENE := preload("res://entities/ranged_projectile.tscn")
const BANDAGE_PICKUP_SCRIPT := preload("res://scene/interactables/bandage_pickup.gd")

signal lobby_changed
signal discovered_rooms_changed
signal connection_message_changed(message: String)

enum Role { OFFLINE, HOST, CLIENT }

const GAME_PORT := 27840
const DISCOVERY_PORT := 27841
const PROTOCOL_VERSION := 3
const MAX_PLAYERS := 4
const DISCOVERY_INTERVAL := 0.75
const ROOM_EXPIRY := 2.5
const SNAPSHOT_INTERVAL := 0.05
const INPUT_ACTIONS := [&"left", &"right", &"down", &"jump", &"attack", &"attack_slot_1", &"attack_slot_2", &"dash", &"interact", &"heal", &"switch_weapon"]

var role: Role = Role.OFFLINE
var room_name := "Cyberfield LAN"
var connection_message := ""
var connected_peer_id := 0
var connected_peer_ids: Array[int] = []
var local_participant_id: StringName = &"player_1"
var _peer_participants: Dictionary = {}
var session_player_count := 1
var discovered_rooms: Array[Dictionary] = []
var _peer: ENetMultiplayerPeer
var _discovery_sender: PacketPeerUDP
var _discovery_senders: Array[Dictionary] = []
var _discovery_listener: PacketPeerUDP
var _discovery_elapsed := 0.0
var _snapshot_elapsed := 0.0
var _remote_input_state: Dictionary = {}
var _room_last_seen: Dictionary = {}
var _last_sent_input: Dictionary = {}
var _input_keepalive_elapsed := 0.0
var _input_sequence := 0
var _pulse_release_deadlines: Dictionary = {}
var _last_action_sequences: Dictionary = {}
var _pending_attribute_choices: Dictionary = {}
var _client_attribute_chest_id: StringName = &""
var _next_projectile_id := 1
var _client_projectiles: Dictionary = {}
var _reported_layout_mismatch := false
var last_discovery_sent := "NUNCA"
var last_discovery_received := "NUNCA"
var discovery_interfaces: Array[String] = []


func _ready() -> void:
	add_to_group("lan_session")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	call_deferred("_connect_attribute_ui")
	set_process(true)


func _connect_attribute_ui() -> void:
	var attribute_ui := get_tree().get_first_node_in_group("attribute_choice_ui")
	if attribute_ui != null and not attribute_ui.network_choice_submitted.is_connected(_on_client_attribute_choice):
		attribute_ui.network_choice_submitted.connect(_on_client_attribute_choice)


func _process(delta: float) -> void:
	_release_finished_action_pulses()
	_process_discovery(delta)
	if role == Role.CLIENT and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_input_keepalive_elapsed += delta
		_send_local_input()
	elif role == Role.HOST and not connected_peer_ids.is_empty():
		_snapshot_elapsed += delta
		if _snapshot_elapsed >= SNAPSHOT_INTERVAL:
			_snapshot_elapsed = 0.0
			_broadcast_authoritative_snapshot()


func host_room(requested_name: String = "Cyberfield LAN") -> Error:
	shutdown()
	room_name = requested_name.strip_edges() if not requested_name.strip_edges().is_empty() else "Cyberfield LAN"
	_peer = ENetMultiplayerPeer.new()
	var result := _peer.create_server(GAME_PORT, MAX_PLAYERS - 1)
	if result != OK:
		_set_message("Não foi possível abrir a sala (erro %d)." % result)
		return result
	multiplayer.multiplayer_peer = _peer
	role = Role.HOST
	_configure_discovery_senders()
	_set_message("Sala aberta em %s:%d" % [get_preferred_lan_address(), GAME_PORT])
	lobby_changed.emit()
	return OK


func search_rooms() -> Error:
	stop_discovery()
	_discovery_listener = PacketPeerUDP.new()
	var result := _discovery_listener.bind(DISCOVERY_PORT, "*")
	if result != OK:
		_set_message("Discovery LAN indisponível (erro %d). Use ENTRAR POR IP." % result)
		return result
	_discovery_listener.set_broadcast_enabled(true)
	_set_message("Procurando salas na rede local…")
	discovered_rooms_changed.emit()
	return OK


func join_room(address: String, port: int = GAME_PORT) -> Error:
	var normalized_address := address.strip_edges()
	if normalized_address.is_empty():
		_set_message("Informe o IP do host.")
		return ERR_INVALID_PARAMETER
	shutdown()
	_peer = ENetMultiplayerPeer.new()
	var result := _peer.create_client(normalized_address, port)
	if result != OK:
		_set_message("Não foi possível iniciar a conexão (erro %d)." % result)
		return result
	multiplayer.multiplayer_peer = _peer
	role = Role.CLIENT
	_set_message("Conectando a %s:%d…" % [normalized_address, port])
	lobby_changed.emit()
	return OK


func start_host_run(difficulty: StringName) -> void:
	if role != Role.HOST:
		return
	stop_discovery()
	var meta := get_tree().get_first_node_in_group("meta_progression") as MetaProgression
	var serialized_weapon_pool: Array[String] = []
	if meta != null:
		for weapon_id: StringName in meta.get_run_weapon_pool():
			serialized_weapon_pool.append(String(weapon_id))
	var config := {
		"protocol": PROTOCOL_VERSION,
		"seed": 0,
		"difficulty": String(difficulty),
		"biome_id": "lower_city",
		"player_count": get_player_count(),
		"weapon_pool": serialized_weapon_pool,
	}
	for peer_id: int in connected_peer_ids:
		var peer_config: Dictionary = config.duplicate()
		peer_config["local_participant_id"] = String(get_participant_for_peer(peer_id))
		_receive_run_config.rpc_id(peer_id, peer_config)
	_start_network_hub(config)


func broadcast_run_start(config: Dictionary) -> void:
	if role != Role.HOST:
		return
	for peer_id: int in connected_peer_ids:
		_receive_run_start.rpc_id(peer_id, config)


func broadcast_stage_transition(exit_id: StringName, destination_id: StringName, stage_seed: int) -> void:
	_reported_layout_mismatch = false
	if role == Role.HOST:
		for peer_id: int in connected_peer_ids:
			_receive_stage_transition.rpc_id(peer_id, String(exit_id), String(destination_id), stage_seed)


func request_remote_attribute_choice(participant_id: StringName, chest_id: StringName, options: Array[StringName]) -> void:
	var peer_id := get_peer_for_participant(participant_id)
	if role != Role.HOST or peer_id <= 0 or chest_id.is_empty() or options.is_empty():
		return
	_pending_attribute_choices[peer_id] = {"chest_id": chest_id, "options": options.duplicate()}
	var serialized_options: Array[String] = []
	for option in options:
		serialized_options.append(String(option))
	_show_remote_attribute_choice.rpc_id(peer_id, String(chest_id), serialized_options)


func replicate_projectile_spawn(origin: Vector2, direction: Vector2, speed: float, damage: int, target_group: StringName = &"player") -> int:
	if role != Role.HOST:
		return 0
	var projectile_id := _next_projectile_id
	_next_projectile_id += 1
	for peer_id: int in connected_peer_ids:
		_spawn_network_projectile.rpc_id(peer_id, projectile_id, origin, direction, speed, damage, String(target_group))
	return projectile_id


func replicate_projectile_despawn(projectile_id: int) -> void:
	if role == Role.HOST and projectile_id > 0:
		for peer_id: int in connected_peer_ids:
			_despawn_network_projectile.rpc_id(peer_id, projectile_id)


func shutdown() -> void:
	role = Role.OFFLINE
	_release_remote_inputs()
	stop_discovery()
	if _peer != null:
		_peer.close()
	_peer = null
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected_peer_id = 0
	connected_peer_ids.clear()
	local_participant_id = &"player_1"
	_peer_participants.clear()
	session_player_count = 1
	_snapshot_elapsed = 0.0
	_input_keepalive_elapsed = 0.0
	_last_sent_input.clear()
	_pulse_release_deadlines.clear()
	_last_action_sequences.clear()
	_pending_attribute_choices.clear()
	_client_attribute_chest_id = &""
	for projectile_value: Variant in _client_projectiles.values():
		var projectile := projectile_value as Node
		if is_instance_valid(projectile):
			projectile.queue_free()
	_client_projectiles.clear()
	_next_projectile_id = 1
	_reported_layout_mismatch = false
	connection_message = ""
	lobby_changed.emit()


func stop_discovery() -> void:
	if _discovery_listener != null:
		_discovery_listener.close()
	_discovery_listener = null
	_discovery_sender = null
	for sender_data: Dictionary in _discovery_senders:
		var sender := sender_data.get("peer") as PacketPeerUDP
		if sender != null:
			sender.close()
	_discovery_senders.clear()
	_discovery_elapsed = 0.0


func is_network_game() -> bool:
	return role != Role.OFFLINE


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


func request_map_discovery(module_id: StringName) -> void:
	if role == Role.CLIENT:
		_request_map_discovery.rpc_id(1, String(module_id))


func request_teleporter_activation(teleporter_id: StringName) -> void:
	if role == Role.CLIENT:
		_request_teleporter_activation.rpc_id(1, String(teleporter_id))


func request_remote_teleporter_menu(participant_id: StringName, origin_id: StringName) -> void:
	var peer_id := get_peer_for_participant(participant_id)
	if role == Role.HOST and peer_id > 0 and not origin_id.is_empty():
		_open_remote_teleporter_menu.rpc_id(peer_id, String(origin_id))


func request_fast_travel(origin_id: StringName, destination_id: StringName) -> void:
	if role == Role.CLIENT:
		_request_fast_travel.rpc_id(1, String(origin_id), String(destination_id))


func cancel_fast_travel_confirmation() -> void:
	if role == Role.CLIENT:
		_cancel_fast_travel_confirmation.rpc_id(1)
	elif role == Role.HOST:
		var room_manager := get_tree().get_first_node_in_group("room_manager")
		if room_manager != null:
			room_manager.cancel_fast_travel_confirmation(local_participant_id)


func broadcast_fast_travel_vote(origin_id: StringName, destination_id: StringName, confirmed_ids: Array[StringName], active_ids: Array[StringName]) -> void:
	if role != Role.HOST:
		return
	var confirmed: Array[String] = []
	var active: Array[String] = []
	for participant_id in confirmed_ids:
		confirmed.append(String(participant_id))
	for participant_id in active_ids:
		active.append(String(participant_id))
	for peer_id: int in connected_peer_ids:
		_receive_fast_travel_vote.rpc_id(peer_id, String(origin_id), String(destination_id), confirmed, active)


func broadcast_fast_travel_applied(destination_id: StringName) -> void:
	if role != Role.HOST:
		return
	for peer_id: int in connected_peer_ids:
		_apply_fast_travel.rpc_id(peer_id, String(destination_id))


func request_return_to_laboratory() -> void:
	if role == Role.CLIENT:
		_request_return_to_laboratory.rpc_id(1)


func open_meta_terminal_for(participant_id: StringName) -> void:
	if role != Role.HOST:
		return
	var peer_id := get_peer_for_participant(participant_id)
	if peer_id > 0:
		_open_meta_terminal.rpc_id(peer_id)


func broadcast_return_to_laboratory() -> void:
	if role != Role.HOST:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var results: Dictionary = room_manager.run_manager.last_run_results.duplicate(true) if room_manager != null else {}
	for peer_id: int in connected_peer_ids:
		_apply_return_to_laboratory.rpc_id(peer_id, results)


func request_weapon_pickup(pickup_id: StringName) -> void:
	if role == Role.CLIENT:
		_request_weapon_pickup.rpc_id(1, String(pickup_id))


func request_bandage_pickup(pickup_id: StringName) -> void:
	if role == Role.CLIENT:
		_request_bandage_pickup.rpc_id(1, String(pickup_id))


func get_player_count() -> int:
	if role == Role.HOST:
		return 1 + connected_peer_ids.size()
	if role == Role.CLIENT and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return session_player_count
	return 0


func get_local_participant_id() -> StringName:
	return local_participant_id


func get_participant_for_peer(peer_id: int) -> StringName:
	return StringName(_peer_participants.get(peer_id, &""))


func get_peer_for_participant(participant_id: StringName) -> int:
	for peer_value: Variant in _peer_participants:
		var peer_id := int(peer_value)
		if StringName(_peer_participants[peer_id]) == participant_id:
			return peer_id
	return 0


func get_role_label() -> String:
	match role:
		Role.HOST:
			return "HOST"
		Role.CLIENT:
			return "CLIENT"
		_:
			return "OFFLINE"


func get_preferred_lan_address() -> String:
	var fallback_address := "127.0.0.1"
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if fallback_address == "127.0.0.1":
			fallback_address = address
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return fallback_address


func get_discovery_diagnostics() -> String:
	return "IP %s // ENET %d // UDP %d\nIFACES %s\nENVIO %s // RECEBIDO %s" % [get_preferred_lan_address(), GAME_PORT, DISCOVERY_PORT, ", ".join(discovery_interfaces), last_discovery_sent, last_discovery_received]


func _configure_discovery_senders() -> void:
	_discovery_senders.clear()
	discovery_interfaces.clear()
	for address_value: Variant in IP.get_local_addresses():
		var address := String(address_value)
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		var octets := address.split(".")
		if octets.size() != 4:
			continue
		var sender := PacketPeerUDP.new()
		var bind_result := sender.bind(0, address)
		if bind_result != OK:
			continue
		sender.set_broadcast_enabled(true)
		var directed_broadcast := "%s.%s.%s.255" % [octets[0], octets[1], octets[2]]
		_discovery_senders.append({"peer": sender, "address": address, "broadcasts": [directed_broadcast, "255.255.255.255"]})
		discovery_interfaces.append("%s→%s/255.255.255.255" % [address, directed_broadcast])
	if _discovery_senders.is_empty():
		var fallback := PacketPeerUDP.new()
		fallback.set_broadcast_enabled(true)
		_discovery_senders.append({"peer": fallback, "address": "*", "broadcasts": ["255.255.255.255"]})
		discovery_interfaces.append("*→255.255.255.255")


func _process_discovery(delta: float) -> void:
	if role == Role.HOST and not _discovery_senders.is_empty():
		_discovery_elapsed += delta
		if _discovery_elapsed >= DISCOVERY_INTERVAL:
			_discovery_elapsed = 0.0
			var announcement := {
				"protocol": PROTOCOL_VERSION,
				"name": room_name,
				"port": GAME_PORT,
				"players": get_player_count(),
			}
			var payload := JSON.stringify(announcement).to_utf8_buffer()
			for sender_data: Dictionary in _discovery_senders:
				var sender := sender_data.peer as PacketPeerUDP
				for broadcast_value: Variant in sender_data.broadcasts:
					sender.set_dest_address(String(broadcast_value), DISCOVERY_PORT)
					sender.put_packet(payload)
			last_discovery_sent = "%s @ %d" % [Time.get_time_string_from_system(), DISCOVERY_PORT]
	if _discovery_listener == null:
		return
	while _discovery_listener.get_available_packet_count() > 0:
		var packet := _discovery_listener.get_packet()
		var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if not parsed is Dictionary:
			continue
		var data: Dictionary = parsed as Dictionary
		if int(data.get("protocol", -1)) != PROTOCOL_VERSION:
			continue
		var host_address := _discovery_listener.get_packet_ip()
		last_discovery_received = "%s @ %s" % [Time.get_time_string_from_system(), host_address]
		var key := "%s:%d" % [host_address, int(data.get("port", GAME_PORT))]
		data["address"] = host_address
		data["last_seen"] = Time.get_ticks_msec() / 1000.0
		_room_last_seen[key] = data
	_prune_discovered_rooms()


func _prune_discovered_rooms() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var changed := false
	for key_value: Variant in _room_last_seen.keys():
		var key := String(key_value)
		var room: Dictionary = _room_last_seen[key] as Dictionary
		if now - float(room.get("last_seen", 0.0)) > ROOM_EXPIRY:
			_room_last_seen.erase(key)
			changed = true
	var next_rooms: Array[Dictionary] = []
	for room_value: Variant in _room_last_seen.values():
		next_rooms.append((room_value as Dictionary).duplicate())
	next_rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name) < String(b.name))
	if changed or next_rooms != discovered_rooms:
		discovered_rooms = next_rooms
		discovered_rooms_changed.emit()


func _send_local_input() -> void:
	for action: StringName in INPUT_ACTIONS:
		if action not in [&"left", &"right"] and Input.is_action_just_pressed(action):
			_submit_action_pulse.rpc_id(1, String(action), _input_sequence)
	var state := {
		"left": Input.get_action_strength(&"left"),
		"right": Input.get_action_strength(&"right"),
		"down": Input.is_action_pressed(&"down"),
		"jump": Input.is_action_pressed(&"jump"),
		"attack": Input.is_action_pressed(&"attack"),
		"attack_slot_1": Input.is_action_pressed(&"attack_slot_1"),
		"attack_slot_2": Input.is_action_pressed(&"attack_slot_2"),
		"dash": Input.is_action_pressed(&"dash"),
		"interact": Input.is_action_pressed(&"interact"),
		"heal": Input.is_action_pressed(&"heal"),
		"switch_weapon": Input.is_action_pressed(&"switch_weapon"),
		"sequence": _input_sequence,
	}
	var comparable_state: Dictionary = state.duplicate()
	comparable_state.erase("sequence")
	if comparable_state == _last_sent_input and _input_keepalive_elapsed < 0.10:
		return
	_input_sequence += 1
	state.sequence = _input_sequence
	_last_sent_input = comparable_state
	_input_keepalive_elapsed = 0.0
	_submit_client_input.rpc_id(1, state)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_client_input(state: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var participant_id := get_participant_for_peer(sender_id)
	if role != Role.HOST or participant_id.is_empty():
		return
	_apply_remote_input(participant_id, state)


@rpc("any_peer", "call_remote", "reliable", 1)
func _submit_action_pulse(action_name: String, sequence: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var participant_id := get_participant_for_peer(sender_id)
	if role != Role.HOST or participant_id.is_empty():
		return
	var base_action := StringName(action_name)
	if not INPUT_ACTIONS.has(base_action) or base_action in [&"left", &"right"]:
		return
	var sequence_key := "%d:%s" % [sender_id, action_name]
	if sequence <= int(_last_action_sequences.get(sequence_key, -1)):
		return
	_last_action_sequences[sequence_key] = sequence
	var remote_action := _remote_action(participant_id, base_action)
	Input.action_press(remote_action)
	_pulse_release_deadlines[remote_action] = Time.get_ticks_msec() + 90


func _release_finished_action_pulses() -> void:
	if _pulse_release_deadlines.is_empty():
		return
	var now := Time.get_ticks_msec()
	for action_value: Variant in _pulse_release_deadlines.keys():
		var remote_action := StringName(action_value)
		if now < int(_pulse_release_deadlines.get(remote_action, now)):
			continue
		var parts := String(remote_action).split("_", true, 1)
		var participant_id := StringName("player_%s" % parts[0].trim_prefix("p")) if parts.size() == 2 else &""
		var base_action := StringName(parts[1]) if parts.size() == 2 else &""
		var participant_state: Dictionary = _remote_input_state.get(participant_id, {}) as Dictionary
		if not bool(participant_state.get(base_action, false)):
			Input.action_release(remote_action)
		_pulse_release_deadlines.erase(remote_action)


func _apply_remote_input(participant_id: StringName, state: Dictionary) -> void:
	var participant_state: Dictionary = _remote_input_state.get(participant_id, {}) as Dictionary
	for base_action in INPUT_ACTIONS:
		var remote_action := _remote_action(participant_id, base_action)
		var pressed := false
		var strength := 1.0
		if base_action == &"left" or base_action == &"right":
			strength = clampf(float(state.get(String(base_action), 0.0)), 0.0, 1.0)
			pressed = strength > 0.0
		else:
			pressed = bool(state.get(String(base_action), false))
		var was_pressed := bool(participant_state.get(base_action, false))
		if pressed:
			Input.action_press(remote_action, strength)
		elif was_pressed:
			Input.action_release(remote_action)
		participant_state[base_action] = pressed
	_remote_input_state[participant_id] = participant_state


func _release_remote_inputs() -> void:
	for participant_value: Variant in _remote_input_state:
		var participant_id := StringName(participant_value)
		for base_action in INPUT_ACTIONS:
			Input.action_release(_remote_action(participant_id, base_action))
	_remote_input_state.clear()


func _release_remote_player_inputs(participant_id: StringName) -> void:
	for base_action in INPUT_ACTIONS:
		Input.action_release(_remote_action(participant_id, base_action))
	_remote_input_state.erase(participant_id)


func _remote_action(participant_id: StringName, base_action: StringName) -> StringName:
	var profile := String(participant_id).replace("player_", "p")
	LocalCoopInput.ensure_network_player_actions(StringName(profile))
	return StringName("%s_%s" % [profile, base_action])


func _broadcast_authoritative_snapshot() -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or not room_manager.mode_selected:
		return
	var players: Array[Dictionary] = []
	for player in room_manager.get_players():
		players.append(player.get_network_state())
	var enemies: Array[Dictionary] = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("get_network_state"):
			enemies.append(enemy.get_network_state())
	var bandages: Array[Dictionary] = []
	for pickup in get_tree().get_nodes_in_group("bandage_pickup"):
		bandages.append({"pickup_id": String(pickup.pickup_id), "room_id": String(pickup.room_id), "position": pickup.global_position})
	var layout_signature := ""
	if room_manager.current_room != null and room_manager.current_room.has_method("get_generation_report"):
		var generation_report: Dictionary = room_manager.current_room.get_generation_report()
		layout_signature = String(generation_report.get("signature", ""))
	var snapshot := {
		"players": players,
		"enemies": enemies,
		"bandages": bandages,
		"dirty_money": int(room_manager.run_manager.dirty_money),
		"selected_exit_id": String(room_manager.run_manager.selected_exit_id),
		"stage_index": int(room_manager.run_manager.stage_index),
		"collected_loot": room_manager.run_manager.collected_biome_loot.keys(),
		"run_active": bool(room_manager.run_manager.run_active),
		"run_lost": bool(room_manager.run_manager.run_is_lost),
		"run_completed": bool(room_manager.run_manager.run_is_completed),
		"layout_signature": layout_signature,
		"map_state": room_manager.run_manager.serialize_current_map_state(),
		"run_elapsed_time": room_manager.run_manager.run_elapsed_time,
		"run_results": room_manager.run_manager.last_run_results.duplicate(true),
	}
	for peer_id: int in connected_peer_ids:
		_apply_authoritative_snapshot.rpc_id(peer_id, snapshot)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _apply_authoritative_snapshot(snapshot: Dictionary) -> void:
	if role != Role.CLIENT:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null:
		return
	var players_by_id: Dictionary = {}
	for player in room_manager.get_players():
		players_by_id[player.participant_id] = player
	var authoritative_player_ids: Dictionary = {}
	var player_states: Array = snapshot.get("players", []) as Array
	for state_value: Variant in player_states:
		var state: Dictionary = state_value as Dictionary
		var participant_id := StringName(state.get("participant_id", &""))
		authoritative_player_ids[participant_id] = true
		if players_by_id.has(participant_id):
			var predicted_local := participant_id == local_participant_id
			players_by_id[participant_id].apply_network_state(state, predicted_local)
	for participant_value: Variant in players_by_id:
		var participant_id := StringName(participant_value)
		if not authoritative_player_ids.has(participant_id):
			(players_by_id[participant_id] as Node).queue_free()
	var enemies_by_id: Dictionary = {}
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemies_by_id[enemy.persistent_id] = enemy
	var authoritative_enemy_ids: Dictionary = {}
	var enemy_states: Array = snapshot.get("enemies", []) as Array
	for state_value: Variant in enemy_states:
		var state: Dictionary = state_value as Dictionary
		var enemy_id := StringName(state.get("persistent_id", &""))
		authoritative_enemy_ids[enemy_id] = true
		if enemies_by_id.has(enemy_id) and enemies_by_id[enemy_id].has_method("apply_network_state"):
			enemies_by_id[enemy_id].apply_network_state(state)
	for enemy_id_value: Variant in enemies_by_id.keys():
		var enemy_id := StringName(enemy_id_value)
		if not authoritative_enemy_ids.has(enemy_id):
			enemies_by_id[enemy_id].queue_free()
	var local_bandages := {}
	for pickup in get_tree().get_nodes_in_group("bandage_pickup"):
		local_bandages[pickup.pickup_id] = pickup
	var authoritative_bandages := {}
	for data_value: Variant in snapshot.get("bandages", []):
		var data := data_value as Dictionary
		var pickup_id := StringName(data.pickup_id)
		authoritative_bandages[pickup_id] = true
		if not local_bandages.has(pickup_id) and room_manager.current_room != null:
			var pickup := BANDAGE_PICKUP_SCRIPT.new() as BandagePickup
			pickup.pickup_id = pickup_id
			pickup.room_id = StringName(data.room_id)
			room_manager.current_room.add_child(pickup)
			pickup.global_position = Vector2(data.position)
	for pickup_id in local_bandages:
		if not authoritative_bandages.has(pickup_id):
			local_bandages[pickup_id].queue_free()
	var collected_loot: Array = snapshot.get("collected_loot", []) as Array
	for loot in get_tree().get_nodes_in_group("biome_loot"):
		if collected_loot.has(loot.loot_id):
			loot.queue_free()
	room_manager.run_manager.dirty_money = int(snapshot.get("dirty_money", room_manager.run_manager.dirty_money))
	room_manager.run_manager.apply_network_map_state(snapshot.get("map_state", {}))
	room_manager.run_manager.run_elapsed_time = float(snapshot.get("run_elapsed_time", room_manager.run_manager.run_elapsed_time))
	var map_state: BiomeMapState = room_manager.run_manager.get_current_map_state()
	for pickup in get_tree().get_nodes_in_group("weapon_pickup"):
		if map_state.collected_weapon_ids.has(pickup.pickup_id):
			pickup.queue_free()
	room_manager.refresh_teleporter_states()
	var authoritative_signature := String(snapshot.get("layout_signature", ""))
	if not authoritative_signature.is_empty() and room_manager.current_room != null and room_manager.current_room.has_method("get_generation_report"):
		var local_report: Dictionary = room_manager.current_room.get_generation_report()
		var local_signature := String(local_report.get("signature", ""))
		if local_signature != authoritative_signature and not _reported_layout_mismatch:
			_reported_layout_mismatch = true
			push_error("LAN layout mismatch: host=%s client=%s" % [authoritative_signature, local_signature])
	if bool(snapshot.get("run_lost", false)) and room_manager.run_manager.run_active:
		room_manager.run_manager.apply_network_loss()
	elif bool(snapshot.get("run_completed", false)) and not room_manager.run_manager.run_is_completed:
		room_manager.run_manager.apply_network_completion(snapshot.get("run_results", {}) as Dictionary)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_run_config(config: Dictionary) -> void:
	if role != Role.CLIENT or int(config.get("protocol", -1)) != PROTOCOL_VERSION:
		return
	local_participant_id = StringName(config.get("local_participant_id", local_participant_id))
	session_player_count = clampi(int(config.get("player_count", 2)), 1, MAX_PLAYERS)
	_start_network_hub(config)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_run_start(config: Dictionary) -> void:
	if role != Role.CLIENT or int(config.get("protocol", -1)) != PROTOCOL_VERSION:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.apply_lan_run_start(config)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_stage_transition(exit_id: String, destination_id: String, stage_seed: int) -> void:
	if role != Role.CLIENT:
		return
	_reported_layout_mismatch = false
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.apply_lan_stage_transition(StringName(exit_id), StringName(destination_id), stage_seed)


@rpc("authority", "call_remote", "reliable", 0)
func _show_remote_attribute_choice(chest_id: String, serialized_options: Array[String]) -> void:
	if role != Role.CLIENT:
		return
	var options: Array[StringName] = []
	for option in serialized_options:
		options.append(StringName(option))
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var attribute_ui := get_tree().get_first_node_in_group("attribute_choice_ui")
	if room_manager == null or attribute_ui == null:
		return
	for player in room_manager.get_players():
		if player.participant_id == local_participant_id:
			_client_attribute_chest_id = StringName(chest_id)
			attribute_ui.open_network_for(player, options)
			return


@rpc("authority", "call_remote", "reliable", 3)
func _spawn_network_projectile(projectile_id: int, origin: Vector2, direction: Vector2, speed: float, damage: int, target_group: String = "player") -> void:
	if role != Role.CLIENT or _client_projectiles.has(projectile_id):
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or room_manager.current_room == null:
		return
	var projectile := NETWORK_PROJECTILE_SCENE.instantiate()
	projectile.network_id = projectile_id
	projectile.network_visual_only = true
	room_manager.current_room.add_child(projectile)
	projectile.setup(origin, direction, null, speed, damage, StringName(target_group))
	_client_projectiles[projectile_id] = projectile


@rpc("authority", "call_remote", "reliable", 3)
func _despawn_network_projectile(projectile_id: int) -> void:
	if role != Role.CLIENT or not _client_projectiles.has(projectile_id):
		return
	var projectile := _client_projectiles[projectile_id] as Node
	if is_instance_valid(projectile):
		projectile.queue_free()
	_client_projectiles.erase(projectile_id)


func _on_client_attribute_choice(attribute: StringName) -> void:
	if role != Role.CLIENT or _client_attribute_chest_id.is_empty():
		return
	_submit_remote_attribute_choice.rpc_id(1, String(_client_attribute_chest_id), String(attribute))
	_client_attribute_chest_id = &""


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_remote_attribute_choice(chest_id: String, attribute: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var participant_id := get_participant_for_peer(sender_id)
	if role != Role.HOST or participant_id.is_empty():
		return
	var requested_chest_id := StringName(chest_id)
	var requested_attribute := StringName(attribute)
	var pending: Dictionary = _pending_attribute_choices.get(sender_id, {}) as Dictionary
	var pending_options: Array = pending.get("options", []) as Array
	if requested_chest_id != StringName(pending.get("chest_id", &"")) or not pending_options.has(requested_attribute):
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null:
		return
	var remote_player: Node = room_manager._find_player(participant_id)
	if remote_player == null:
		return
	for interactable in get_tree().get_nodes_in_group("interactable"):
		if interactable.has_method("apply_choice") and StringName(interactable.get("chest_id")) == requested_chest_id:
			interactable.apply_choice(remote_player, requested_attribute)
			_pending_attribute_choices.erase(sender_id)
			return


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_map_discovery(module_id: String) -> void:
	var participant_id := get_participant_for_peer(multiplayer.get_remote_sender_id())
	if role != Role.HOST or participant_id.is_empty():
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or room_manager.current_room == null:
		return
	var remote_player: Node = room_manager._find_player(participant_id)
	var module_index := int(room_manager.current_room.get_module_index_at(remote_player.global_position)) if remote_player != null else -1
	var graph: Dictionary = room_manager.current_room.get_map_graph()
	var modules: Array = graph.get("modules", []) as Array
	if module_index < 0 or module_index >= modules.size() or StringName((modules[module_index] as Dictionary).instance_id) != StringName(module_id):
		return
	var neighbors: Array[StringName] = []
	for neighbor_value: Variant in (modules[module_index] as Dictionary).neighbors:
		neighbors.append(StringName((modules[int(neighbor_value)] as Dictionary).instance_id))
	room_manager.run_manager.discover_map_module(StringName(module_id), neighbors)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_teleporter_activation(teleporter_id: String) -> void:
	var participant_id := get_participant_for_peer(multiplayer.get_remote_sender_id())
	if role != Role.HOST or participant_id.is_empty():
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.activate_teleporter_authoritative(StringName(teleporter_id), participant_id)


@rpc("authority", "call_remote", "reliable", 0)
func _open_remote_teleporter_menu(origin_id: String) -> void:
	if role != Role.CLIENT or origin_id.is_empty():
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.open_local_teleporter_menu(StringName(origin_id))


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_weapon_pickup(pickup_id: String) -> void:
	var participant_id := get_participant_for_peer(multiplayer.get_remote_sender_id())
	if role != Role.HOST or participant_id.is_empty():
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null:
		return
	var remote_player: Node = room_manager._find_player(participant_id)
	if remote_player == null:
		return
	for pickup in get_tree().get_nodes_in_group("weapon_pickup"):
		if StringName(pickup.pickup_id) == StringName(pickup_id):
			pickup.claim_authoritative(remote_player)
			return


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_bandage_pickup(pickup_id: String) -> void:
	var participant_id := get_participant_for_peer(multiplayer.get_remote_sender_id())
	if role != Role.HOST or participant_id.is_empty():
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null:
		return
	var remote_player: Node = room_manager._find_player(participant_id)
	for pickup in get_tree().get_nodes_in_group("bandage_pickup"):
		if StringName(pickup.pickup_id) == StringName(pickup_id) and remote_player != null and remote_player.global_position.distance_to(pickup.global_position) <= 100.0:
			pickup.claim_authoritative(remote_player)
			return


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_fast_travel(origin_id: String, destination_id: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var participant_id := get_participant_for_peer(sender_id)
	if role != Role.HOST or participant_id.is_empty():
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.submit_fast_travel_confirmation(participant_id, StringName(origin_id), StringName(destination_id))


@rpc("any_peer", "call_remote", "reliable", 0)
func _cancel_fast_travel_confirmation() -> void:
	var participant_id := get_participant_for_peer(multiplayer.get_remote_sender_id())
	if role != Role.HOST or participant_id.is_empty():
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.cancel_fast_travel_confirmation(participant_id)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_fast_travel_vote(origin_id: String, destination_id: String, confirmed: Array[String], active: Array[String]) -> void:
	if role != Role.CLIENT:
		return
	var confirmed_ids: Array[StringName] = []
	var active_ids: Array[StringName] = []
	for participant_id in confirmed:
		confirmed_ids.append(StringName(participant_id))
	for participant_id in active:
		active_ids.append(StringName(participant_id))
	var full_map := get_tree().get_first_node_in_group("full_map")
	if full_map == null:
		return
	if origin_id.is_empty() or not active_ids.has(local_participant_id):
		full_map.clear_fast_travel_vote()
	else:
		full_map.apply_fast_travel_vote(StringName(origin_id), StringName(destination_id), confirmed_ids, active_ids)


@rpc("authority", "call_remote", "reliable", 0)
func _apply_fast_travel(destination_id: String) -> void:
	if role != Role.CLIENT:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.apply_network_fast_travel(StringName(destination_id))


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_return_to_laboratory() -> void:
	if role != Role.HOST or get_participant_for_peer(multiplayer.get_remote_sender_id()).is_empty():
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null and not room_manager.run_manager.run_active:
		room_manager.call_deferred("return_to_laboratory")


@rpc("authority", "call_remote", "reliable", 0)
func _apply_return_to_laboratory(results: Dictionary) -> void:
	if role != Role.CLIENT:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		if not results.is_empty():
			room_manager.run_manager.last_run_results = results.duplicate(true)
		room_manager.call_deferred("apply_network_return_to_laboratory")


@rpc("authority", "call_remote", "reliable", 0)
func _open_meta_terminal() -> void:
	if role != Role.CLIENT:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var ui := get_tree().get_first_node_in_group("meta_lab_ui") as MetaLabUI
	if room_manager == null or ui == null:
		return
	var player: Node = room_manager._find_player(local_participant_id)
	if player != null:
		ui.open_terminal(player)


func _start_network_hub(config: Dictionary) -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.enter_lan_hub(config, role == Role.HOST)


func _on_peer_connected(peer_id: int) -> void:
	if role == Role.HOST:
		if not connected_peer_ids.has(peer_id) and connected_peer_ids.size() < MAX_PLAYERS - 1:
			connected_peer_ids.append(peer_id)
			connected_peer_ids.sort()
			var used_participants: Array = _peer_participants.values()
			for slot in range(2, MAX_PLAYERS + 1):
				var candidate := StringName("player_%d" % slot)
				if not used_participants.has(candidate):
					_peer_participants[peer_id] = candidate
					break
		connected_peer_id = connected_peer_ids[0] if not connected_peer_ids.is_empty() else 0
		session_player_count = 1 + connected_peer_ids.size()
		call_deferred("_publish_host_lobby_state", "Jogador conectado. Lobby %d/%d." % [get_player_count(), MAX_PLAYERS])


func _on_peer_disconnected(peer_id: int) -> void:
	if role == Role.HOST and connected_peer_ids.has(peer_id):
		var participant_id := get_participant_for_peer(peer_id)
		connected_peer_ids.erase(peer_id)
		_peer_participants.erase(peer_id)
		connected_peer_id = connected_peer_ids[0] if not connected_peer_ids.is_empty() else 0
		session_player_count = 1 + connected_peer_ids.size()
		_release_remote_player_inputs(participant_id)
		_pending_attribute_choices.erase(peer_id)
		for key_value: Variant in _last_action_sequences.keys():
			if String(key_value).begins_with("%d:" % peer_id):
				_last_action_sequences.erase(key_value)
		var room_manager := get_tree().get_first_node_in_group("room_manager")
		if room_manager != null:
			var disconnected_player: Node = room_manager._find_player(participant_id)
			if disconnected_player != null:
				disconnected_player.queue_free()
			room_manager.run_manager.set_participant_active(participant_id, false)
			room_manager.call_deferred("handle_teleport_participant_removed", participant_id)
		call_deferred("_publish_host_lobby_state", "Cliente desconectado. A sala continua aberta.")


func _on_connected_to_server() -> void:
	connected_peer_id = 1
	session_player_count = 2
	call_deferred("_publish_client_connection_ready")


func _publish_host_lobby_state(message: String) -> void:
	if role != Role.HOST:
		return
	_set_message(message)
	_broadcast_lobby_state()
	lobby_changed.emit()


func _publish_client_connection_ready() -> void:
	if role != Role.CLIENT:
		return
	_set_message("Conectado ao host. Aguardando início da run.")
	lobby_changed.emit()


func _broadcast_lobby_state() -> void:
	if role != Role.HOST or not multiplayer.has_multiplayer_peer():
		return
	var available_peers: PackedInt32Array = multiplayer.get_peers()
	for peer_id: int in connected_peer_ids:
		if available_peers.has(peer_id):
			_sync_lobby_state.rpc_id(peer_id, get_player_count(), String(get_participant_for_peer(peer_id)))


@rpc("authority", "call_remote", "reliable", 0)
func _sync_lobby_state(player_count: int, participant_id: String) -> void:
	if role != Role.CLIENT:
		return
	session_player_count = clampi(player_count, 1, MAX_PLAYERS)
	local_participant_id = StringName(participant_id)
	call_deferred("_emit_lobby_changed_if_networked")


func _emit_lobby_changed_if_networked() -> void:
	if role != Role.OFFLINE:
		lobby_changed.emit()


func _on_connection_failed() -> void:
	_set_message("Falha ao conectar. Verifique IP, Wi-Fi e hotspot.")
	role = Role.OFFLINE
	lobby_changed.emit()


func _on_server_disconnected() -> void:
	if role != Role.CLIENT:
		return
	_set_message("O host desconectou. Retornando ao menu LAN.")
	role = Role.OFFLINE
	connected_peer_id = 0
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.handle_lan_host_disconnected()
	lobby_changed.emit()


func _set_message(value: String) -> void:
	connection_message = value
	connection_message_changed.emit(value)
