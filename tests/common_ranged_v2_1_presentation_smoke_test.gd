extends SceneTree

const COMMON_SCENE := preload("res://entities/Enemy.tscn")
const RANGED_SCENE := preload("res://entities/RangedEnemy.tscn")
const COMMON_PATH := "res://assets/enemies/common/v2/"
const RANGED_PATH := "res://assets/enemies/ranged/v2/"
const COMMON_HASHES := {
	"common_idle_v2.png": "5375acc7c96428e3f589b47023f047b45caf424a9dde116e37a4f50eacf922a4",
	"common_walk_run_v2.png": "2aac02e262abe807de975c180388772c3a1b33343e80b4f1c2b84b82cde7c16d",
	"common_attack_v2.png": "7e4383965bdb0e0fc48bbcc2b7a70a2d3dd39538cb2e7050e19938ad637ff376",
	"common_jump_air_fall_v2.png": "ea8dc96b402dd9b971ea1c5fa654047ea4de701d6115299e669631d3a60765be",
	"common_hurt_v2.png": "8bba5569fa532faf9729b9463d991fad24ea6204d6a328598fc7a7862e76118a",
	"common_death_v2.png": "c11c9dad130a029ce406797dcd2f6c529317d17efaaf1fb4484787131920e167",
}
const RANGED_HASHES := {
	"ranged_idle_v2.png": "d0dd47a2c890d17b7771efa374c98a504ae51b98a8a3025740f3bccbf5d8fa84",
	"ranged_walk_run_v2.png": "284d6849ec1f4e97921b97248b4653d7a824544129c911ebacabe9ad136d6fc0",
	"ranged_attack_shoot_v2.png": "75365ddb115eee799947a67b86d299ea06539d48a997807846f8b81025447f94",
	"ranged_jump_air_fall_v2.png": "f5fea729870238b48fec9783d6ffba65540f206f3fb03a68566f0aa9305c3fc8",
	"ranged_hurt_v2.png": "13c4a9c14714a5b7a230bc2428e3ebc44d4b97f35e4e3db79cfeba3bf1a6bb2a",
	"ranged_death_v2.png": "cca38f508f771332184ebbae7bcde882f893801e7f9c774fe069a1c202ffdc0d",
}
const EXPECTED_COUNTS := {
	&"common": {&"idle": 4, &"walk": 6, &"attack": 5, &"air": 4, &"hurt": 2, &"death": 3},
	&"ranged": {&"idle": 4, &"walk": 6, &"attack": 6, &"air": 4, &"hurt": 2, &"death": 3},
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_asset_integrity()
	await _validate_common_presentation()
	await _validate_ranged_presentation_and_muzzle()
	print("COMMON_RANGED_V2_1_PRESENTATION_SMOKE_TEST_PASSED")
	quit(0)


func _validate_asset_integrity() -> void:
	for file_name: String in COMMON_HASHES:
		assert(FileAccess.get_sha256(COMMON_PATH + file_name) == COMMON_HASHES[file_name])
	for file_name: String in RANGED_HASHES:
		assert(FileAccess.get_sha256(RANGED_PATH + file_name) == RANGED_HASHES[file_name])
	assert(not FileAccess.file_exists(RANGED_PATH + "ranged_projectile_movement_v2.png"))
	assert(not FileAccess.file_exists(RANGED_PATH + "ranged_projectile_impact_v2.png"))


func _validate_common_presentation() -> void:
	var enemy := COMMON_SCENE.instantiate() as CharacterBody2D
	var collision := enemy.get_node("CollisionShape2D") as CollisionShape2D
	var attack_cast := enemy.get_node("AttackShapeCast") as ShapeCast2D
	var collision_transform := collision.transform
	var collision_shape := collision.shape
	var attack_transform := attack_cast.transform
	var attack_shape := attack_cast.shape
	enemy.set_physics_process(false)
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	var body_transform := enemy.transform
	var visual := enemy.get_node("EnemyCharacterVisual") as EnemyCharacterVisual
	_validate_animation_contract(visual, &"common", COMMON_PATH)
	assert(visual.scale == Vector2.ONE)
	assert(visual.position == Vector2(0.0, -33.0))
	visual.animation = &"idle"
	var expected_offsets: Array[float] = [-8.0, 0.0, 0.0, 0.0]
	for frame_index in expected_offsets.size():
		visual.frame = frame_index
		visual.flip_h = false
		visual._apply_alignment(&"idle")
		assert(visual.offset == Vector2(expected_offsets[frame_index], -7.0))
		var right_world_compensation := visual.offset.x
		visual.flip_h = true
		visual._apply_alignment(&"idle")
		assert(visual.offset == Vector2(expected_offsets[frame_index], -7.0))
		var left_world_compensation := -visual.offset.x
		assert(is_equal_approx(left_world_compensation, -right_world_compensation))
	for animation_name: StringName in [&"walk", &"attack", &"air", &"hurt", &"death"]:
		for frame_index in visual.sprite_frames.get_frame_count(animation_name):
			visual.animation = animation_name
			visual.frame = frame_index
			visual._apply_alignment(animation_name)
			assert(is_zero_approx(visual.offset.x))
			assert(is_equal_approx(visual.offset.y, 0.0 if animation_name == &"air" else -7.0))
	assert(enemy.transform == body_transform)
	assert(collision.transform == collision_transform and collision.shape == collision_shape)
	assert(attack_cast.transform == attack_transform and attack_cast.shape == attack_shape)
	assert(enemy.max_health == CombatStats.COMMON_ENEMY_BASE_HP)
	assert(enemy.attack_damage == CombatStats.COMMON_ENEMY_BASE_DAMAGE)
	assert(is_equal_approx(enemy.move_speed, 100.0))
	enemy.free()


func _validate_ranged_presentation_and_muzzle() -> void:
	var enemy := RANGED_SCENE.instantiate() as CharacterBody2D
	var collision := enemy.get_node("CollisionShape2D") as CollisionShape2D
	var attack_cast := enemy.get_node("MeleeShapeCast") as ShapeCast2D
	var collision_transform := collision.transform
	var collision_shape := collision.shape
	var attack_transform := attack_cast.transform
	var attack_shape := attack_cast.shape
	enemy.set_physics_process(false)
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	var visual := enemy.get_node("EnemyCharacterVisual") as EnemyCharacterVisual
	var facing_source := enemy.get_node("Visual") as Node2D
	var muzzle := enemy.get_node("Visual/Muzzle") as Marker2D
	var aim_line := enemy.get_node("AimLine") as Line2D
	_validate_animation_contract(visual, &"ranged", RANGED_PATH)
	assert(visual.scale == Vector2.ONE)
	assert(visual.position == Vector2(0.0, -39.0))
	var ranged_counts: Dictionary = EXPECTED_COUNTS[&"ranged"]
	for animation_name: StringName in ranged_counts:
		for frame_index in visual.sprite_frames.get_frame_count(animation_name):
			visual.animation = animation_name
			visual.frame = frame_index
			visual._apply_alignment(animation_name)
			assert(is_zero_approx(visual.offset.x))
			assert(is_equal_approx(visual.offset.y, 0.0 if animation_name == &"air" else -11.0))
	enemy.global_position = Vector2(300.0, 300.0)
	facing_source.scale = Vector2(1.1, 1.1)
	var right_origin := muzzle.global_position
	assert(right_origin.is_equal_approx(enemy.global_position + Vector2(51.0, -83.0)))
	assert(right_origin.y < enemy.global_position.y - 40.0)
	enemy._update_aim_line(Vector2.RIGHT)
	assert(aim_line.points[0].is_equal_approx(enemy.to_local(right_origin)))
	facing_source.scale.x = -1.1
	var left_origin := muzzle.global_position
	assert(left_origin.is_equal_approx(enemy.global_position + Vector2(-51.0, -83.0)))
	assert(is_equal_approx(left_origin.x - enemy.global_position.x, -(right_origin.x - enemy.global_position.x)))
	enemy._update_aim_line(Vector2.LEFT)
	assert(aim_line.points[0].is_equal_approx(enemy.to_local(left_origin)))
	await _validate_projectile_spawn(enemy, facing_source, muzzle, Vector2.RIGHT)
	await _validate_projectile_spawn(enemy, facing_source, muzzle, Vector2.LEFT)
	assert(collision.transform == collision_transform and collision.shape == collision_shape)
	assert(attack_cast.transform == attack_transform and attack_cast.shape == attack_shape)
	assert(is_equal_approx(enemy.move_speed, 90.0))
	assert(is_equal_approx(enemy.aim_windup, 0.50))
	assert(is_equal_approx(enemy.aim_lock_before_shot, 0.12))
	assert(is_equal_approx(enemy.attack_recovery, 0.35))
	assert(is_equal_approx(enemy.attack_cooldown, 1.20))
	assert(is_equal_approx(enemy.projectile_speed, 420.0))
	assert(enemy.projectile_damage == CombatStats.RANGED_PROJECTILE_BASE_DAMAGE)
	enemy.free()


func _validate_projectile_spawn(enemy: CharacterBody2D, facing_source: Node2D, muzzle: Marker2D, direction: Vector2) -> void:
	facing_source.scale.x = absf(facing_source.scale.x) * direction.x
	enemy.shot_spawned = false
	enemy.is_attacking = true
	enemy.state = enemy.State.SHOOT
	enemy.locked_direction = direction
	var expected_origin := muzzle.global_position
	enemy._fire_once()
	var projectiles := root.get_children().filter(func(node: Node) -> bool: return node.get_script() == load("res://entities/ranged_projectile.gd"))
	assert(projectiles.size() == 1)
	var projectile := projectiles[0] as CharacterBody2D
	assert(projectile.global_position.is_equal_approx(expected_origin))
	assert(projectile.direction == direction)
	assert(is_equal_approx(float(projectile.speed), 420.0))
	assert(int(projectile.damage) == CombatStats.RANGED_PROJECTILE_BASE_DAMAGE)
	assert(is_equal_approx(float(projectile.maximum_lifetime), 3.0))
	var projectile_visual := projectile.get_node("ProjectileVisual") as ProjectileVisual
	var movement := projectile_visual.sprite_frames.get_frame_texture(&"movement", 0) as AtlasTexture
	var impact := projectile_visual.sprite_frames.get_frame_texture(&"impact", 0) as AtlasTexture
	assert(movement.atlas.resource_path == "res://assets/enemies/ranged/projectile/ranged_projectile_movement_v1.png")
	assert(impact.atlas.resource_path == "res://assets/enemies/ranged/projectile/ranged_projectile_impact_v1.png")
	projectile.free()
	await process_frame


func _validate_animation_contract(visual: EnemyCharacterVisual, kind: StringName, expected_path: String) -> void:
	var counts: Dictionary = EXPECTED_COUNTS[kind]
	assert(visual.sprite_frames.get_animation_names().size() == 6)
	for animation_name: StringName in counts:
		assert(visual.sprite_frames.get_frame_count(animation_name) == int(counts[animation_name]))
		for frame_index in visual.sprite_frames.get_frame_count(animation_name):
			var atlas := visual.sprite_frames.get_frame_texture(animation_name, frame_index) as AtlasTexture
			assert(atlas != null and atlas.atlas != null)
			assert(atlas.atlas.resource_path.begins_with(expected_path))
			assert(atlas.region.position.x >= 0.0 and atlas.region.end.x <= atlas.atlas.get_width())
			assert(atlas.region.position.y >= 0.0 and atlas.region.end.y <= atlas.atlas.get_height())
