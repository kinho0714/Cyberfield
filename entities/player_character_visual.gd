class_name PlayerCharacterVisual
extends AnimatedSprite2D

const VISUAL_ATTACK_DURATION := 0.24
const VISUAL_DASH_DURATION := 0.18
const AIR_POSE_MIN_DURATION := 0.07
const GROUND_SLAM_STARTUP_DURATION := 0.16
const GROUND_SLAM_IMPACT_DURATION := 0.14
const WALL_SLIDE_CONTENT_CENTERS := {
	&"jhon": [4.0, 0.0, -11.0, -6.5],
	&"jackson": [2.0, 0.0, -14.0, -9.0],
	&"kai": [7.0, 14.5, 0.0, -5.0],
	&"spark": [4.5, 0.0, 0.0, -4.5],
}
const CHARACTER_IDS := {
	&"player_1": &"jhon",
	&"player_2": &"jackson",
	&"player_3": &"kai",
	&"player_4": &"spark",
}
const FILES := {
	&"jhon": {
		&"idle": "jhon_v2_idle_v2.png", &"walk": "jhon_v2_walk_run_v2.png",
		&"air": "jhon_v2_jump_air_fall_v2.png", &"attack": "jhon_v2_attack_combo_v2.png",
		&"dash": "jhon_v2_dash_v2.png", &"ground_slam": "jhon_v2_ground_slam_v2.png",
		&"hurt": "jhon_v2_hurt_v2.png", &"downed": "jhon_v2_downed_death_v2.png",
		&"revive": "jhon_v2_revive_ally_v1.png", &"wall_slide": "jhon_v2_wall_slide_v2.png",
		&"wall_climb": "jhon_v2_wall_climb_v2.png",
	},
	&"jackson": {
		&"idle": "jackson_idle_v1.png", &"walk": "jackson_walk_run_v1.png",
		&"air": "jackson_jump_air_fall_v1.png", &"attack": "jackson_attack_combo_v1.png",
		&"dash": "jackson_dash_v1.png", &"ground_slam": "jackson_ground_slam_v1.png",
		&"hurt": "jackson_hurt_v1.png", &"downed": "jackson_downed_death_v1.png",
		&"revive": "jackson_revive_ally_v1.png", &"wall_slide": "jackson_wall_slide_v1.png",
		&"wall_climb": "jackson_wall_climb_v1.png",
	},
	&"kai": {
		&"idle": "kai_idle_v1.png", &"walk": "kai_walk_run_v1.png",
		&"air": "kai_jump_air_fall_v1.png", &"attack": "kai_attack_combo_v1.png",
		&"dash": "kai_dash_v1.png", &"ground_slam": "kai_ground_slam_v1.png",
		&"hurt": "kai_hurt_v1.png", &"downed": "kai_downed_death_v1.png",
		&"revive": "kai_revive_ally_v1.png", &"wall_slide": "kai_wall_slide_v1.png",
		&"wall_climb": "kai_wall_climb_v1.png",
	},
	&"spark": {
		&"idle": "spark_idle_v1.png", &"walk": "spark_walk_run_v1.png",
		&"air": "spark_jump_air_fall_v1.png", &"attack": "spark_attack_combo_v1.png",
		&"dash": "spark_dash_v1.png", &"ground_slam": "spark_ground_slam_v1.png",
		&"hurt": "spark_hurt_v1.png", &"downed": "spark_downed_death_v1.png",
		&"revive": "spark_revive_ally_v1.png", &"wall_slide": "spark_wall_slide_v1.png",
		&"wall_climb": "spark_wall_climb_v1.png",
	},
}

@export var state_source_path: NodePath
@export var fallback_visual_path: NodePath

@onready var _state_source := get_node(state_source_path) as AnimatedSprite2D
@onready var _fallback_visual := get_node(fallback_visual_path) as CanvasItem

