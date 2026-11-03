class_name CampaignWorld
extends RefCounted
const CATALOG := preload("res://scene/world/world_catalog.gd")
const VERSION := 1


static func derive_seed(campaign_seed: int, domain: String, identity: String) -> int:
	var digest: PackedByteArray = ("%d|%s|%s" % [campaign_seed, domain, identity]).sha256_buffer()
	return maxi(1, int(digest.decode_u32(0)) & 0x7fffffff)


static func ensure(campaign: Dictionary) -> bool:
	if campaign.has("world"):
		return campaign.world is Dictionary and valid(campaign.world, String(campaign.campaign_id))
	var catalog: WorldCatalog = CATALOG.new()
	if not catalog.error.is_empty():
		return false
	var locations: Dictionary = {}
	var root_id: String = String(campaign.campaign_id)
	locations[root_id] = _location(root_id, "world", "", "Campanha", "reserved", "partial")
	var eligible: Array[String] = []
	for state: Dictionary in catalog.data.states:
		var sid: String = root_id + "/" + String(state.id)
		locations[sid] = _location(sid, "state", root_id, state.display_name, state.narrative_status, state.implementation)
		if bool(state.eligible_guard):
			eligible.append(sid)
		for city: Dictionary in catalog.data.city_templates:
			var cid: String = sid + "/" + String(city.id)
			locations[cid] = _location(cid, "city", sid, city.display_name, city.narrative_status, "partial")
			for municipality: Dictionary in catalog.data.municipalities:
				var mid: String = cid + "/" + String(municipality.id)
				locations[mid] = _location(mid, "municipality", cid, municipality.display_name, municipality.narrative_status, municipality.implementation)
				locations[mid].biome_kind = municipality.biome_kind
				for neighborhood: Dictionary in municipality.neighborhoods:
					var nid: String = mid + "/" + String(neighborhood.id)
					locations[nid] = _location(nid, "neighborhood", mid, neighborhood.display_name, "proposed", municipality.implementation)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = derive_seed(int(campaign.campaign_seed), "guard_distribution_v1", "")
	for i in range(eligible.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var item: String = eligible[i]
		eligible[i] = eligible[j]
		eligible[j] = item
	var assignment: Dictionary = {}
	for i in catalog.data.guard_slots.size():
		assignment[catalog.data.guard_slots[i].id] = {"state_id": eligible[i], "character_id": "", "narrative_status": "reserved"}
	campaign.world = {"schema_version": VERSION, "catalog_version": catalog.data.catalog_version,
		"world_id": root_id, "campaign_seed": campaign.campaign_seed, "locations": locations,
		"guard_distribution": assignment, "discoveries": {}, "exploration": {}, "clues": {},
		"events": {}, "location": {}, "run_counter": 0}
	visit(campaign.world, root_id + "/state_001/city_001/cidade_baixa/neighborhood_001", "", Vector2.ZERO)
	return true


static func _location(id: String, kind: String, parent: String, name: String, status: String, implementation: String) -> Dictionary:
	return {"id": id, "kind": kind, "parent_id": parent, "display_name": name,
		"narrative_status": status, "implementation": implementation}


static func visit(world: Dictionary, neighborhood_id: String, room_id: String, position: Vector2) -> bool:
	if not world.locations.has(neighborhood_id) or world.locations[neighborhood_id].kind != "neighborhood":
		return false
	var changed := false
	var id: String = neighborhood_id
	while not id.is_empty():
		if not world.discoveries.has(id):
			world.discoveries[id] = true
			changed = true
		id = String(world.locations[id].parent_id)
	if not room_id.is_empty():
		var rid: String = neighborhood_id + "/" + room_id
		if not world.exploration.has(rid):
			world.exploration[rid] = {"neighborhood_id": neighborhood_id, "room_id": room_id}
			changed = true
	world.location = {"neighborhood_id": neighborhood_id, "room_id": room_id, "position": position}
	return changed


static func discover_clue(world: Dictionary, clue: Dictionary) -> bool:
	var id: String = String(clue.get("clue_id", ""))
	if not CATALOG.safe_id(id) or world.clues.has(id):
		return false
	var source: String = String(clue.get("source_location", ""))
	if not world.locations.has(source):
		return false
	for prerequisite: Variant in clue.get("prerequisites", []):
		if not world.clues.has(String(prerequisite)):
			return false
	world.clues[id] = clue.duplicate(true)
	world.clues[id].discovered = true
	world.clues[id].discovered_at = Time.get_datetime_string_from_system(true)
	world.events["clue:" + id] = true
	return true


static func public_view(world: Dictionary) -> Dictionary:
	var known: Array[Dictionary] = []
	for id: Variant in world.discoveries:
		if world.locations.has(id):
			known.append(world.locations[id].duplicate(true))
	return {"world_id": world.world_id, "locations": known, "clues": world.clues.duplicate(true),
		"location": world.location.duplicate(true)}


static func valid(world: Dictionary, campaign_id: String) -> bool:
	if int(world.get("schema_version", 0)) != VERSION or world.get("world_id", "") != campaign_id:
		return false
	for key in ["locations", "discoveries", "exploration", "clues", "events", "location", "guard_distribution"]:
		if world.get(key) is not Dictionary:
			return false
	for id: Variant in world.locations:
		var entry: Variant = world.locations[id]
		if entry is not Dictionary or entry.get("id") != id:
			return false
		if entry.get("kind") != "world" and not world.locations.has(entry.get("parent_id", "")):
			return false
	return true
