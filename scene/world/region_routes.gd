class_name RegionRoutes
extends RefCounted
const WORLD := preload("res://scene/world/world_state.gd")
const MUNICIPALITIES := ["cidade_baixa", "industrial", "laboratorio"]
const NEXT := {"cidade_baixa": "industrial", "industrial": "laboratorio", "laboratorio": "industrial"}


static func ensure(world: Dictionary) -> bool:
	if world.has("routes"):
		return world.routes is Dictionary and validate(world)
	var routes: Dictionary = {}
	for id: Variant in world.locations:
		var entry: Dictionary = world.locations[id]
		if entry.kind != "municipality" or not MUNICIPALITIES.has(String(id).get_file()):
			continue
		var first: String = String(id) + "/neighborhood_001"
		var second: String = String(id) + "/neighborhood_002"
		var optional: String = String(id) + "/neighborhood_003"
		var next: String = String(entry.parent_id) + "/" + String(NEXT[String(id).get_file()]) + "/neighborhood_001"
		routes[first] = [_edge(next, "A", []), _edge(second, "B", []), _edge(optional, "secret", ["dash"])]
		routes[second] = [_edge(next, "A", []), _edge(optional, "B", [])]
		routes[optional] = [_edge(next, "A", []), _edge(second, "B", [])]
	world.routes = routes
	world.route_version = 1
	world.areas = {}
	return validate(world)


static func _edge(target: String, exit_id: String, requirements: Array) -> Dictionary:
	return {"target_id": target, "exit_id": exit_id, "requirements": requirements, "narrative_status": "proposed"}


static func validate(world: Dictionary) -> bool:
	for source: Variant in world.routes:
		if not world.locations.has(source) or world.routes[source] is not Array:
			return false
		var main_route := false
		for edge: Variant in world.routes[source]:
			if edge is not Dictionary or not world.locations.has(edge.get("target_id", "")) or edge.get("requirements") is not Array:
				return false
			if edge.requirements.is_empty():
				main_route = true
		if not main_route:
			return false
	return true


static func destination(world: Dictionary, source: String, exit_id: String, abilities: Array = []) -> String:
	for edge: Dictionary in world.routes.get(source, []):
		if String(edge.exit_id) != exit_id:
			continue
		var permitted := true
		for requirement: Variant in edge.requirements:
			if not abilities.has(requirement):
				permitted = false
		if permitted:
			return String(edge.target_id)
	return ""


static func area_seed(world: Dictionary, run_seed: int, neighborhood: String, stage: int) -> int:
	var relative: String = neighborhood.trim_prefix(String(world.world_id) + "/")
	return WORLD.derive_seed(int(world.campaign_seed), "area_v1", "%d|%s|%d" % [run_seed, relative, stage])


static func reachable(world: Dictionary, start: String, abilities: Array = []) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[String] = [start]
	while not queue.is_empty():
		var source: String = queue.pop_front()
		for edge: Dictionary in world.routes.get(source, []):
			var target: String = destination(world, source, String(edge.exit_id), abilities)
			if not target.is_empty() and not seen.has(target):
				seen[target] = true
				queue.append(target)
	return seen
