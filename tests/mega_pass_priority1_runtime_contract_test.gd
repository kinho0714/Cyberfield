extends SceneTree

const LOWER_CITY_SCENE := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")
const INDUSTRIAL_SCENE := preload("res://scene/biomes/industrial/industrial_biome.tscn")
const LAB_SCENE := preload("res://scene/biomes/lab/lab_biome.tscn")
const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const LOCAL_COOP_INPUT := preload("res://scene/local_coop_input.gd")

const RELAXED_TELEPORTER_GRAPH_DISTANCE := 2
const TELEPORTER_SAMPLE_COUNT := 24


class RoomManagerStub:
	extends Node
	var current_room: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_gamepad_contract()
	await _test_drop_grounding_contract()
	_test_teleporter_spacing_contract(LOWER_CITY_SCENE, 940000)
	_test_teleporter_spacing_contract(INDUSTRIAL_SCENE, 950000)
	_test_teleporter_spacing_contract(LAB_SCENE, 960000)
	print("MEGA_PASS_PRIORITY1_RUNTIME_CONTRACT_TEST_OK")
	quit(0)


func _test_gamepad_contract() -> void:
	const P1_DEVICE := 7
	const P2_DEVICE := 8
	LOCAL_COOP_INPUT.ensure_player_one_actions(P1_DEVICE)
	assert(_has_axis(&"left", JOY_AXIS_LEFT_X, -1.0, P1_DEVICE))
	assert(_has_axis(&"right", JOY_AXIS_LEFT_X, 1.0, P1_DEVICE))
	assert(_has_axis(&"down", JOY_AXIS_LEFT_Y, 1.0, P1_DEVICE))
	assert(_has_button(&"left", JOY_BUTTON_DPAD_LEFT, P1_DEVICE))
	assert(_has_button(&"right", JOY_BUTTON_DPAD_RIGHT, P1_DEVICE))
	assert(_has_button(&"down", JOY_BUTTON_DPAD_DOWN, P1_DEVICE))
	assert(_has_button(&"jump", JOY_BUTTON_A, P1_DEVICE))
	assert(_has_button(&"attack", JOY_BUTTON_X, P1_DEVICE))
	assert(_has_button(&"dash", JOY_BUTTON_B, P1_DEVICE))
	assert(_has_button(&"interact", JOY_BUTTON_Y, P1_DEVICE))
	assert(_has_button(&"heal", JOY_BUTTON_LEFT_SHOULDER, P1_DEVICE))
	assert(_has_button(&"attack_slot_1", JOY_BUTTON_X, P1_DEVICE))
	assert(_has_button(&"attack_slot_2", JOY_BUTTON_RIGHT_SHOULDER, P1_DEVICE))
	assert(_has_axis(&"attack_slot_2", JOY_AXIS_TRIGGER_RIGHT, 1.0, P1_DEVICE))
	assert(_has_button(&"switch_weapon", JOY_BUTTON_LEFT_STICK, P1_DEVICE))
	assert(_has_keyboard_event(&"left"), "P1 gamepad binding removed keyboard movement")
	assert(_has_joypad_event(&"open_map"))
	assert(_has_joypad_event(&"open_inventory"))
	assert(_has_joypad_event(&"pause_menu"))

	LOCAL_COOP_INPUT.ensure_player_two_actions(P2_DEVICE)
	assert(_has_axis(&"p2_left", JOY_AXIS_LEFT_X, -1.0, P2_DEVICE))
	assert(_has_button(&"p2_jump", JOY_BUTTON_A, P2_DEVICE))
	assert(_has_button(&"p2_attack", JOY_BUTTON_X, P2_DEVICE))
	assert(_has_button(&"p2_dash", JOY_BUTTON_B, P2_DEVICE))
	assert(_has_button(&"p2_interact", JOY_BUTTON_Y, P2_DEVICE))
	assert(_has_button(&"p2_heal", JOY_BUTTON_LEFT_SHOULDER, P2_DEVICE))
	assert(_has_button(&"p2_attack_slot_1", JOY_BUTTON_X, P2_DEVICE))
	assert(_has_button(&"p2_attack_slot_2", JOY_BUTTON_RIGHT_SHOULDER, P2_DEVICE))
	assert(_has_axis(&"p2_attack_slot_2", JOY_AXIS_TRIGGER_RIGHT, 1.0, P2_DEVICE))