var _active_character: StringName = &""
var _frame_cache: Dictionary = {}
var _last_state: StringName = &""
var _last_attack_generation := -1
var _attack_visual_elapsed := -1.0
var _dash_visual_elapsed := -1.0
var _ground_slam_elapsed := -1.0
var _ground_slam_impact_timer := 0.0
var _was_dashing := false
var _was_ground_slamming := false
var _air_pose := 0
var _air_pose_elapsed := 0.0
var _was_airborne := false


func _ready() -> void:
	_update_presentation(0.0)


func _process(delta: float) -> void:
	_update_presentation(delta)


func _update_presentation(delta: float = 0.0) -> void:
	var player := get_parent() as CharacterBody2D
	if player == null or _state_source == null or _fallback_visual == null:
		visible = false
		return
	_ensure_character(StringName(player.get("participant_id")))
	_advance_visual_timers(player, delta)
	var visual_state := _resolve_state(player)
	visible = sprite_frames != null and sprite_frames.has_animation(visual_state)
	_fallback_visual.visible = not visible
	if not visible:
		return
	flip_h = _state_source.flip_h
	if visual_state in [&"wall_slide", &"wall_climb"]:
		_apply_wall_facing(player)
	modulate = Color(1.0, 1.0, 1.0, _state_source.modulate.a)
	if visual_state == &"air":
		animation = &"air"
		pause()
		var requested_air_frame := clampi(int(player.get("network_visual_frame")), 0, 3) if bool(player.get("network_remote_replica")) else _air_frame(player.velocity.y)
		frame = _stable_air_frame(requested_air_frame, player.velocity.y, delta)
	elif visual_state == &"dash":
		_set_manual_frame(&"dash", _timeline_frame(_dash_visual_elapsed, VISUAL_DASH_DURATION, 4))
	elif visual_state == &"attack":
		var attack_frames := sprite_frames.get_frame_count(&"attack")
		_set_manual_frame(&"attack", _timeline_frame(_attack_visual_elapsed, VISUAL_ATTACK_DURATION, attack_frames))
	elif visual_state == &"ground_slam":
		_set_manual_frame(&"ground_slam", _ground_slam_frame())
	elif animation != visual_state or (_is_looping(visual_state) and not is_playing()):
		play(visual_state)
	if visual_state != &"air":
		_was_airborne = false
	_apply_frame_alignment(visual_state)
	_last_state = visual_state


func _resolve_state(player: CharacterBody2D) -> StringName:
	var remote_state := StringName(player.get("network_visual_state"))
	if bool(player.get("network_remote_replica")) and not remote_state.is_empty():
		return remote_state
	if bool(player.get("is_downed")):
		return &"downed"
	if bool(player.get("is_hurt")):
		return &"hurt"
	if bool(player.get("is_ground_slamming")) or _ground_slam_impact_timer > 0.0:
		return &"ground_slam"
	var revive_target: Variant = player.get("_revive_target")
	if revive_target is Node and is_instance_valid(revive_target):
		return &"revive"
	if float(player.get("dash_timer")) > 0.0 or (_dash_visual_elapsed >= 0.0 and _dash_visual_elapsed < VISUAL_DASH_DURATION):
		return &"dash"
	if bool(player.get("is_attacking")) or (_attack_visual_elapsed >= 0.0 and _attack_visual_elapsed < VISUAL_ATTACK_DURATION):
		return &"attack"
	if _is_wall_climb_state(player):
		return &"wall_climb"
	if _is_wall_slide_state(player):
		return &"wall_slide"
	if _state_source.animation == &"jump" or not player.is_on_floor():
		return &"air"
	if _state_source.animation == &"walk" and absf(player.velocity.x) > 12.0:
		return &"walk"
	return &"idle"


func get_presentation_state() -> StringName:
	var player := get_parent() as CharacterBody2D
	return _resolve_state(player) if player != null else &"idle"


