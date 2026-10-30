extends SceneTree
## 30/10: combat feedback is presentation only and obeys the visual effects profile.
## Run separately with Godot --headless --path . --script res://tests/combat_fx_smoke_test.gd

const ENEMY_SCENE := preload("res://entities/Enemy.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous := VisualQuality.profile()
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	world.add_child(camera)
	camera.make_current()
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	world.add_child(enemy)
	enemy.global_position = camera.global_position
	await process_frame

	VisualQuality.set_profile(VisualQuality.FULL)
	var health_before: int = enemy.health
	var children_before := world.get_child_count()
	CombatFx.enemy_hit(enemy, 1.0, true)
	var visual := enemy.get_node("EnemyCharacterVisual") as CanvasItem
	assert(visual.self_modulate != Color.WHITE, "hit flash missing")
	assert(world.get_child_count() > children_before, "hit sparks missing")
	assert(not world.find_children("*", "AnimatedSprite2D", false, false).is_empty(), "pixel-art hit spark missing")
	assert(camera.has_meta(CombatFx.SHAKE_META), "shake missing in FULL")
	assert(enemy.health == health_before, "feedback must not change gameplay")
	for i in 12:
		await process_frame
	assert(visual.self_modulate.is_equal_approx(Color.WHITE), "flash must settle")
	assert(camera.offset.is_zero_approx(), "shake must settle")

	VisualQuality.set_profile(VisualQuality.MINIMAL)
	camera.remove_meta(CombatFx.SHAKE_META)
	children_before = world.get_child_count()
	CombatFx.enemy_hit(enemy, -1.0, true)
	assert(world.get_child_count() == children_before, "MINIMAL spawns no particles or sheets")
	assert(not camera.has_meta(CombatFx.SHAKE_META), "MINIMAL never shakes")
	assert(visual.self_modulate != Color.WHITE, "MINIMAL keeps the readable sprite flash")

	VisualQuality.set_profile(previous)
	world.queue_free()
	await process_frame
	print("COMBAT_FX_SMOKE_TEST_OK")
	quit(0)
