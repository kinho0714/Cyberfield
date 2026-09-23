extends SceneTree

const COMMON_SCENE := preload("res://entities/Enemy.tscn")
const V2_PATH := "res://assets/enemies/common/v2/"
const EXPECTED_SHEETS := {
	&"idle": ["common_idle_v2.png", 416, 128, 4, 104],
	&"walk": ["common_walk_run_v2.png", 720, 128, 6, 120],
	&"attack": ["common_attack_v2.png", 920, 128, 5, 184],
	&"air": ["common_jump_air_fall_v2.png", 416, 128, 4, 104],
	&"hurt": ["common_hurt_v2.png", 208, 128, 2, 104],
	&"death": ["common_death_v2.png", 720, 128, 3, 240],
}
const EXPECTED_HASHES := {
	"common_idle_v2.png": "5375acc7c96428e3f589b47023f047b45caf424a9dde116e37a4f50eacf922a4",
	"common_walk_run_v2.png": "2aac02e262abe807de975c180388772c3a1b33343e80b4f1c2b84b82cde7c16d",
	"common_attack_v2.png": "7e4383965bdb0e0fc48bbcc2b7a70a2d3dd39538cb2e7050e19938ad637ff376",
	"common_jump_air_fall_v2.png": "ea8dc96b402dd9b971ea1c5fa654047ea4de701d6115299e669631d3a60765be",
	"common_hurt_v2.png": "8bba5569fa532faf9729b9463d991fad24ea6204d6a328598fc7a7862e76118a",
	"common_death_v2.png": "c11c9dad130a029ce406797dcd2f6c529317d17efaaf1fb4484787131920e167",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_source_files()
	await _validate_common_scene_contract()
	print("COMMON_ENEMY_REBUILD_V2_SMOKE_TEST_PASSED")
	quit(0)


func _validate_source_files() -> void:
	for file_name: String in EXPECTED_HASHES:
		var path := V2_PATH + file_name
		assert(FileAccess.file_exists(path))
		assert(FileAccess.get_sha256(path) == EXPECTED_HASHES[file_name])
		var texture := load(path) as Texture2D
		var image := texture.get_image()
		assert(image != null and image.get_format() == Image.FORMAT_RGBA8)
		assert(image.detect_alpha() != Image.ALPHA_NONE)


func _validate_common_scene_contract() -> void:
	var enemy := COMMON_SCENE.instantiate() as CharacterBody2D
	var collision := enemy.get_node("CollisionShape2D") as CollisionShape2D
	var attack_cast := enemy.get_node("AttackShapeCast") as ShapeCast2D
	enemy.set_physics_process(false)
	root.add_child(enemy)
	await process_frame
	var initial_transform := enemy.transform
	var initial_collision_transform := collision.transform
	var initial_collision_shape := collision.shape
	var initial_cast_transform := attack_cast.transform
	var initial_cast_shape := attack_cast.shape
	var visual := enemy.get_node("EnemyCharacterVisual") as EnemyCharacterVisual
	assert(visual.character_kind == "common")
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
	assert(total_frames == 24)
	assert(visual.sprite_frames.get_frame_count(&"attack") == 5)
	assert(visual.scale == Vector2.ONE)
	assert(visual.position == Vector2(0.0, -33.0))
	enemy.is_attacking = false
	enemy.is_hurt = false
	enemy.is_dead = false
	enemy.velocity = Vector2.ZERO
	visual._apply_alignment(&"idle")
	assert(visual.offset == Vector2(0.0, -7.0))
	assert(is_equal_approx(visual.position.y + (124.0 - 64.0) + visual.offset.y, 20.0))
	visual._apply_alignment(&"air")
	assert(visual.offset == Vector2.ZERO)
	assert(is_equal_approx(64.0 - 64.0, 0.0))
	assert(enemy.transform == initial_transform)
	assert(collision.transform == initial_collision_transform)
	assert(collision.shape == initial_collision_shape)
	assert(attack_cast.transform == initial_cast_transform)
	assert(attack_cast.shape == initial_cast_shape)
	assert(is_equal_approx(enemy.move_speed, 100.0))
	assert(is_equal_approx(enemy.attack_windup, 0.22))
	assert(is_equal_approx(enemy.attack_recovery, 0.30))
	assert(is_equal_approx(enemy.attack_cooldown, 0.45))
	assert(enemy.attack_damage == CombatStats.COMMON_ENEMY_BASE_DAMAGE)
	assert(enemy.max_health == CombatStats.COMMON_ENEMY_BASE_HP)
	enemy.free()


func _validate_regions(frames: SpriteFrames, animation_name: StringName, cell_width: int, cell_height: int) -> void:
	for frame_index in frames.get_frame_count(animation_name):
		var atlas := frames.get_frame_texture(animation_name, frame_index) as AtlasTexture
		assert(atlas != null and atlas.atlas != null)
		assert(atlas.region == Rect2(frame_index * cell_width, 0, cell_width, cell_height))
		assert(atlas.region.end.x <= atlas.atlas.get_width())
		assert(atlas.region.end.y <= atlas.atlas.get_height())