func _ensure_character(participant_id: StringName) -> void:
	var character_id: StringName = CHARACTER_IDS.get(participant_id, &"jhon")
	if character_id == _active_character:
		return
	var cached: Variant = _frame_cache.get(character_id)
	if cached is SpriteFrames:
		sprite_frames = cached as SpriteFrames
	else:
		var generated := VisualSpriteFactory.build_sprite_frames(_build_definitions(character_id))
		_frame_cache[character_id] = generated
		sprite_frames = generated
	_active_character = character_id
	_last_state = &""
	_last_attack_generation = -1
	_attack_visual_elapsed = -1.0
	_dash_visual_elapsed = -1.0
	_ground_slam_elapsed = -1.0
	_ground_slam_impact_timer = 0.0
	_was_airborne = false
	offset = Vector2.ZERO


func _build_definitions(character_id: StringName) -> Dictionary:
	var character_files := FILES[character_id] as Dictionary
	var base_path := "res://assets/players/%s/" % String(character_id)
	var attack_frames := 5 if character_id == &"jhon" else 6
	return {
		&"idle": _definition(base_path, character_files, &"idle", 4, 4.0, true),
		&"walk": _definition(base_path, character_files, &"walk", 6, 8.0, true),
		&"air": _definition(base_path, character_files, &"air", 4, 8.0, false),
		&"attack": _definition(base_path, character_files, &"attack", attack_frames, float(attack_frames) / VISUAL_ATTACK_DURATION, false),
		&"dash": _definition(base_path, character_files, &"dash", 4, 4.0 / VISUAL_DASH_DURATION, false),
		&"ground_slam": _definition(base_path, character_files, &"ground_slam", 5, 12.0, false),
		&"hurt": _definition(base_path, character_files, &"hurt", 2, 20.0, false),
		&"downed": _definition(base_path, character_files, &"downed", 3, 6.0, false),
		&"revive": _definition(base_path, character_files, &"revive", 5, 5.0, true),
		&"wall_slide": _definition(base_path, character_files, &"wall_slide", 4, 8.0, true),
		&"wall_climb": _definition(base_path, character_files, &"wall_climb", 4, 8.0, true),
	}


func _definition(base_path: String, files: Dictionary, key: StringName, frames: int, fps: float, loop: bool) -> Dictionary:
	return {"texture": load(base_path + String(files[key])) as Texture2D, "frames": frames, "fps": fps, "loop": loop}


func _is_looping(animation_name: StringName) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(animation_name) and sprite_frames.get_animation_loop(animation_name)


func _is_wall_climb_state(player: CharacterBody2D) -> bool:
	return not player.is_on_floor() and player.is_on_wall() and float(player.get("wall_transfer_assist_timer")) <= 0.0 and is_equal_approx(player.velocity.y, -80.0)


func _is_wall_slide_state(player: CharacterBody2D) -> bool:
	return not player.is_on_floor() and player.is_on_wall() and float(player.get("wall_transfer_assist_timer")) <= 0.0 and not _is_wall_climb_state(player)


func _apply_wall_facing(player: CharacterBody2D) -> void:
	var wall_normal := player.get_wall_normal()
	if wall_normal.x > 0.0:
		flip_h = false
	elif wall_normal.x < 0.0:
		flip_h = true