func _test_drop_grounding_contract() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	var room_manager := RoomManagerStub.new()
	room_manager.add_to_group("room_manager")
	root.add_child(room_manager)
	var room := Node2D.new()
	root.add_child(room)
	room_manager.current_room = room

	var floor := StaticBody2D.new()
	floor.collision_layer = 1
	room.add_child(floor)
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(200.0, 16.0)
	floor_shape.shape = floor_rectangle
	floor.position = Vector2(0.0, 100.0)
	floor.add_child(floor_shape)

	var source_enemy := CharacterBody2D.new()
	source_enemy.collision_layer = 1
	room.add_child(source_enemy)
	var enemy_shape := CollisionShape2D.new()
	var enemy_rectangle := RectangleShape2D.new()
	enemy_rectangle.size = Vector2(30.0, 30.0)
	enemy_shape.shape = enemy_rectangle
	source_enemy.position = Vector2(0.0, 35.0)
	source_enemy.add_child(enemy_shape)

	await physics_frame
	var grounded: Vector2 = manager.call("_resolve_enemy_drop_position", source_enemy.global_position, source_enemy)
	assert(absf(grounded.x) < 0.01)
	assert(is_equal_approx(grounded.y, 82.0), "Airborne enemy drop did not settle onto the platform")

	var edge_grounded: Vector2 = manager.call("_resolve_enemy_drop_position", Vector2(115.0, 35.0), source_enemy)
	assert(edge_grounded.x < 115.0 and is_equal_approx(edge_grounded.y, 82.0), "Drop near an edge did not find the nearby safe surface")

	var too_far := Vector2(0.0, -200.0)
	var unresolved: Vector2 = manager.call("_resolve_enemy_drop_position", too_far, source_enemy)
	assert(unresolved.is_equal_approx(too_far), "Drop grounding snapped to a surface beyond the configured maximum distance")

	room.queue_free()
	room_manager.queue_free()
	manager.queue_free()
	await process_frame


func _test_teleporter_spacing_contract(scene: PackedScene, seed_base: int) -> void:
	for sample in TELEPORTER_SAMPLE_COUNT:
		var seed := seed_base + sample * 7919
		var manager := RUN_MANAGER_SCRIPT.new()
		root.add_child(manager)
		manager.configure_run(&"solo", &"normal")
		manager.prepare_new_run(seed)
		var biome := scene.instantiate()
		assert(biome.generate(seed, manager))
		var graph: Dictionary = biome.get_map_graph()
		var teleporters: Array = graph.get("teleporters", []) as Array
		var modules: Array = graph.get("modules", []) as Array
		assert(teleporters.size() >= 3 and teleporters.size() <= 5)
		for first in teleporters.size():
			for second in range(first + 1, teleporters.size()):
				var a := teleporters[first] as Dictionary
				var b := teleporters[second] as Dictionary
				var graph_distance := _module_graph_distance(modules, int(a.module_index), int(b.module_index))
				assert(graph_distance >= RELAXED_TELEPORTER_GRAPH_DISTANCE, "Teleporter graph spacing regressed for seed %d" % seed)
				assert(Vector2(a.position).distance_to(Vector2(b.position)) >= 760.0, "Teleporter world spacing regressed for seed %d" % seed)
		biome.free()
		manager.free()


func _module_graph_distance(modules: Array, start_index: int, target_index: int) -> int:
	if start_index == target_index:
		return 0
	var neighbors := {}
	for value: Variant in modules:
		var module := value as Dictionary
		neighbors[int(module.index)] = (module.neighbors as Array).duplicate()
	var distances := {start_index: 0}
	var queue: Array[int] = [start_index]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor_value: Variant in neighbors.get(current, []):
			var neighbor := int(neighbor_value)
			if distances.has(neighbor):
				continue
			distances[neighbor] = int(distances[current]) + 1
			if neighbor == target_index:
				return int(distances[neighbor])
			queue.append(neighbor)
	return 999


func _has_axis(action: StringName, axis: JoyAxis, axis_value: float, device: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.device == device and event.axis == axis and is_equal_approx(event.axis_value, axis_value):
			return true
	return false


func _has_button(action: StringName, button: JoyButton, device: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.device == device and event.button_index == button:
			return true
	return false


func _has_keyboard_event(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return true
	return false


func _has_joypad_event(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false
