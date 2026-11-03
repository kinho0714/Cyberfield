extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player: Node = load("res://entities/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.global_position = Vector2(100, 100)
	for path: String in ["Enemy", "HeavyEnemy", "RangedEnemy"]:
		var enemy: Node = load("res://entities/" + path + ".tscn").instantiate()
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.global_position = Vector2(80, 100)
		enemy.player = player
		if path != "RangedEnemy":
			enemy.attack()
			var generation: int = enemy.attack_generation
			enemy._on_detection_area_body_exited(player)
			check(not enemy.is_attacking and enemy.attack_generation > generation, path + " target exit invalidates windup")
			enemy.player = player
			await create_timer(enemy.attack_windup + 0.03).timeout
			check(player.health == player.max_health, "stale attack cannot damage replacement target")
		EnemyStatus.freeze(enemy, 0.5, 0.5, 0.3)
		if path == "RangedEnemy":
			enemy._begin_aim()
		else:
			enemy.attack_cooldown_timer = 0.0
			enemy.attack()
		check(not enemy.is_attacking, path + " cannot restart attack while frozen")
		enemy.queue_free()
		await process_frame
	await create_timer(0.4).timeout
	player.queue_free()
	await process_frame
	print("ENEMY_INTERRUPTION_REPORT failures=", failures)
	quit(0 if failures == 0 else 1)