func _advance_visual_timers(player: CharacterBody2D, delta: float) -> void:
	var is_downed_now := bool(player.get("is_downed"))
	var is_hurt_now := bool(player.get("is_hurt"))
	var revive_target: Variant = player.get("_revive_target")
	var is_reviving := revive_target is Node and is_instance_valid(revive_target)
	var is_ground_slamming_now := bool(player.get("is_ground_slamming"))
	var is_dashing_now := float(player.get("dash_timer")) > 0.0
	var is_attacking_now := bool(player.get("is_attacking"))
	if is_downed_now or is_hurt_now or is_reviving:
		_attack_visual_elapsed = -1.0
		_dash_visual_elapsed = -1.0
		_ground_slam_impact_timer = 0.0
		_was_dashing = is_dashing_now
		_was_ground_slamming = is_ground_slamming_now
		return
	if is_ground_slamming_now:
		if not _was_ground_slamming:
			_ground_slam_elapsed = 0.0
		else:
			_ground_slam_elapsed += delta
		_attack_visual_elapsed = -1.0
		_dash_visual_elapsed = -1.0
		_was_dashing = is_dashing_now
		_was_ground_slamming = true
		return
	elif _was_ground_slamming:
		_ground_slam_impact_timer = GROUND_SLAM_IMPACT_DURATION
	if _ground_slam_impact_timer > 0.0:
		_ground_slam_impact_timer = maxf(_ground_slam_impact_timer - delta, 0.0)
	if is_dashing_now:
		_ground_slam_impact_timer = 0.0
		if not _was_dashing:
			_dash_visual_elapsed = 0.0
		else:
			_dash_visual_elapsed += delta
		_attack_visual_elapsed = -1.0
	elif _dash_visual_elapsed >= 0.0:
		_dash_visual_elapsed += delta
	var generation := int(player.get("attack_generation"))
	if is_attacking_now and generation != _last_attack_generation:
		_ground_slam_impact_timer = 0.0
		_last_attack_generation = generation
		_attack_visual_elapsed = 0.0
	elif _attack_visual_elapsed >= 0.0:
		_attack_visual_elapsed += delta
	_was_dashing = is_dashing_now
	_was_ground_slamming = is_ground_slamming_now


func _set_manual_frame(animation_name: StringName, frame_index: int) -> void:
	animation = animation_name
	pause()
	frame = clampi(frame_index, 0, maxi(sprite_frames.get_frame_count(animation_name) - 1, 0))


func _timeline_frame(elapsed: float, duration: float, frame_count: int) -> int:
	if frame_count <= 1 or elapsed <= 0.0:
		return 0
	var progress := clampf(elapsed / maxf(duration, 0.001), 0.0, 0.9999)
	return clampi(floori(progress * float(frame_count)), 0, frame_count - 1)


func _ground_slam_frame() -> int:
	if _ground_slam_impact_timer > 0.0 and not _was_ground_slamming:
		var impact_progress := 1.0 - _ground_slam_impact_timer / GROUND_SLAM_IMPACT_DURATION
		return 3 if impact_progress < 0.55 else 4
	if _ground_slam_elapsed < 0.08:
		return 0
	if _ground_slam_elapsed < GROUND_SLAM_STARTUP_DURATION:
		return 1
	return 2


func _stable_air_frame(requested_frame: int, vertical_velocity: float, delta: float) -> int:
	requested_frame = clampi(requested_frame, 0, 3)
	if not _was_airborne:
		_air_pose = requested_frame
		_air_pose_elapsed = 0.0
		_was_airborne = true
		return _air_pose
	_air_pose_elapsed += delta
	var restarted_ascent := requested_frame == 0 and vertical_velocity <= -160.0
	if restarted_ascent or requested_frame > _air_pose and _air_pose_elapsed >= AIR_POSE_MIN_DURATION:
		_air_pose = requested_frame
		_air_pose_elapsed = 0.0
	return _air_pose


func _apply_frame_alignment(visual_state: StringName) -> void:
	offset = Vector2.ZERO
	if visual_state in [&"air", &"wall_slide", &"wall_climb"]:
		offset.y = 1.0
	elif visual_state == &"ground_slam" and frame < 3:
		offset.y = 1.0
	if visual_state == &"wall_slide":
		var centers: Array = WALL_SLIDE_CONTENT_CENTERS.get(_active_character, []) as Array
		if frame >= 0 and frame < centers.size():
			offset.x = -float(centers[frame])


func _air_frame(vertical_velocity: float) -> int:
	if vertical_velocity <= -160.0:
		return 0
	if vertical_velocity < 60.0:
		return 1
	if vertical_velocity < 240.0:
		return 2
	return 3

