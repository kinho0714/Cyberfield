class_name MissionLedger
extends RefCounted
## Data-only, unique missions. Definitions are trusted project content, never client messages.
const EVENT_TYPES := ["location_discovered", "npc_interacted", "enemy_defeated", "item_collected", "investigation", "region_transition"]

static func ensure(world: Dictionary) -> void:
	if not world.has("missions"):
		world.missions = {}

static func register(world: Dictionary, definition: Dictionary) -> bool:
	ensure(world)
	var id: String = String(definition.get("id", ""))
	if id.is_empty() or id.length() > 128 or world.missions.has(id) or definition.get("objectives") is not Array or definition.objectives.is_empty():
		return false
	var objective_ids: Dictionary = {}
	for objective: Variant in definition.objectives:
		if objective is not Dictionary or not EVENT_TYPES.has(objective.get("event", "")) or int(objective.get("count", 0)) < 1:
			return false
		var oid: String = String(objective.get("id", ""))
		if oid.is_empty() or objective_ids.has(oid):
			return false
		objective_ids[oid] = 0
	var prerequisites: Variant = definition.get("prerequisites", [])
	if prerequisites is not Array or prerequisites.has(id):
		return false
	for prior: Variant in prerequisites:
		if prior is not String or not world.missions.has(prior):
			return false
	if int(definition.get("reward_credits", 0)) < 0 or int(definition.get("reward_credits", 0)) > 1000000:
		return false
	world.missions[id] = {"definition": definition.duplicate(true), "state": "blocked", "progress": objective_ids, "events": {}, "reward_claimed": false}
	refresh(world)
	return true

static func refresh(world: Dictionary) -> void:
	ensure(world)
	for id: String in world.missions:
		var mission: Dictionary = world.missions[id]
		if mission.state != "blocked":
			continue
		var permitted := true
		for prior: String in mission.definition.get("prerequisites", []):
			if not world.missions.has(prior) or world.missions[prior].state != "completed":
				permitted = false
		if permitted:
			mission.state = "available"

static func activate(world: Dictionary, id: String) -> bool:
	refresh(world)
	if not world.missions.has(id) or world.missions[id].state != "available":
		return false
	world.missions[id].state = "active"
	return true

static func fail(world: Dictionary, id: String) -> bool:
	if not world.get("missions", {}).has(id) or world.missions[id].state != "active":
		return false
	world.missions[id].state = "failed"
	return true

static func consume(world: Dictionary, type: String, event_id: String, payload: Dictionary = {}) -> bool:
	ensure(world)
	if not EVENT_TYPES.has(type) or event_id.is_empty() or event_id.length() > 256:
		return false
	var changed := false
	for id: String in world.missions:
		var mission: Dictionary = world.missions[id]
		if mission.state != "active" or mission.events.has(event_id):
			continue
		var matched := false
		var complete := true
		for objective: Dictionary in mission.definition.objectives:
			var oid: String = String(objective.id)
			if String(objective.event) == type and (String(objective.get("target", "")).is_empty() or objective.target == payload.get("target", "")):
				mission.progress[oid] = mini(int(mission.progress[oid]) + 1, int(objective.count))
				matched = true
			if int(mission.progress[oid]) < int(objective.count):
				complete = false
		if matched:
			mission.events[event_id] = true
			changed = true
			if complete:
				mission.state = "completed"
	refresh(world)
	return changed

static func claim(campaign: Dictionary, id: String) -> bool:
	var missions: Dictionary = campaign.get("world", {}).get("missions", {})
	if not missions.has(id) or missions[id].state != "completed" or missions[id].reward_claimed:
		return false
	missions[id].reward_claimed = true
	campaign.permanent.credits = int(campaign.permanent.get("credits", 0)) + int(missions[id].definition.get("reward_credits", 0))
	if not campaign.get("session", {}).is_empty():
		campaign.session.permanent = campaign.permanent.duplicate(true)
	return true
