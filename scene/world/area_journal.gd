class_name AreaJournal
extends RefCounted
## Per-run scene archives; inventory/economy always come from the live session.
const SNAPSHOT := preload("res://scene/persistence/session_snapshot.gd")
const AREA_FIELDS := ["stage_index", "current_stage_id", "current_biome_kind", "current_biome_id", "current_biome_name", "current_room_index", "generated_module_count", "generation_fallback", "generation_failure_reason", "area_seed_value", "selected_exit_id", "selected_exit_destination"]

static func key(snapshot: Dictionary) -> String:
	return "%d:%s" % [int(snapshot.run.seed_value), String(snapshot.run.get("current_stage_id", ""))]

static func remember(world: Dictionary, snapshot: Dictionary, location: Dictionary) -> String:
	if not SNAPSHOT.valid(snapshot) or snapshot.hub:
		return ""
	if not world.has("visited_areas"):
		world.visited_areas = {}
	# Keep only this run's archives; permanent discoveries remain in world.exploration.
	for previous: String in world.visited_areas.keys():
		if not previous.begins_with(str(snapshot.run.seed_value) + ":"):
			world.visited_areas.erase(previous)
	var id: String = key(snapshot)
	world.visited_areas[id] = {"session": snapshot.duplicate(true), "location": location.duplicate(true)}
	return id

static func prepare(world: Dictionary, id: String, live: Dictionary) -> Dictionary:
	var entry: Dictionary = world.get("visited_areas", {}).get(id, {})
	if entry.is_empty() or not SNAPSHOT.valid(entry.get("session", {})) or not SNAPSHOT.valid(live):
		return {}
	var old: Dictionary = entry.session
	if old.hub or int(old.run.seed_value) != int(live.run.seed_value):
		return {}
	var target: Dictionary = old.duplicate(true)
	target.run = live.run.duplicate(true)
	for field: String in AREA_FIELDS:
		if old.run.has(field):
			target.run[field] = old.run[field]
	target.players = live.players.duplicate(true)
	for index in mini(target.players.size(), old.players.size()):
		target.players[index].position = old.players[index].position
	target.permanent = live.permanent.duplicate(true)
	target.maps = live.maps.duplicate(true)
	return target
