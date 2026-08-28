extends SceneTree

const LAB_SCENE := preload("res://scene/laboratory_hub.tscn")

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
