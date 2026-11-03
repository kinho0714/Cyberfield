class_name PrivateGameplayBridge
extends Node
## Explicit opt-in adapter: trusted host Godot simulates; relay only authenticates seats/routes messages.
## No UI, no account authentication and no writes to individual campaign namespaces.
signal gameplay_ready
signal snapshot_applied(revision: int)
const WIRE := preload("res://scene/network/gameplay_wire.gd")
const ACTIONS := ["left", "right", "down", "jump", "attack", "attack_slot_1", "attack_slot_2", "dash", "interact", "heal", "switch_weapon", "gadget_1", "gadget_2"]
var game: Node
var transport: PrivateSessionClient
var running := false
var _starting := false
var last_applied := 0
var _elapsed := 0.0
var _awaiting_ack := false
var _world_key := ""
var _transport_paused := false
var _run_was_active := false
var _game_process_mode := Node.PROCESS_MODE_INHERIT
var _input_age: Dictionary = {}
var _input_sequences: Dictionary = {}
var _legacy_path := ""
var _has_legacy_state := false
var _legacy_state: Dictionary = {}
var _owned_snapshot: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind_gameplay(target: Node, client: PrivateSessionClient) -> Error:
	if running or game != null or target.mode_selected or not target.campaigns.active.is_empty() or target.lan_session.is_network_game():
		return ERR_ALREADY_IN_USE
	_has_legacy_state = false
	last_applied = 0
	_elapsed = 0.0
	_awaiting_ack = false
	_world_key = ""
	_input_age.clear()
	_input_sequences.clear()
	_owned_snapshot.clear()
	_transport_paused = false
	game = target
	transport = client
	transport.input_received.connect(_host_input)
	transport.state_received.connect(_receive_snapshot)
	return OK

func begin() -> Error:
	if game == null or transport == null or transport.status != "active" or running or _starting or game.mode_selected:
		return ERR_UNAVAILABLE
	var count: int = int(transport.lobby.get("required_players", 4))
	if count < 2 or count > 4 or transport.lobby.get("connected", []).size() != count:
		return ERR_UNAUTHORIZED
	_starting = true
	var meta: Node = game.get_node("MetaProgression")
	_legacy_path = meta.save_path
	_legacy_state = meta.to_dictionary().duplicate(true)
	_has_legacy_state = true
	# Any existing progression API writes only to the independent cooperative scope.
	meta.save_path = "user://coop_authority_v1/" + transport.room_id + "/profile.json"
	DirAccess.make_dir_recursive_absolute(meta.save_path.get_base_dir())
	meta._reset_defaults()
	await game.start_configured_run(&"solo", &"normal", -1)
	if not game.mode_selected:
		meta.save_path = _legacy_path
		meta._reset_defaults()
		meta._apply_save(_legacy_state)
		_has_legacy_state = false
		_starting = false
		return ERR_CANT_CREATE
	game.run_manager.configure_run(&"lan", &"normal", -1, count)
	game._create_network_players(count)
	for actor in game.get_players():
		game.run_manager.register_participant(actor.participant_id, true)
	game._position_players_in_hub(game.current_room.get_node("Gameplay/P1Spawn").global_position, game.current_room.get_node("Gameplay/P2Spawn").global_position)
	running = true
	_starting = false
	if transport.peer_id != 1:
		_passive_client()
	gameplay_ready.emit()
	return OK

func _physics_process(delta: float) -> void:
	if not running:
		return
	if transport.status != "active":
		# Fail closed on any missing seat; no movement/rewards while the private session is paused.
		if not _transport_paused:
			_run_was_active = bool(game.run_manager.run_active)
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if enemy.has_method("cancel_attack"):
					enemy.cancel_attack()
			_game_process_mode = game.process_mode
			game.process_mode = Node.PROCESS_MODE_DISABLED
			_transport_paused = true
		game.run_manager.run_active = false
		_awaiting_ack = false
		game._set_all_player_input(false)
		for peer: int in _input_age:
			_release_peer(peer)
		return
	if _transport_paused:
		game.run_manager.run_active = _run_was_active
		game.process_mode = _game_process_mode
		_transport_paused = false
		if transport.peer_id == 1:
			game._set_all_player_input(not game.is_transitioning)
	if transport.peer_id == 1:
		for peer: int in _input_age:
			_input_age[peer] = float(_input_age[peer]) + delta
			if float(_input_age[peer]) >= 0.25:
				_release_peer(peer)
	_elapsed += delta
	if _elapsed < 0.05 or game.is_transitioning:
		return
	_elapsed = 0.0
	if transport.peer_id == 1:
		if not _awaiting_ack:
			var state: Dictionary = _capture()
			if transport.publish_snapshot(state) == OK:
				_awaiting_ack = true
	else:
		var actions: Dictionary = {}
		for action: String in ACTIONS:
			actions[action] = Input.is_action_pressed(StringName(action)) or (action in ["left", "right", "down"] and InputMap.has_action("touch_" + action) and Input.is_action_pressed("touch_" + action))
		transport.send_input(actions)

