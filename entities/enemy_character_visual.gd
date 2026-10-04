class_name EnemyCharacterVisual
extends AnimatedSprite2D

@export_enum("common", "ranged", "heavy") var character_kind := "common"
@export var facing_source_path: NodePath
@export var fallback_visual_path: NodePath
@export var content_biome_id: StringName = &"biome_01"
@export var content_variant_id: StringName
@export var content_visual_profile_id: StringName

@onready var _facing_source := get_node_or_null(facing_source_path) as Node2D
@onready var _fallback_visual := get_node_or_null(fallback_visual_path) as CanvasItem

var _last_state: StringName = &""
var _content_profile: ContentVisualProfile
var _legacy_offset := Vector2.ZERO

const COMMON_V2_GROUND_OFFSET := Vector2(0.0, -7.0)
const COMMON_V2_AIR_OFFSET := Vector2.ZERO
const COMMON_V2_ATTACK_FPS := 9.615384
const COMMON_V2_FRAME_X_OFFSETS := {
	&"idle": [-8.0, 0.0, 0.0, 0.0],
}
const RANGED_V2_GROUND_OFFSET := Vector2(0.0, -11.0)
const RANGED_V2_AIR_OFFSET := Vector2.ZERO
const RANGED_V2_ATTACK_FPS := 7.0


func _ready() -> void:
	_legacy_offset = offset
	sprite_frames = VisualSpriteFactory.build_sprite_frames(_build_definitions())
	var variant := ContentRegistry.enemy_variant(content_biome_id, StringName(character_kind), content_variant_id)
	_content_profile = ContentRegistry.entry_profile(variant)
	var enemy := get_parent()
	if enemy.has_method("is_boss") and bool(enemy.call("is_boss")):
		# Existing prototype boss shares melee AI, not the biome melee identity.
		_content_profile = ContentRegistry.profile(&"boss_existing")
	if not content_visual_profile_id.is_empty():
		_content_profile = ContentRegistry.profile(content_visual_profile_id)
	if _content_profile != null:
		sprite_frames = _content_profile.merge_frames(sprite_frames)
	if _fallback_visual != null:
		_fallback_visual.visible = false
	_update_presentation()
	_place_health_bar()


func _process(_delta: float) -> void:
	_update_presentation()


func _update_presentation() -> void:
	var enemy := get_parent() as CharacterBody2D
	if enemy == null or sprite_frames == null:
		visible = false
		return
	var state := &"idle"
	if enemy.has_method("get_visual_state"):
		state = StringName(enemy.call("get_visual_state"))
	visible = sprite_frames.has_animation(state)
	if _fallback_visual != null:
		_fallback_visual.visible = not visible
	if not visible:
		return
	_apply_facing()
	# Telegraph tint formerly reached only the hidden legacy sprite.
	if _facing_source is AnimatedSprite2D:
		modulate = (_facing_source as AnimatedSprite2D).modulate
	if state == &"air":
		animation = state
		pause()
		frame = _air_frame(enemy.velocity.y)
	elif animation != state or (_is_looping(state) and not is_playing()):
		play(state)
	_apply_alignment(state)
	if _content_profile != null:
		offset = _content_profile.alignment(state, offset)
	_last_state = state


func _apply_facing() -> void:
	if _facing_source is AnimatedSprite2D:
		flip_h = (_facing_source as AnimatedSprite2D).flip_h
	elif _facing_source != null:
		flip_h = _facing_source.scale.x < 0.0


func _build_definitions() -> Dictionary:
	if character_kind == "common":
		return _build_common_v2_definitions()
	if character_kind == "ranged":
		return _build_ranged_v2_definitions()
	var path := "res://assets/enemies/%s/" % character_kind
	return {
		&"idle": _definition(path + "%s_idle_v1.png" % character_kind, 4, 4.0, true),
		&"walk": _definition(path + "%s_walk_run_v1.png" % character_kind, 6, 7.0 if character_kind == "heavy" else 8.0, true),
		&"attack": _definition(path + "%s_attack_shoot_v1.png" % character_kind, 6, 8.0, false),
		&"air": _definition(path + "%s_jump_air_fall_v1.png" % character_kind, 4, 8.0, false),
		&"hurt": _definition(path + "%s_hurt_v1.png" % character_kind, 2, 20.0, false),
		&"death": _definition(path + "%s_death_v1.png" % character_kind, 3, 10.0, false),
	}


