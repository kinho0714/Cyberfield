class_name WorldTracker
extends Node
signal mission_states_changed
signal visited_areas_changed
const WORLD := preload("res://scene/world/world_state.gd")
const ROUTES := preload("res://scene/world/region_routes.gd")
const CATALOG := preload("res://scene/world/world_catalog.gd")
var controller: Node
var catalog: WorldCatalog = CATALOG.new()
var elapsed := 0.0
# Validate each newly loaded/replaced world once; structural edits use validated APIs.
var _sample_world: Dictionary = {}


func _ready() -> void:
	controller.game.run_manager.gameplay_event.connect(record_gameplay_event)
	set_campaign_active(not controller.active.is_empty())


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.25:
		return
	elapsed = 0.0
	sample()


func sample() -> void:
	if controller.active.is_empty() or controller.restoring:
		return
	var game: Node = controller.game
	if not game.mode_selected or game.is_transitioning or game.get_node("MetaProgression").dev_sandbox_active or game.run_manager.dev_session:
		return
	if not is_same(_sample_world, controller.active.get("world", {})):
		if not WORLD.ensure(controller.active):
			return
		_sample_world = controller.active.world
	var players: Array = game.get_players()
	if players.is_empty():
		return
	var world: Dictionary = controller.active.world
	world.in_hub = bool(game.current_is_hub)
	if game.current_is_hub:
		return
	var neighborhood: String = current_neighborhood()
	if neighborhood.is_empty():
		return
	var room_id: String = String(game.run_manager.current_stage_id)
	if game.current_room.has_method("get_room_identity_at"):
		var identity: String = game.current_room.get_room_identity_at(players[0].global_position)
		if not identity.is_empty():
			room_id = "%d_%s" % [int(game.run_manager.seed_value), identity]
	if WORLD.visit(world, neighborhood, room_id, players[0].global_position):
		controller.dirty = true
		record_gameplay_event("location_discovered", "discover:" + neighborhood + "/" + room_id, {"target": neighborhood})


func current_neighborhood() -> String:
	if controller.active.is_empty() or not controller.active.has("world"):
		return ""
	var world: Dictionary = controller.active.world
	var kind: String = String(controller.game.run_manager.current_biome_kind)
	var municipality: String = catalog.municipality_for_biome(kind)
	var selected: String = String(world.location.get("neighborhood_id", ""))
	if not selected.is_empty() and world.locations.has(selected):
		var parent: String = String(world.locations[selected].parent_id)
		if municipality.is_empty() or parent.ends_with("/" + municipality):
			return selected
	if municipality.is_empty():
		return ""
	return String(world.world_id) + "/state_001/city_001/" + municipality + "/neighborhood_001"


func choose_region(id: String) -> bool:
	if controller.active.is_empty() or not controller.game.current_is_hub or controller.game.is_transitioning or controller.game.get_node("MetaProgression").dev_sandbox_active or controller.game.run_manager.dev_session:
		return false
	var next: Dictionary = controller.active.duplicate(true)
	if not next.world.discoveries.has(id) or not next.world.locations.has(id):
		return false
	if next.world.locations[id].kind != "neighborhood" or next.world.locations[id].implementation != "implemented":
		return false
	next.world.location = {"neighborhood_id": id, "room_id": "", "position": Vector2.ZERO}
	if not controller.store.save_campaign(next):
		return false
	controller.active = next
	return true


func known_regions() -> Array[Dictionary]:
	if controller.active.is_empty() or not controller.active.has("world"):
		return []
	return WORLD.public_view(controller.active.world).locations


func next_run_seed() -> int:
	if controller.game.get_node("MetaProgression").dev_sandbox_active or controller.game.run_manager.dev_session:
		return maxi(1, int(Crypto.new().generate_random_bytes(4).decode_u32(0)) & 0x7fffffff)
	if controller.active.is_empty():
		return 0
	var next: Dictionary = controller.active.duplicate(true)
	if not WORLD.ensure(next) or not ROUTES.ensure(next.world):
		return 0
	next.world.run_counter = int(next.world.get("run_counter", 0)) + 1
	var seed_value: int = WORLD.derive_seed(int(next.campaign_seed), "run_v1", str(next.world.run_counter))
	if not controller.store.save_campaign(next):
		controller.last_error = controller.store.last_error
		return 0
	controller.active = next
	return seed_value