func _host_input(peer: int, sequence: int, actions: Dictionary) -> void:
	if not running or transport.peer_id != 1 or transport.status != "active" or peer < 2 or peer > game.get_players().size() or sequence <= int(_input_sequences.get(peer, 0)):
		return
	for key: Variant in actions:
		if not ACTIONS.has(key) or actions[key] is not bool:
			return
	_input_sequences[peer] = sequence
	_input_age[peer] = 0.0
	game.lan_session._apply_remote_input(StringName("player_%d" % peer), actions)

func _release_peer(peer: int) -> void:
	game.lan_session._apply_remote_input(StringName("player_%d" % peer), {})

func _capture() -> Dictionary:
	var players: Dictionary = {}
	for actor in game.get_players():
		players[String(actor.participant_id)] = WIRE.encode(actor.get_network_state())
	var enemies: Dictionary = {}
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("get_network_state") and enemy.get("is_dead") != true and int(enemy.get("health")) > 0:
			enemies[String(enemy.persistent_id)] = WIRE.encode(enemy.get_network_state())
	var manager: Node = game.run_manager
	return {"world_state": {"protocol": 1, "signature": String(game.current_room.get_generation_report().get("signature", "")) if game.current_room.has_method("get_generation_report") else "", "hub": game.current_is_hub, "seed": manager.seed_value, "area_seed": manager.area_seed_value, "stage": manager.stage_index, "stage_id": String(manager.current_stage_id), "kind": String(manager.current_biome_kind), "enemies": enemies, "dirty_money": manager.dirty_money, "scrap": manager.scrap}, "player_states": players, "story_state": {}, "inventory_state": {}}

func _receive_snapshot(revision: int, state: Dictionary) -> void:
	if not running:
		return
	if transport.peer_id == 1:
		_awaiting_ack = false
		return
	if revision <= last_applied or state.get("world_state") is not Dictionary or state.get("player_states") is not Dictionary:
		return
	var world: Dictionary = state.world_state
	if int(world.get("protocol", 0)) != 1 or world.get("hub") is not bool or world.get("enemies") is not Dictionary or state.player_states.size() > 4 or int(world.get("stage", -1)) < 0 or int(world.get("stage", -1)) > 5:
		return
	var key: String = "%s:%d:%d:%s" % [str(world.hub), int(world.seed), int(world.stage), String(world.kind)]
	if key != _world_key:
		game.run_manager.seed_value = int(world.seed)
		game.run_manager.stage_index = int(world.stage)
		game.run_manager.current_stage_id = StringName(world.get("stage_id", "lower_city"))
		game.run_manager.stage_biome_kinds[int(world.stage)] = StringName(world.kind)
		game.restoring_snapshot = true
		var loaded: bool = game._load_laboratory_hub() if bool(world.hub) else game._load_current_stage(int(world.area_seed))
		game.restoring_snapshot = false
		if not loaded:
			return
		var signature: String = String(game.current_room.get_generation_report().get("signature", "")) if game.current_room.has_method("get_generation_report") else ""
		if signature != String(world.get("signature", "")):
			transport._fail("layout_mismatch")
			return
		_world_key = key
		_passive_client()
	for actor in game.get_players():
		var id: String = String(actor.participant_id)
		if state.player_states.has(id):
			var data: Dictionary = WIRE.decode(state.player_states[id])
			actor.apply_network_state(data, false)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var id: String = String(enemy.persistent_id)
		if world.enemies.has(id) and enemy.has_method("apply_network_state"):
			enemy.apply_network_state(WIRE.decode(world.enemies[id]))
		elif not world.enemies.has(id):
			enemy.queue_free()
	game.run_manager.dirty_money = int(world.get("dirty_money", 0))
	game.run_manager.scrap = int(world.get("scrap", 0))
	last_applied = revision
	_owned_snapshot = state.duplicate(true)
	snapshot_applied.emit(revision)

func _passive_client() -> void:
	for actor in game.get_players():
		actor.network_remote_replica = true
		actor.network_prediction_only = false
		actor.set_input_enabled(false)
		actor.network_target_position = actor.global_position
	game._set_client_world_passive()
	_disable_interactions(game.current_room)

func _disable_interactions(node: Node) -> void:
	# Includes parent scripts (e.g. DashPassage) that poll their child detectors.
	node.set_physics_process(false)
	if node is Area2D:
		node.set_process(false)
		node.set_physics_process(false)
		node.set_deferred("monitoring", false)
		node.set_deferred("monitorable", false)
	for child in node.get_children():
		_disable_interactions(child)

func stop() -> void:
	while _starting:
		await get_tree().process_frame
	if game == null:
		return
	running = false
	if _transport_paused:
		game.process_mode = _game_process_mode
		_transport_paused = false
	for peer: int in _input_age:
		_release_peer(peer)
	await game.return_to_main_menu()
	var meta: Node = game.get_node("MetaProgression")
	if _has_legacy_state:
		meta.save_path = _legacy_path
		meta._reset_defaults()
		meta._apply_save(_legacy_state)
	_has_legacy_state = false
	transport.input_received.disconnect(_host_input)
	transport.state_received.disconnect(_receive_snapshot)
	game = null
	_legacy_state.clear()
	_legacy_path = ""