func _build_common_v2_definitions() -> Dictionary:
	const PATH := "res://assets/enemies/common/v2/"
	return {
		&"idle": _definition(PATH + "common_idle_v2.png", 4, 4.0, true),
		&"walk": _definition(PATH + "common_walk_run_v2.png", 6, 8.0, true),
		&"attack": _definition(PATH + "common_attack_v2.png", 5, COMMON_V2_ATTACK_FPS, false),
		&"air": _definition(PATH + "common_jump_air_fall_v2.png", 4, 8.0, false),
		&"hurt": _definition(PATH + "common_hurt_v2.png", 2, 20.0, false),
		&"death": _definition(PATH + "common_death_v2.png", 3, 10.0, false),
	}


func _build_ranged_v2_definitions() -> Dictionary:
	const PATH := "res://assets/enemies/ranged/v2/"
	return {
		&"idle": _definition(PATH + "ranged_idle_v2.png", 4, 4.0, true),
		&"walk": _definition(PATH + "ranged_walk_run_v2.png", 6, 8.0, true),
		&"attack": _definition(PATH + "ranged_attack_shoot_v2.png", 6, RANGED_V2_ATTACK_FPS, false),
		&"air": _definition(PATH + "ranged_jump_air_fall_v2.png", 4, 8.0, false),
		&"hurt": _definition(PATH + "ranged_hurt_v2.png", 2, 20.0, false),
		&"death": _definition(PATH + "ranged_death_v2.png", 3, 10.0, false),
	}


func _apply_alignment(state: StringName) -> void:
	offset = _legacy_offset
	if character_kind == "common":
		offset = COMMON_V2_AIR_OFFSET if state == &"air" else COMMON_V2_GROUND_OFFSET
		offset.x += _frame_x_offset(COMMON_V2_FRAME_X_OFFSETS, state, frame)
	elif character_kind == "ranged":
		offset = RANGED_V2_AIR_OFFSET if state == &"air" else RANGED_V2_GROUND_OFFSET


func _frame_x_offset(offsets_by_animation: Dictionary, state: StringName, frame_index: int) -> float:
	var animation_offsets: Variant = offsets_by_animation.get(state)
	if not animation_offsets is Array or frame_index < 0 or frame_index >= animation_offsets.size():
		return 0.0
	return float(animation_offsets[frame_index])


func _definition(path: String, frames: int, fps: float, loop: bool) -> Dictionary:
	return {"texture": load(path) as Texture2D, "frames": frames, "fps": fps, "loop": loop}


func _is_looping(animation_name: StringName) -> bool:
	return sprite_frames.has_animation(animation_name) and sprite_frames.get_animation_loop(animation_name)


func _air_frame(vertical_velocity: float) -> int:
	if vertical_velocity <= -120.0:
		return 0
	if vertical_velocity < 40.0:
		return 1
	if vertical_velocity < 220.0:
		return 2
	return 3


func _place_health_bar() -> void:
	var bar: ProgressBar = get_parent().get_node_or_null("HealthBar") as ProgressBar
	if bar == null or sprite_frames == null or not sprite_frames.has_animation(&"idle") or sprite_frames.get_frame_count(&"idle") == 0:
		return
	# Use the official idle canvas and alignment, never legacy placeholder offsets.
	var texture: Texture2D = sprite_frames.get_frame_texture(&"idle", 0)
	if texture == null:
		return
	var top: float = position.y + (offset.y - texture.get_height() * 0.5) * scale.y
	bar.scale = Vector2.ONE
	bar.position = Vector2(-26.0, top - 12.0)
	bar.size = Vector2(52.0, 6.0)
	bar.z_index = z_index + 1
