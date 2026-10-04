extends SceneTree

const PLAYER_SCENE := preload("res://entities/player.tscn")
const EXPECTED_CHARACTERS: Array[StringName] = [&"jhon", &"jackson", &"kai", &"spark"]
const WALL_CENTERS := {
	&"jhon": [4.0, 0.0, -11.0, -6.5],
	&"jackson": [2.0, 0.0, -14.0, -9.0],
	&"kai": [7.0, 14.5, 0.0, -5.0],
	&"spark": [4.5, 0.0, 0.0, -4.5],
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for index in 4:
		await _test_character(index)
	print("PLAYER_VISUAL_PRESENTATION_HOTFIX_SMOKE_TEST_OK")
	quit(0)


func _test_character(index: int) -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.participant_id = StringName("player_%d" % (index + 1))
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var visual := player.get_node("PlayerCharacterVisual") as PlayerCharacterVisual
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var attack_cast := player.get_node("AttackShapeCast") as ShapeCast2D
	var slam_cast := player.get_node("GroundSlamShapeCast") as ShapeCast2D
	var original_player_position := player.global_position
	var original_collision_transform := collision.transform
	var original_collision_shape := collision.shape
	var original_attack_transform := attack_cast.transform
	var original_attack_shape := attack_cast.shape
	var original_slam_transform := slam_cast.transform
	var original_slam_shape := slam_cast.shape
	assert(StringName(visual.get("_active_character")) == EXPECTED_CHARACTERS[index])
	assert(is_equal_approx(visual.scale.x, 1.5) and is_equal_approx(visual.scale.y, 1.5))
	assert(is_equal_approx(visual.position.y, -34.5))
	var rendered_opaque_height := 64.0 * visual.scale.y
	assert(is_equal_approx(rendered_opaque_height, 96.0))
	var idle_feet_y := visual.position.y + (69.0 - 36.0) * visual.scale.y
	assert(is_equal_approx(idle_feet_y, 15.0))
	_test_wall_alignment(visual, EXPECTED_CHARACTERS[index])
	_test_stable_state_and_action_timelines(player, visual)
	assert(player.global_position == original_player_position)
	assert(collision.transform == original_collision_transform and collision.shape == original_collision_shape)
	assert(attack_cast.transform == original_attack_transform and attack_cast.shape == original_attack_shape)
	assert(slam_cast.transform == original_slam_transform and slam_cast.shape == original_slam_shape)
	player.free()


func _test_wall_alignment(visual: PlayerCharacterVisual, character_id: StringName) -> void:
	var centers: Array = WALL_CENTERS[character_id] as Array
	visual.animation = &"wall_slide"
	for is_flipped in [false, true]:
		visual.flip_h = is_flipped
		for frame_index in 4:
			visual.frame = frame_index
			visual._apply_frame_alignment(&"wall_slide")
			var anchored_center := float(centers[frame_index]) + visual.offset.x
			assert(absf(anchored_center) <= 0.01)
			assert(is_equal_approx(visual.offset.y, 1.0))


func _test_stable_state_and_action_timelines(player: CharacterBody2D, visual: PlayerCharacterVisual) -> void:
	player.network_remote_replica = true
	player.network_visual_state = &"idle"
	visual.play(&"idle")
	visual.frame = 2
	visual._update_presentation(0.016)
	assert(visual.animation == &"idle" and visual.frame == 2)
	player.network_remote_replica = false
	player.network_visual_state = &""
	player.is_attacking = true
	player.attack_generation += 1
	var attack_frames: Array[int] = []
	for step in 6:
		visual._update_presentation(0.04 if step > 0 else 0.0)
		attack_frames.append(visual.frame)
	_assert_monotonic(attack_frames)
	player.attack_generation += 1
	visual._update_presentation(0.0)
	assert(visual.frame == 0)
	player.is_attacking = false
	visual._update_presentation(0.25)
	player.dash_timer = 0.15
	var dash_frames: Array[int] = []
	for step in 5:
		visual._update_presentation(0.045 if step > 0 else 0.0)
		dash_frames.append(visual.frame)
	_assert_monotonic(dash_frames)
	player.dash_timer = 0.0
	visual.set("_was_airborne", false)
	assert(visual._stable_air_frame(1, 0.0, 0.0) == 1)
	assert(visual._stable_air_frame(2, 100.0, 0.08) == 2)
	assert(visual._stable_air_frame(1, 40.0, 0.20) == 2)
	assert(visual._stable_air_frame(0, -200.0, 0.01) == 0)
	player.is_ground_slamming = true
	visual._update_presentation(0.0)
	assert(visual.animation == &"ground_slam" and visual.frame == 0)
	visual._update_presentation(0.18)
	assert(visual.frame == 2)
	player.is_ground_slamming = false
	visual._update_presentation(0.0)
	assert(visual.frame == 3)


func _assert_monotonic(values: Array[int]) -> void:
	for index in range(1, values.size()):
		assert(values[index] >= values[index - 1])