func selected_biome() -> StringName:
	var world: Dictionary = controller.active.world
	var id: String = String(world.location.get("neighborhood_id", ""))
	if not world.locations.has(id):
		return &"lower_city"
	var municipality: String = String(world.locations[id].parent_id)
	return StringName(world.locations[municipality].get("biome_kind", "lower_city"))


func advance_route(exit_id: StringName) -> void:
	var game: Node = controller.game
	if controller.active.is_empty() or game.run_manager.dev_session or game.get_node("MetaProgression").dev_sandbox_active or game.run_manager.stage_index >= 5:
		return
	var world: Dictionary = controller.active.world
	if not ROUTES.ensure(world):
		return
	var source: String = current_neighborhood()
	var target: String = ROUTES.destination(world, source, "B" if exit_id == &"next_biome_b" else "A")
	if target.is_empty():
		return
	world.location = {"neighborhood_id": target, "room_id": "", "position": Vector2.ZERO}
	game.run_manager.stage_biome_kinds[game.run_manager.stage_index] = selected_biome()
	# Transition runs under the manager guard; consume only trusted local game events.
	preload("res://scene/missions/mission_ledger.gd").consume(world, "region_transition", "%d:%d:%s" % [int(game.run_manager.seed_value), int(game.run_manager.stage_index), target], {"target": target})
	controller.dirty = true


func area_seed(fallback: int) -> int:
	var game: Node = controller.game
	if controller.active.is_empty() or game.run_manager.dev_session or game.get_node("MetaProgression").dev_sandbox_active:
		return fallback
	var world: Dictionary = controller.active.world
	return ROUTES.area_seed(world, int(game.run_manager.seed_value), String(world.location.get("neighborhood_id", "")), int(game.run_manager.stage_index))


func record_area(seed_value: int, graph: Dictionary) -> void:
	var game: Node = controller.game
	if controller.active.is_empty() or game.run_manager.dev_session or game.get_node("MetaProgression").dev_sandbox_active or controller.restoring:
		return
	var world: Dictionary = controller.active.world
	if not ROUTES.ensure(world):
		return
	var key: String = "%d:%d" % [int(game.run_manager.seed_value), int(game.run_manager.stage_index)]
	world.areas[key] = {"neighborhood_id": world.location.get("neighborhood_id", ""), "area_seed": seed_value,
		"signature": graph.get("signature", ""), "graph": graph.duplicate(true)}
	controller.dirty = true


func preview_route(destination_id: StringName) -> StringName:
	if controller.active.is_empty() or controller.game.run_manager.dev_session or controller.game.get_node("MetaProgression").dev_sandbox_active:
		return &""
	var world: Dictionary = controller.active.world
	if not ROUTES.ensure(world):
		return &""
	var source: String = String(world.location.get("neighborhood_id", ""))
	var target: String = ROUTES.destination(world, source, "B" if destination_id == &"next_biome_b" else "A")
	if target.is_empty():
		return &""
	var parent: String = String(world.locations[target].parent_id)
	return StringName(world.locations[parent].get("biome_kind", ""))


func remember_current_area() -> String:
	if not _gameplay_writable() or controller.game.current_is_hub:
		return ""
	sample()
	var snapshot: Dictionary = preload("res://scene/persistence/session_snapshot.gd").capture(controller.game)
	if snapshot.is_empty():
		return ""
	var id: String = preload("res://scene/world/area_journal.gd").remember(controller.active.world, snapshot, controller.active.world.location)
	controller.dirty = true
	visited_areas_changed.emit()
	return id


func visited_areas() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if controller.active.is_empty():
		return result
	for id: String in controller.active.world.get("visited_areas", {}):
		var entry: Dictionary = controller.active.world.visited_areas[id]
		if int(entry.session.run.seed_value) == int(controller.game.run_manager.seed_value):
			result.append({"area_id": id, "location": entry.location.duplicate(true)})
	return result


