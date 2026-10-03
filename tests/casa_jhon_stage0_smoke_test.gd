extends SceneTree
## Run after import using --headless --path . --script and this resource path.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hub: Node2D = load("res://scene/casa_jhon_hub.tscn").instantiate()
	root.add_child(hub)
	assert(hub.get_hub_bounds() == Rect2(0, 0, 2560, 768))
	assert(hub.get_node("Gameplay/P1Spawn") is Marker2D)
	assert(hub.get_node("Gameplay/P2Spawn") is Marker2D)
	var portal: Area2D = hub.get_node("Gameplay/RunPortal")
	var terminal: Area2D = hub.get_node("Gameplay/MetaTerminal")
	assert(portal.has_method("interact") and terminal.has_method("interact"))
	assert(portal.is_in_group("interactable") and terminal.is_in_group("interactable"))
	var bodies: Array[CharacterBody2D] = []
	for index in 4:
		var body := CharacterBody2D.new()
		var collider := CollisionShape2D.new()
		var shape := CapsuleShape2D.new()
		shape.radius = 8.0
		shape.height = 32.0
		collider.shape = shape
		body.add_child(collider)
		hub.add_child(body)
		body.position = Vector2(1060 + index * 40, 620)
		bodies.append(body)
	await physics_frame
	await physics_frame
	for body in bodies:
		assert(portal.overlaps_body(body), "Portal must accommodate all four participants")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(1280, 650)
	query.collision_mask = 1
	assert(not hub.get_world_2d().direct_space_state.intersect_point(query).is_empty())
	hub.queue_free()
	await process_frame
	print("CASA_JHON_STAGE0_SMOKE_TEST_OK")
	quit()
