extends SceneTree
const WORLD := preload("res://scene/world/world_state.gd")
const CATALOG := preload("res://scene/world/world_catalog.gd")
const STORE := preload("res://scene/persistence/campaign_store.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)


func _run() -> void:
	var catalog: WorldCatalog = CATALOG.new()
	check(catalog.validate(), "catalog validation")
	var store: CampaignStore = STORE.new()
	store.root_path = "user://world_test_" + store.new_id()
	var a: Dictionary = store.create_campaign("A", 12345, {})
	var b: Dictionary = store.create_campaign("B", 67890, {})
	check(WORLD.ensure(a) and WORLD.ensure(b), "worlds initialized")
	var world: Dictionary = a.world
	var original: Dictionary = world.guard_distribution.duplicate(true)
	var same: Dictionary = a.duplicate(true)
	same.erase("world")
	check(WORLD.ensure(same) and same.world.guard_distribution == original, "fixed seed reproduces explicit distribution")
	var different: Dictionary = same.duplicate(true)
	different.erase("world")
	different.campaign_seed = 67890
	check(WORLD.ensure(different) and different.world.guard_distribution != original, "known seed pair varies distribution")
	var assigned: Dictionary = {}
	for slot: Variant in original:
		var state_id: String = original[slot].state_id
		check(not assigned.has(state_id), "distinct eligible states")
		check(state_id.ends_with("state_001") or state_id.ends_with("state_002") or state_id.ends_with("state_003") or state_id.ends_with("state_004") or state_id.ends_with("state_005") or state_id.ends_with("state_006") or state_id.ends_with("state_007"), "investigative states excluded")
		assigned[state_id] = true
	check(assigned.size() == 7, "seven reserved guard slots")
	check(WORLD.ensure(a) and a.world.guard_distribution == original, "ensure never reshuffles")
	var known: Dictionary = WORLD.public_view(world)
	check(not known.has("guard_distribution") and not str(known).contains("eligible_guard"), "hidden knowledge filtered")
	var neighborhood: String = String(world.world_id) + "/state_001/city_001/industrial/neighborhood_001"
	check(WORLD.visit(world, neighborhood, "room_test_001", Vector2(3, 7)), "new discovery")
	check(not WORLD.visit(world, neighborhood, "room_test_001", Vector2(4, 8)), "discovery idempotent")
	check(WORLD.discover_clue(world, {"clue_id": "test_clue", "source_location": neighborhood, "narrative_status": "reserved"}), "reserved fixture clue")
	check(not WORLD.discover_clue(world, {"clue_id": "test_clue", "source_location": neighborhood}), "no duplicate clue")
	check(store.save_campaign(a), "world committed")
	var restored: Dictionary = store.load_campaign(a.campaign_id)
	check(restored.world.guard_distribution == original and restored.world.clues.has("test_clue"), "distribution and clues persist")
	check(restored.world.location.position == Vector2(4, 8), "geographic position persists")
	check(b.world.exploration.is_empty(), "independent exploration")
	for id: Variant in world.locations:
		var location: Dictionary = world.locations[id]
		if location.kind != "world":
			check(world.locations.has(location.parent_id), "parent reference valid")
	print("WORLD_PERSISTENCE_REPORT failures=", failures)
	quit(0 if failures == 0 else 1)
