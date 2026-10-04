extends SceneTree

const RANGED_SCENE := preload("res://entities/RangedEnemy.tscn")
const COMMON_SCENE := preload("res://entities/Enemy.tscn")
const HEAVY_SCENE := preload("res://entities/HeavyEnemy.tscn")
const PROJECTILE_SCENE := preload("res://entities/ranged_projectile.tscn")
const V2_PATH := "res://assets/enemies/ranged/v2/"
const EXPECTED_SHEETS := {
	&"idle": ["ranged_idle_v2.png", 416, 136, 4, 104],
	&"walk": ["ranged_walk_run_v2.png", 816, 136, 6, 136],
	&"attack": ["ranged_attack_shoot_v2.png", 768, 136, 6, 128],
	&"air": ["ranged_jump_air_fall_v2.png", 480, 136, 4, 120],
	&"hurt": ["ranged_hurt_v2.png", 240, 136, 2, 120],
	&"death": ["ranged_death_v2.png", 672, 136, 3, 224],
}
const EXPECTED_HASHES := {
	"ranged_idle_v2.png": "d0dd47a2c890d17b7771efa374c98a504ae51b98a8a3025740f3bccbf5d8fa84",
	"ranged_walk_run_v2.png": "284d6849ec1f4e97921b97248b4653d7a824544129c911ebacabe9ad136d6fc0",
	"ranged_attack_shoot_v2.png": "75365ddb115eee799947a67b86d299ea06539d48a997807846f8b81025447f94",
	"ranged_jump_air_fall_v2.png": "f5fea729870238b48fec9783d6ffba65540f206f3fb03a68566f0aa9305c3fc8",
	"ranged_hurt_v2.png": "13c4a9c14714a5b7a230bc2428e3ebc44d4b97f35e4e3db79cfeba3bf1a6bb2a",
	"ranged_death_v2.png": "cca38f508f771332184ebbae7bcde882f893801e7f9c774fe069a1c202ffdc0d",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_source_files()
	await _validate_ranged_scene_contract()
	await _validate_unrelated_enemy_visuals()
	await _validate_legacy_projectile_contract()
	print("RANGED_ENEMY_REBUILD_V2_SMOKE_TEST_PASSED")
	quit(0)


func _validate_source_files() -> void:
	assert(FileAccess.file_exists(V2_PATH + "manifest.json"))
	assert(FileAccess.get_sha256(V2_PATH + "manifest.json") == "67e8c6e52aa6f5b1002d9ffb9e118bbeb22ded965d3b7245ddc038f104b1c363")
	for file_name: String in EXPECTED_HASHES:
		var path := V2_PATH + file_name
		assert(FileAccess.file_exists(path))
		assert(FileAccess.get_sha256(path) == EXPECTED_HASHES[file_name])
		var texture := load(path) as Texture2D
		var image := texture.get_image()
		assert(image != null and image.get_format() == Image.FORMAT_RGBA8)
		assert(image.detect_alpha() != Image.ALPHA_NONE)
	assert(not FileAccess.file_exists(V2_PATH + "ranged_projectile_movement_v2.png"))
	assert(not FileAccess.file_exists(V2_PATH + "ranged_projectile_impact_v2.png"))


func _validate_ranged_scene_contract() -> void:
	var enemy := RANGED_SCENE.instantiate() as CharacterBody2D
	var collision := enemy.get_node("CollisionShape2D") as CollisionShape2D
	var attack_cast := enemy.get_node("MeleeShapeCast") as ShapeCast2D
	var initial_collision_transform := collision.transform
	var initial_collision_shape := collision.shape
	var initial_cast_transform := attack_cast.transform
	var initial_cast_shape := attack_cast.shape
	enemy.set_physics_process(false)
	root.add_child(enemy)
	await process_frame
	var initial_transform := enemy.transform
	var visual := enemy.get_node("EnemyCharacterVisual") as EnemyCharacterVisual
	assert(visual.character_kind == "ranged")
	assert(visual.sprite_frames.get_animation_names().size() == 6)
	var total_frames := 0
	for animation_value: Variant in EXPECTED_SHEETS:
		var animation_name := StringName(animation_value)
		var contract: Array = EXPECTED_SHEETS[animation_name]
		var texture := load(V2_PATH + String(contract[0])) as Texture2D
		assert(texture.get_width() == int(contract[1]))
		assert(texture.get_height() == int(contract[2]))
		assert(texture.get_width() % int(contract[3]) == 0)
		assert(texture.get_width() / int(contract[3]) == int(contract[4]))
		assert(visual.sprite_frames.get_frame_count(animation_name) == int(contract[3]))
		total_frames += int(contract[3])
		_validate_regions(visual.sprite_frames, animation_name, int(contract[4]), int(contract[2]))
	assert(total_frames == 25)
	assert(visual.sprite_frames.get_frame_count(&"attack") == 6)
	assert(is_equal_approx(visual.sprite_frames.get_animation_speed(&"attack"), 7.0))
	assert(visual.scale == Vector2.ONE)
	assert(visual.position == Vector2(0.0, -39.0))
	visual._apply_alignment(&"idle")
	assert(visual.offset == Vector2(0.0, -11.0))
	assert(is_equal_approx(visual.position.y + (132.0 - 68.0) + visual.offset.y, 14.0))
	visual._apply_alignment(&"air")
	assert(visual.offset == Vector2.ZERO)
	assert(is_equal_approx(68.0 - 68.0, 0.0))
	assert(enemy.transform == initial_transform)
	assert(collision.transform == initial_collision_transform)
	assert(collision.shape == initial_collision_shape)
	assert(attack_cast.transform == initial_cast_transform)
	assert(attack_cast.shape == initial_cast_shape)
	assert(is_equal_approx(enemy.move_speed, 90.0))
	assert(is_equal_approx(enemy.melee_distance, 72.0))
	assert(is_equal_approx(enemy.ranged_distance, 88.0))
	assert(is_equal_approx(enemy.aim_windup, 0.50))
	assert(is_equal_approx(enemy.aim_lock_before_shot, 0.12))
	assert(is_equal_approx(enemy.attack_recovery, 0.35))
	assert(is_equal_approx(enemy.attack_cooldown, 1.20))
	assert(enemy.projectile_damage == CombatStats.RANGED_PROJECTILE_BASE_DAMAGE)
	assert(enemy.melee_damage == CombatStats.RANGED_MELEE_BASE_DAMAGE)
	enemy.free()


func _validate_unrelated_enemy_visuals() -> void:
	var common := COMMON_SCENE.instantiate() as CharacterBody2D
	common.set_physics_process(false)
	root.add_child(common)
	await process_frame
	var common_visual := common.get_node("EnemyCharacterVisual") as EnemyCharacterVisual
	var common_idle := common_visual.sprite_frames.get_frame_texture(&"idle", 0) as AtlasTexture
	assert(common_idle.atlas.resource_path == "res://assets/enemies/common/v2/common_idle_v2.png")
	common.free()
	var heavy := HEAVY_SCENE.instantiate() as CharacterBody2D
	heavy.set_physics_process(false)
	root.add_child(heavy)
	await process_frame
	var heavy_visual := heavy.get_node("EnemyCharacterVisual") as EnemyCharacterVisual
	var heavy_idle := heavy_visual.sprite_frames.get_frame_texture(&"idle", 0) as AtlasTexture
	assert(heavy_idle.atlas.resource_path == "res://assets/enemies/heavy/heavy_idle_v1.png")
	heavy.free()


func _validate_legacy_projectile_contract() -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	root.add_child(projectile)
	await process_frame
	assert(projectile.projectile_type == "ranged")
	var movement := projectile.projectile_visual.sprite_frames.get_frame_texture(&"movement", 0) as AtlasTexture
	var impact := projectile.projectile_visual.sprite_frames.get_frame_texture(&"impact", 0) as AtlasTexture
	assert(movement.atlas.resource_path == "res://assets/enemies/ranged/projectile/ranged_projectile_movement_v1.png")
	assert(impact.atlas.resource_path == "res://assets/enemies/ranged/projectile/ranged_projectile_impact_v1.png")
	assert(projectile.projectile_visual.sprite_frames.get_frame_count(&"movement") == 8)
	assert(projectile.projectile_visual.sprite_frames.get_frame_count(&"impact") == 6)
	projectile.free()


func _validate_regions(frames: SpriteFrames, animation_name: StringName, cell_width: int, cell_height: int) -> void:
	for frame_index in frames.get_frame_count(animation_name):
		var atlas := frames.get_frame_texture(animation_name, frame_index) as AtlasTexture
		assert(atlas != null and atlas.atlas != null)
		assert(atlas.region == Rect2(frame_index * cell_width, 0, cell_width, cell_height))
		assert(atlas.region.end.x <= atlas.atlas.get_width())
		assert(atlas.region.end.y <= atlas.atlas.get_height())
