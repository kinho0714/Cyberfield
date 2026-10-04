extends SceneTree

const PLAYER_SCENE := preload("res://entities/player.tscn")
const BIOME_SCENE := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")
const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_valid_shaft_transfer_and_consecutive_jump()
	await _test_large_gap_is_not_reached_during_ascent()
	_test_procedural_shaft_contract()
	_release_inputs()
	print("PHASE8_WALL_TO_WALL_SHAFT_HOTFIX_SMOKE_TEST_OK")
	quit(0)


func _test_valid_shaft_transfer_and_consecutive_jump() -> void:
	var setup := _build_test_shaft(BiomeGenerator.VERTICAL_SHAFT_INNER_WIDTH)
	var player := setup.player as CharacterBody2D
	assert(player.WALL_CLIMB_DURATION == 3.6)
	assert(player.max_wall_climb_duration == 3.6)
	Input.action_press(&"left")
	player.velocity.x = -80.0
	await physics_frame
	await physics_frame
	assert(player.is_on_wall() and player.get_wall_normal().x > 0.0)
	var stamina_before: float = player.wall_climb_time
	player.call("_launch_wall_jump", player.get_wall_normal())
	await physics_frame
	# The source-wall direction is intentionally still held here. It must not
	# erase the wall-jump launch on Android before the thumb crosses the axis.
	assert(player.velocity.x > 300.0)
	var stamina_spent: float = stamina_before - player.wall_climb_time
	assert(stamina_spent >= player.WALL_JUMP_STAMINA_COST and stamina_spent < player.WALL_JUMP_STAMINA_COST + 0.05)
	Input.action_release(&"left")
	Input.action_press(&"right")
	var reached_opposite := false
	for _frame in 32:
		await physics_frame
		if player.is_on_wall() and player.get_wall_normal().x < 0.0:
			reached_opposite = true
			break
	assert(reached_opposite)
	await physics_frame
	assert(player.wall_jump_available)
	player.call("_launch_wall_jump", player.get_wall_normal())
	await physics_frame
	assert(player.velocity.x < -300.0)
	_release_inputs()
	(setup.root as Node).free()
	await process_frame


func _test_large_gap_is_not_reached_during_ascent() -> void:
	var setup := _build_test_shaft(320.0)
	var player := setup.player as CharacterBody2D
	Input.action_press(&"left")
	player.velocity.x = -80.0
	await physics_frame
	await physics_frame
	assert(player.is_on_wall())
	player.call("_launch_wall_jump", player.get_wall_normal())
	await physics_frame
	Input.action_release(&"left")
	Input.action_press(&"right")
	var reached_during_ascent := false
	while player.velocity.y < 0.0:
		await physics_frame
		if player.is_on_wall() and player.get_wall_normal().x < 0.0:
			reached_during_ascent = true
			break
	assert(not reached_during_ascent)
	_release_inputs()
	(setup.root as Node).free()
	await process_frame


func _test_procedural_shaft_contract() -> void:
	var player := PLAYER_SCENE.instantiate()
	var safe_width: float = player.WALL_TRANSFER_SAFE_SHAFT_WIDTH
	assert(BiomeGenerator.VERTICAL_SHAFT_INNER_WIDTH <= safe_width)
	assert(player.WALL_TRANSFER_ASSIST_DISTANCE == 20.0)
	assert(player.WALL_TRANSFER_GRACE_DURATION < 0.5)
	player.free()
	for test_seed in [81001, 81002, 81003, 81004, 81005]:
		var manager := RUN_MANAGER_SCRIPT.new()
		root.add_child(manager)
		manager.configure_run(&"solo", &"normal")
		manager.prepare_new_run(test_seed)
		var biome := BIOME_SCENE.instantiate()
		root.add_child(biome)
		assert(biome.generate(test_seed, manager))
		var connections := biome.get_node("VerticalConnections") as Node2D
		var groups: Dictionary = {}
		for body_value: Variant in connections.get_children():
			var body := body_value as StaticBody2D
			var collision := body.get_child(0) as CollisionShape2D
			var size := (collision.shape as RectangleShape2D).size
			var key := "%0.2f:%0.2f" % [body.position.y, size.y]
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append({"x": body.position.x, "width": size.x})
		for values_value: Variant in groups.values():
			var values := values_value as Array
			values.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.x) < float(second.x))
			assert(values.size() % 2 == 0)
			for index in range(0, values.size(), 2):
				var left := values[index] as Dictionary
				var right := values[index + 1] as Dictionary
				var inner_width := float(right.x) - float(right.width) * 0.5 - (float(left.x) + float(left.width) * 0.5)
				assert(inner_width <= safe_width)
		biome.free()
		manager.free()


func _build_test_shaft(inner_width: float) -> Dictionary:
	var holder := Node2D.new()
	root.add_child(holder)
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	var capsule := (player.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	var center_x := 400.0
	var left_inner_x := center_x - inner_width * 0.5
	player.global_position = Vector2(left_inner_x + capsule.radius + 0.5, 320.0)
	_add_wall(holder, left_inner_x - 9.0, 320.0)
	_add_wall(holder, center_x + inner_width * 0.5 + 9.0, 320.0)
	return {"root": holder, "player": player}


func _add_wall(parent: Node2D, x: float, y: float) -> void:
	var wall := StaticBody2D.new()
	wall.position = Vector2(x, y)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 640.0)
	collision.shape = shape
	wall.add_child(collision)
	parent.add_child(wall)


func _release_inputs() -> void:
	for action in [&"left", &"right", &"jump"]:
		Input.action_release(action)
