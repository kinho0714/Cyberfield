extends SceneTree
const WORLD := preload("res://scene/world/world_state.gd")
const ROUTES := preload("res://scene/world/region_routes.gd")
var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var a: Dictionary = {"campaign_id": "a".repeat(32), "campaign_seed": 314159}
	var b: Dictionary = {"campaign_id": "b".repeat(32), "campaign_seed": 314159}
	check(WORLD.ensure(a) and WORLD.ensure(b), "same seed worlds")
	check(ROUTES.ensure(a.world) and ROUTES.ensure(b.world), "connected graph valid")
	var start: String = a.campaign_id + "/state_001/city_001/cidade_baixa/neighborhood_001"
	var reachable: Dictionary = ROUTES.reachable(a.world, start)
	check(reachable.size() >= 6, "main routes do not require optional ability")
	check(ROUTES.destination(a.world, start, "secret").is_empty(), "secret requires dash")
	check(not ROUTES.destination(a.world, start, "secret", ["dash"]).is_empty(), "secret reachable with ability")
	var seed_value: int = ROUTES.area_seed(a.world, 12, start, 0)
	var other_start: String = start.replace(a.campaign_id, b.campaign_id)
	check(seed_value == ROUTES.area_seed(b.world, 12, other_start, 0), "same campaign seed reproduces area across independent IDs")
	check(seed_value != ROUTES.area_seed(b.world, 13, other_start, 0), "run variation")
	var c: Dictionary = {"campaign_id": "c".repeat(32), "campaign_seed": 271828}
	check(WORLD.ensure(c), "second known seed")
	check(seed_value != ROUTES.area_seed(c.world, 12, start.replace(a.campaign_id, c.campaign_id), 0), "campaign variation")
	var frozen: Dictionary = a.world.duplicate(true)
	check(ROUTES.ensure(a.world) and a.world == frozen, "saved explicit routes unchanged")
	print("REGION_ROUTES_REPORT failures=", failures)
	quit(0 if failures == 0 else 1)
