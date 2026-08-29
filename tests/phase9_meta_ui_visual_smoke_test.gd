extends SceneTree

const MAIN_SCENE := preload("res://scene/main.tscn")
const PLAYER_SCENE := preload("res://entities/player.tscn")
const COMMON_SCENE := preload("res://entities/Enemy.tscn")
const RANGED_SCENE := preload("res://entities/RangedEnemy.tscn")
const HEAVY_SCENE := preload("res://entities/HeavyEnemy.tscn")
const META_SCRIPT := preload("res://scene/meta_progression.gd")
const WEAPON_PICKUP_SCRIPT := preload("res://scene/weapons/weapon_pickup.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_save_load_legacy_and_deduplication()
	await _test_ui_and_visual_contracts()
	print("PHASE9_META_UI_VISUAL_SMOKE_TEST_OK")
	quit(0)


func _test_save_load_legacy_and_deduplication() -> void:
	var path := "user://phase9_meta_test_%d.json" % Time.get_ticks_usec()
	var meta := META_SCRIPT.new() as MetaProgression
	meta.save_path = path
	root.add_child(meta)
	meta.credits = 500
	assert(meta.purchase(&"arc_emitter"))
	var result := {"run_id": "phase9-test-run", "completed": true, "elapsed_time": 90.0, "money_earned": 200, "stage_index": 5, "boss_defeated": true}
	assert(meta.record_run(result) == 40)
	assert(meta.record_run(result) == 0)
	assert(meta.statistics.runs == 1 and meta.statistics.victories == 1 and meta.statistics.bosses_defeated == 1)
	assert(meta.save_profile())
	var loaded := META_SCRIPT.new() as MetaProgression
	loaded.save_path = path
	root.add_child(loaded)
	loaded.load_profile()
	assert(loaded.credits == 320 and loaded.unlocked_weapons.has(&"arc_emitter"))
	assert(loaded.get_run_weapon_pool().has(&"breaker_maul") and loaded.get_run_weapon_pool().has(&"arc_emitter"))
	var legacy_path := "user://phase9_meta_legacy_%d.json" % Time.get_ticks_usec()
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"money": 77, "unlocked_weapons": "arc_emitter"}))
	legacy_file.close()
	var legacy := META_SCRIPT.new() as MetaProgression
	legacy.save_path = legacy_path
	root.add_child(legacy)
	legacy.load_profile()
	assert(legacy.credits == 77 and legacy.unlocked_weapons.has(&"arc_emitter"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	meta.free()
	loaded.free()
	legacy.free()


func _test_ui_and_visual_contracts() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	assert(main.has_node("MetaProgression") and main.has_node("MetaLabUI") and main.has_node("RunResultUI"))
	var run_manager: Node = main.get_node("RunManager")
	run_manager.call("configure_run_weapon_pool", [&"arc_emitter"])
	run_manager.call("prepare_new_run", 900009, true)
	assert((run_manager.get("run_weapon_pool") as Array) == [&"arc_emitter"])
	await _test_player_color_variants()
	var scenes: Array[PackedScene] = [PLAYER_SCENE, COMMON_SCENE, RANGED_SCENE, HEAVY_SCENE]
	for packed_scene: PackedScene in scenes:
		var actor := packed_scene.instantiate() as CharacterBody2D
		root.add_child(actor)
		await process_frame
		var collision := actor.get_node("CollisionShape2D") as CollisionShape2D
		assert(collision.shape != null)
		assert(actor.has_node("TempPixelVisual"))
		var visual := actor.get_node("TempPixelVisual") as TempPixelVisual
		assert(visual.z_index == 2)
		assert(visual.find_children("*", "CollisionObject2D", true, false).is_empty())
		actor.free()
	var pickup := WEAPON_PICKUP_SCRIPT.new() as WeaponPickup
	pickup.weapon_id = &"arc_emitter"
	root.add_child(pickup)
	await process_frame
	assert(pickup.has_node("TempWeaponSprite"))
	pickup.free()
	main.free()
	await process_frame


func _test_player_color_variants() -> void:
	var expected_variants: Array[StringName] = [&"original", &"orange", &"white", &"red"]
	var expected_frames: Dictionary = {&"idle": 4, &"walk": 8, &"jump": 5, &"attack": 5, &"dash": 5, &"fall": 6, &"wall_slide": 6}
	for participant_index in 4:
		var player := PLAYER_SCENE.instantiate() as CharacterBody2D
		player.set("participant_id", StringName("player_%d" % (participant_index + 1)))
		root.add_child(player)
		await process_frame
		var visual := player.get_node("JhonIdleVisual") as JhonIdleVisual
		assert(StringName(visual.get("_active_variant")) == expected_variants[participant_index])
		assert(visual.scale.is_equal_approx(Vector2(1.333333, 1.333333)))
		assert(visual.position.is_equal_approx(Vector2(0.0, -31.666655)))
		assert(visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		for animation_value: Variant in expected_frames:
			var animation_name: StringName = StringName(animation_value)
			assert(visual.sprite_frames.has_animation(animation_name))
			assert(visual.sprite_frames.get_frame_count(animation_name) == int(expected_frames[animation_name]))
		assert(not visual.sprite_frames.get_animation_loop(&"fall"))
		assert(visual.sprite_frames.get_animation_loop(&"wall_slide"))
		var state_source := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
		state_source.animation = &"jump"
		player.velocity = Vector2(0.0, -180.0)
		visual._update_presentation()
		assert(visual.visible and visual.animation == &"jump")
		player.velocity.y = 180.0
		visual._update_presentation()
		assert(visual.visible and visual.animation == &"fall")
		assert(not visual._is_wall_slide_visual_state(player))
		player.free()
