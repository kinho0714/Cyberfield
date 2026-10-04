extends SceneTree

const PLAYER_SCENE := preload("res://entities/player.tscn")
const COMMON_SCENE := preload("res://entities/Enemy.tscn")
const RANGED_SCENE := preload("res://entities/RangedEnemy.tscn")
const HEAVY_SCENE := preload("res://entities/HeavyEnemy.tscn")
const RANGED_PROJECTILE_SCENE := preload("res://entities/ranged_projectile.tscn")
const HEAVY_PROJECTILE_SCENE := preload("res://entities/heavy_projectile.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_players()
	await _test_enemies()
	await _test_projectiles_and_heavy_attack()
	print("OFFICIAL_VISUAL_INTEGRATION_SMOKE_TEST_OK")
	quit(0)


func _test_players() -> void:
	var character_ids: Array[StringName] = [&"jhon", &"jackson", &"kai", &"spark"]
	for index in 4:
		var player := PLAYER_SCENE.instantiate() as CharacterBody2D
		player.participant_id = StringName("player_%d" % (index + 1))
		root.add_child(player)
		await process_frame
		var visual := player.get_node("PlayerCharacterVisual") as PlayerCharacterVisual
		assert(StringName(visual.get("_active_character")) == character_ids[index])
		assert(visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		assert(visual.sprite_frames.get_animation_names().size() == 11)
		assert(visual.sprite_frames.get_frame_count(&"attack") == (5 if index == 0 else 6))
		for animation_name in [&"idle", &"walk", &"air", &"attack", &"dash", &"ground_slam", &"hurt", &"downed", &"revive", &"wall_slide", &"wall_climb"]:
			assert(visual.sprite_frames.has_animation(animation_name))
			_assert_regions_inside_texture(visual.sprite_frames, animation_name)
		assert((player.get_node("CollisionShape2D") as CollisionShape2D).shape is CapsuleShape2D)
		assert((player.get_node("AttackShapeCast") as ShapeCast2D).shape is RectangleShape2D)
		assert((player.get_node("GroundSlamShapeCast") as ShapeCast2D).shape is RectangleShape2D)
		player.is_ground_slamming = true
		visual._update_presentation()
		assert(visual.animation == &"ground_slam")
		player.is_ground_slamming = false
		player.is_hurt = true
		visual._update_presentation()
		assert(visual.animation == &"hurt")
		player.is_hurt = false
		player.is_downed = true
		visual._update_presentation()
		assert(visual.animation == &"downed")
		player.is_downed = false
		var ally := CharacterBody2D.new()
		root.add_child(ally)
		player.set("_revive_target", ally)
		visual._update_presentation()
		assert(visual.animation == &"revive")
		player.set("_revive_target", null)
		ally.free()
		player.free()


func _test_enemies() -> void:
	var scenes: Array[PackedScene] = [COMMON_SCENE, RANGED_SCENE, HEAVY_SCENE]
	var kinds: Array[String] = ["common", "ranged", "heavy"]
	for index in scenes.size():
		var enemy := scenes[index].instantiate() as CharacterBody2D
		root.add_child(enemy)
		await process_frame
		var visual := enemy.get_node("EnemyCharacterVisual") as EnemyCharacterVisual
		assert(visual.character_kind == kinds[index])
		assert(visual.sprite_frames.get_animation_names().size() == 6)
		assert(visual.sprite_frames.get_frame_count(&"attack") == (5 if index == 0 else 6))
		if index == 1:
			var ranged_idle := visual.sprite_frames.get_frame_texture(&"idle", 0) as AtlasTexture
			assert(ranged_idle.atlas.resource_path == "res://assets/enemies/ranged/v2/ranged_idle_v2.png")
		for animation_name in [&"idle", &"walk", &"attack", &"air", &"hurt", &"death"]:
			assert(visual.sprite_frames.has_animation(animation_name))
			_assert_regions_inside_texture(visual.sprite_frames, animation_name)
		assert((enemy.get_node("CollisionShape2D") as CollisionShape2D).shape is CapsuleShape2D)
		enemy.free()


func _test_projectiles_and_heavy_attack() -> void:
	var ranged := RANGED_PROJECTILE_SCENE.instantiate()
	root.add_child(ranged)
	await process_frame
	assert(ranged.projectile_type == "ranged")
	assert(ranged.projectile_visual.sprite_frames.get_frame_count(&"movement") == 8)
	assert(ranged.projectile_visual.sprite_frames.get_frame_count(&"impact") == 6)
	ranged.free()
	var heavy_projectile := HEAVY_PROJECTILE_SCENE.instantiate()
	root.add_child(heavy_projectile)
	await process_frame
	assert(heavy_projectile.projectile_type == "heavy")
	assert(heavy_projectile.projectile_visual.sprite_frames.get_frame_count(&"movement") == 8)
	assert(heavy_projectile.projectile_visual.sprite_frames.get_frame_count(&"impact") == 6)
	heavy_projectile.free()
	var heavy := HEAVY_SCENE.instantiate() as HeavyEnemy
	root.add_child(heavy)
	await process_frame
	assert(heavy.ranged_min_distance > heavy.attack_horizontal_range)
	assert(heavy.ranged_max_distance > heavy.ranged_min_distance)
	assert(heavy.shoot_windup >= 0.8 and heavy.shoot_cooldown >= 2.0)
	assert(heavy.projectile_speed < 420.0)
	var target := PLAYER_SCENE.instantiate() as CharacterBody2D
	target.participant_id = &"player_1"
	root.add_child(target)
	heavy.global_position = Vector2(100, 100)
	target.global_position = Vector2(350, 100)
	await physics_frame
	heavy.set_physics_process(false)
	target.set_physics_process(false)
	heavy.player = target
	assert(heavy.has_method("_has_shot_line_of_sight"))
	heavy._begin_ranged_attack()
	assert(heavy.ranged_phase == heavy.RangedPhase.WINDUP and heavy.is_attacking)
	heavy._cancel_ranged_attack(false)
	heavy.ranged_phase = heavy.RangedPhase.WINDUP
	heavy.is_attacking = true
	heavy.take_damage(1)
	assert(heavy.ranged_phase == heavy.RangedPhase.READY)
	heavy.locked_shot_direction = Vector2.RIGHT
	heavy._fire_heavy_projectile()
	var spawned := root.get_children().filter(func(node: Node) -> bool: return node is HeavyProjectile)
	assert(spawned.size() == 1)
	(spawned[0] as Node).free()
	target.free()
	heavy.free()


func _assert_regions_inside_texture(frames: SpriteFrames, animation_name: StringName) -> void:
	for frame_index in frames.get_frame_count(animation_name):
		var atlas := frames.get_frame_texture(animation_name, frame_index) as AtlasTexture
		assert(atlas != null and atlas.atlas != null)
		assert(atlas.region.position.x >= 0.0 and atlas.region.end.x <= atlas.atlas.get_width())
		assert(atlas.region.position.y >= 0.0 and atlas.region.end.y <= atlas.atlas.get_height())
