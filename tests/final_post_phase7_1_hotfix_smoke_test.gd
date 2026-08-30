extends SceneTree

const LAB_SCENE := preload("res://scene/laboratory_hub.tscn")
const PLAYER_SCRIPT := preload("res://entities/player.gd")

class FakeRunManager extends Node:
	var last_run_results: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := FakeRunManager.new()
	manager.add_to_group("run_manager")
	root.add_child(manager)
	var lab := LAB_SCENE.instantiate()
	root.add_child(lab)
	_test_laboratory_hub_geometry(lab)
	var variants := [
		{},
		{"completed": false, "elapsed_time": 110.0, "difficulty": &"pro", "money_earned": 89, "stage_index": 0, "weapons_found": {&"player_1": PackedStringArray(["scrap_blade", "breaker_maul"])}, "participants": {&"player_1": {"intellect": 0, "health": 0, "strength": 0}}},
		{"completed": false, "weapons_found": null, "stage_history": "", "participants": null},
		{"completed": true, "weapons_found": [&"arc_emitter"], "stage_history": [{"exit_id": &"right"}]},
	]
	for result in variants:
		manager.last_run_results = result
		lab._ready()
		var summary := lab.get_node("LastRunSummary") as Label
		assert(not summary.text.is_empty())
	assert(lab._normalize_sequence(PackedStringArray(["a", "b"])).size() == 2)
	assert(lab._normalize_sequence({"p1": [&"scrap_blade"]}).size() == 1)
	assert(lab._normalize_weapons({"p1": [&"scrap_blade"], "p2": "arc_emitter"}).size() == 2)
	var main: Node = load("res://scene/main.tscn").instantiate()
	var result_title := main.get_node("RunDebugHUD/EndOverlay/Center/VBox/Title") as Label
	assert(result_title.autowrap_mode != TextServer.AUTOWRAP_OFF)
	assert(result_title.get_theme_font_size("font_size") <= 28)
	main.free()
	lab.free()
	manager.free()
	print("FINAL_POST_PHASE7_1_HOTFIX_SMOKE_TEST_OK")
	quit()


func _test_laboratory_hub_geometry(lab: Node2D) -> void:
	var p1_spawn := lab.get_node("Gameplay/P1Spawn") as Marker2D
	var p2_spawn := lab.get_node("Gameplay/P2Spawn") as Marker2D
	var terminal := lab.get_node("Gameplay/MetaTerminal") as Area2D
	var portal := lab.get_node("Gameplay/RunPortal") as Area2D
	var floor := lab.get_node("Geometry/Floor") as StaticBody2D
	var catwalk := lab.get_node("Geometry/UpperCatwalk") as StaticBody2D
	var access_wall := lab.get_node("Geometry/AccessWall") as StaticBody2D
	var right_wall := lab.get_node("Geometry/RightWall") as StaticBody2D
	var floor_shape := (floor.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var catwalk_shape := (catwalk.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var access_shape := (access_wall.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var right_wall_shape := (right_wall.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var portal_shape := (portal.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var floor_top: float = floor.position.y - floor_shape.size.y * 0.5
	var catwalk_top: float = catwalk.position.y - catwalk_shape.size.y * 0.5
	var catwalk_bottom: float = catwalk.position.y + catwalk_shape.size.y * 0.5
	var access_top: float = access_wall.position.y - access_shape.size.y * 0.5
	var access_bottom: float = access_wall.position.y + access_shape.size.y * 0.5
	var access_left: float = access_wall.position.x - access_shape.size.x * 0.5
	var shaft_left: float = access_wall.position.x + access_shape.size.x * 0.5
	var shaft_right: float = right_wall.position.x - right_wall_shape.size.x * 0.5
	var portal_right: float = portal.position.x + portal_shape.size.x * 0.5
	assert(catwalk_shape.size.x >= 900.0 and catwalk_shape.size.y <= 24.0)
	assert(floor_top - catwalk_bottom >= 240.0)
	assert(is_equal_approx(access_top, catwalk_top))
	assert(floor_top - access_bottom >= 96.0)
	assert(shaft_right - shaft_left > 80.0)
	assert(shaft_right - shaft_left <= float(PLAYER_SCRIPT.WALL_TRANSFER_SAFE_SHAFT_WIDTH))
	assert(portal_right < access_left)
	assert(p1_spawn.position.y < floor_top and p2_spawn.position.y < floor_top)
	assert(p1_spawn.position.x < portal.position.x and p2_spawn.position.x < portal.position.x)
	assert(terminal.position.x < p1_spawn.position.x)
	assert(terminal.has_node("CollisionShape2D") and portal.has_node("CollisionShape2D"))
	assert(lab.has_node("FutureStations/WorkshopZone"))
	assert(lab.has_node("FutureStations/ArsenalZone"))
	assert(lab.has_node("FutureStations/UpgradeZone"))
	assert(lab.has_node("FutureStations/RecordsZone"))
	assert(lab.has_node("BackgroundStructure/UpperWall"))
	assert(lab.has_node("MidgroundStructure"))
	assert(lab.has_node("GameplayStructureVisuals/Catwalk"))
	assert(lab.has_node("Decoration"))