func revisit_area(id: String) -> bool:
	if not _gameplay_writable() or controller.game.current_is_hub or controller.game.run_manager.stage_index >= 5:
		return false
	var game: Node = controller.game
	var snapshot_script: Script = preload("res://scene/persistence/session_snapshot.gd")
	var live: Dictionary = snapshot_script.capture(game)
	if live.is_empty() or preload("res://scene/world/area_journal.gd").key(live) == id:
		return false
	var target: Dictionary = preload("res://scene/world/area_journal.gd").prepare(controller.active.world, id, live)
	if target.is_empty():
		return false
	remember_current_area()
	var location: Dictionary = controller.active.world.visited_areas[id].location.duplicate(true)
	game.is_transitioning = true
	game._set_all_player_input(false)
	var restored: bool = snapshot_script.restore(game, target)
	if not restored:
		snapshot_script.restore(game, live)
	else:
		controller.active.world.location = location
	game.is_transitioning = false
	game._set_all_player_input(true)
	controller.dirty = true
	if restored:
		controller.save_now()
	return restored


func revisit_area_async(id: String) -> bool:
	if not _gameplay_writable() or controller.game.current_is_hub or controller.game.run_manager.stage_index >= 5:
		return false
	var game: Node = controller.game
	var snapshot_script: Script = preload("res://scene/persistence/session_snapshot.gd")
	var live: Dictionary = snapshot_script.capture(game)
	if live.is_empty() or preload("res://scene/world/area_journal.gd").key(live) == id:
		return false
	var target: Dictionary = preload("res://scene/world/area_journal.gd").prepare(controller.active.world, id, live)
	if target.is_empty():
		return false
	remember_current_area()
	var location: Dictionary = controller.active.world.visited_areas[id].location.duplicate(true)
	game.is_transitioning = true
	game._set_all_player_input(false)
	await game._fade_to(1.0)
	var restored: bool = await snapshot_script.restore_async(game, target)
	if not restored:
		await snapshot_script.restore_async(game, live)
	else:
		controller.active.world.location = location
	await game._fade_to(0.0)
	game.is_transitioning = false
	game._set_all_player_input(true)
	controller.dirty = true
	if restored:
		controller.save_now()
	return restored


func _gameplay_writable() -> bool:
	return not controller.active.is_empty() and not controller.restoring and not controller.game.is_transitioning and not controller.game.get_node("MetaProgression").dev_sandbox_active and not controller.game.run_manager.dev_session and not controller.game.lan_session.is_network_game()


func register_mission(definition: Dictionary) -> bool:
	if not _gameplay_writable():
		return false
	var result: bool = preload("res://scene/missions/mission_ledger.gd").register(controller.active.world, definition)
	controller.dirty = controller.dirty or result
	if result:
		mission_states_changed.emit()
	return result


func activate_mission(id: String) -> bool:
	if not _gameplay_writable():
		return false
	var result: bool = preload("res://scene/missions/mission_ledger.gd").activate(controller.active.world, id)
	controller.dirty = controller.dirty or result
	if result:
		mission_states_changed.emit()
	return result


func record_gameplay_event(type: String, event_id: String, payload: Dictionary = {}) -> void:
	if not _gameplay_writable():
		return
	if preload("res://scene/missions/mission_ledger.gd").consume(controller.active.world, type, event_id, payload):
		controller.dirty = true
		mission_states_changed.emit()


func claim_mission_reward(id: String) -> bool:
	if not _gameplay_writable() or not controller.save_now():
		return false
	# Reward and receipt are committed in the same campaign revision before applying runtime credit.
	var next: Dictionary = controller.active.duplicate(true)
	if not preload("res://scene/missions/mission_ledger.gd").claim(next, id):
		return false
	if not controller.store.save_campaign(next):
		controller.last_error = controller.store.last_error
		return false
	controller.active = next
	mission_states_changed.emit()
	controller.game.get_node("MetaProgression").credits = int(next.permanent.credits)
	controller.game.get_node("MetaProgression").profile_changed.emit()
	return true


func mission_states() -> Dictionary:
	if controller.active.is_empty():
		return {}
	return controller.active.world.get("missions", {}).duplicate(true)


func set_campaign_active(enabled: bool) -> void:
	set_process(enabled)
	if not enabled:
		_sample_world = {}
		elapsed = 0.0
