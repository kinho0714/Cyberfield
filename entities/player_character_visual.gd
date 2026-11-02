class_name PlayerCharacterVisual
extends AnimatedSprite2D

const VISUAL_ATTACK_DURATION := 0.24
const VISUAL_DASH_DURATION := 0.18
const AIR_POSE_MIN_DURATION := 0.07
const GROUND_SLAM_STARTUP_DURATION := 0.16
const GROUND_SLAM_IMPACT_DURATION := 0.14
# 30/10: sheets repacked by tools/visual/repack_wall_slide.py, one centred pose per cell.
const WALL_SLIDE_CONTENT_CENTERS := {
	&"jhon": [0.0, 0.0, 0.0, 0.0],
	&"jackson": [0.0, 0.0, 0.0, 0.0],
	&"kai": [0.0, 0.0, 0.0, 0.0],
	&"spark": [0.0, 0.0, 0.0, 0.0],
}
const FRAME_ANCHORS := preload("res://entities/player_frame_anchors.gd")
## 02/11: conjuntos oficiais por personagem (Jhon Design B). Estados sem folha aprovada
## (revive, wall_slide/climb, ground_slam) continuam com as folhas antigas.
const ANIMATION_SETS := preload("res://entities/character_animation_sets.gd")
const LEGACY_SCALE := 1.5
## Duração visual (só apresentação) dos estados de quadro manual do conjunto oficial.
const SET_TIMELINES := {&"hurt": 0.32, &"get_up": 0.55, &"land": 0.22, &"dash": 0.2,
	&"shoot_pistol": 0.24, &"shoot_rifle": 0.24, &"shoot_bow": 0.30, &"melee_punch_01": 0.24}
const AIM_HOLD := 0.6
const RUN_SPEED_MIN := 170.0
## Família de animação por categoria de arma (WeaponCatalog.CATEGORIES). Novas famílias
## (lâmina, impacto, socos/chutes, combos) entram aqui sem mexer no resto.
const WEAPON_FAMILY := {&"pistol": &"pistol", &"semi_auto": &"rifle", &"rifle": &"rifle", &"shotgun": &"rifle", &"bow": &"bow",
	&"blunt": &"impact", &"blade": &"blade"}
const MELEE_STRIKE := {&"impact": &"melee_punch_01", &"blade": &"melee_punch_01", &"unarmed": &"melee_punch_01"}
const READY_STANCE := {&"impact": &"melee_ready_impact"}
const LEGACY_STATES: Array[StringName] = [&"revive", &"wall_slide", &"wall_climb", &"ground_slam"]
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
var _content_profile: ContentVisualProfile
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
var _contact_shadow: Sprite2D
var _set: Dictionary = {}
var _set_state: StringName = &""
var _set_elapsed := 0.0
var _hurt_elapsed := -1.0
var _get_up_elapsed := -1.0
var _land_elapsed := -1.0
var _aim_hold := 0.0
var _air_elapsed := 0.0
var _was_hurt := false
var _was_downed := false
var _was_on_floor := true
var _shot_family: StringName = &""
var _recoil := 0.0
var _held_weapon: Sprite2D


func _ready() -> void:
	_build_contact_shadow()
	_update_presentation(0.0)


## One soft contact shadow for every grounded state (sheets no longer bake their own).
## Drawn behind the character, in this node's space: feet sit at local y = 36.
func _build_contact_shadow() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.02, 0.42))
	gradient.set_color(1, Color(0.0, 0.0, 0.02, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 8
	_contact_shadow = Sprite2D.new()
	_contact_shadow.name = "ContactShadow"
	_contact_shadow.texture = texture
	_contact_shadow.show_behind_parent = true
	_contact_shadow.position = Vector2(0.0, 35.0)
	add_child(_contact_shadow)


func _process(delta: float) -> void:
	_update_presentation(delta)


func _update_presentation(delta: float = 0.0) -> void:
	var player := get_parent() as CharacterBody2D
	if player == null or _state_source == null or _fallback_visual == null:
		visible = false
		return
	_ensure_character(StringName(player.get("participant_id")))
	if not _set.is_empty():
		_update_set_presentation(player, delta)
		return
	_advance_visual_timers(player, delta)
	var visual_state := _resolve_state(player)
	visible = sprite_frames != null and sprite_frames.has_animation(visual_state)
	_fallback_visual.visible = not visible
	if not visible:
		return
	flip_h = _state_source.flip_h
	if not bool(player.get("network_remote_replica")) and visual_state in [&"wall_slide", &"wall_climb"]:
		_apply_wall_facing(player)
	modulate = Color(1.0, 1.0, 1.0, _state_source.modulate.a)
	if bool(player.get("network_remote_replica")) and visual_state in [&"air", &"dash", &"attack", &"ground_slam"]:
		_set_manual_frame(visual_state, clampi(int(player.get("network_visual_frame")), 0, sprite_frames.get_frame_count(visual_state) - 1))
	elif visual_state == &"air":
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
	if _contact_shadow != null:
		_contact_shadow.visible = not visual_state in [&"air", &"wall_slide", &"wall_climb"]
	if _content_profile != null:
		offset = _content_profile.alignment(visual_state, offset)
	_last_state = visual_state


func _resolve_state(player: CharacterBody2D) -> StringName:
	var remote_state := StringName(player.get("network_visual_state"))
	if bool(player.get("network_remote_replica")) and not remote_state.is_empty():
		return remote_state
	if bool(player.get("is_downed")):
		return &"downed"
	if bool(player.get("network_prediction_only")):
		if bool(player.get("network_is_hurt")):
			return &"hurt"
		if bool(player.get("network_is_reviving")):
			return &"revive"
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


## Atualiza a pose na hora (o disparo acontece antes do _process deste nó).
func refresh_now() -> void:
	_update_presentation(0.0)


func get_presentation_state() -> StringName:
	var player := get_parent() as CharacterBody2D
	if player == null:
		return &"idle"
	return _resolve_set_state(player) if not _set.is_empty() else _resolve_state(player)


func get_content_portrait(fallback: Texture2D) -> Texture2D:
	if not _set.is_empty():
		return fallback  # retrato do perfil antigo mostraria o design anterior
	return _content_profile.texture("portrait", fallback) if _content_profile != null else fallback


func _ensure_character(participant_id: StringName) -> void:
	var character_id: StringName = CHARACTER_IDS.get(participant_id, &"jhon")
	if character_id == _active_character:
		return
	_content_profile = ContentRegistry.entry_profile(ContentRegistry.character(character_id))
	_set = (ANIMATION_SETS.SETS.get(character_id, {}) as Dictionary)
	scale = Vector2.ONE * LEGACY_SCALE
	var cached: Variant = _frame_cache.get(character_id)
	if cached is SpriteFrames:
		sprite_frames = cached as SpriteFrames
	else:
		var generated := VisualSpriteFactory.build_sprite_frames(_build_definitions(character_id))
		if not _set.is_empty():
			_add_set_animations(generated)
		elif _content_profile != null:
			generated = _content_profile.merge_frames(generated)
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


# ---------------------------------------------------------------- conjunto oficial (Design B)

func _add_set_animations(frames: SpriteFrames) -> void:
	var dir := String(_set.get("dir", ""))
	var anims: Dictionary = _set.get("anims", {})
	for name_value: Variant in anims:
		var spec: Dictionary = anims[name_value]
		var texture := load(dir + String(spec.file)) as Texture2D
		var anim_name := StringName("b_" + String(name_value))
		if texture != null:
			VisualSpriteFactory.add_sheet_animation(frames, anim_name, texture, int(spec.frames), float(spec.fps), bool(spec.loop))


func has_set_animation(state: StringName) -> bool:
	return (_set.get("anims", {}) as Dictionary).has(state) and sprite_frames != null and sprite_frames.has_animation(StringName("b_" + String(state)))


func _weapon_family(player: CharacterBody2D) -> StringName:
	var weapon_id: StringName = player.call("get_active_weapon_id") if player.has_method("get_active_weapon_id") else &""
	return WEAPON_FAMILY.get(WeaponCatalog.category(weapon_id), &"unarmed") if not weapon_id.is_empty() else &"unarmed"


func _resolve_set_state(player: CharacterBody2D) -> StringName:
	var remote_state := StringName(player.get("network_visual_state"))
	if bool(player.get("network_remote_replica")) and not remote_state.is_empty():
		return remote_state
	if bool(player.get("is_downed")):
		return &"downed"
	var reviving_target: Variant = player.get("_revive_target")
	if (reviving_target is Node and is_instance_valid(reviving_target)) or (bool(player.get("network_prediction_only")) and bool(player.get("network_is_reviving"))):
		return &"revive"  # ação de reviver um aliado vence a animação de levantar
	if _get_up_elapsed >= 0.0 and _get_up_elapsed < float(SET_TIMELINES[&"get_up"]) and absf(player.velocity.x) < 12.0:
		return &"get_up"
	if _hurt_elapsed >= 0.0 and _hurt_elapsed < float(SET_TIMELINES[&"hurt"]):
		return &"hurt"
	if bool(player.get("is_ground_slamming")) or _ground_slam_impact_timer > 0.0:
		return &"ground_slam"
	var revive_target: Variant = player.get("_revive_target")
	if (revive_target is Node and is_instance_valid(revive_target)) or (bool(player.get("network_prediction_only")) and bool(player.get("network_is_reviving"))):
		return &"revive"
	if float(player.get("dash_timer")) > 0.0 or (_dash_visual_elapsed >= 0.0 and _dash_visual_elapsed < float(SET_TIMELINES[&"dash"])):
		return &"dash"
	var family := _weapon_family(player)
	if bool(player.get("is_attacking")) or (_attack_visual_elapsed >= 0.0 and _attack_visual_elapsed < VISUAL_ATTACK_DURATION):
		var weapon_id: StringName = player.call("get_active_weapon_id")
		if WeaponCatalog.is_ranged(weapon_id):
			_shot_family = family
			return StringName("shoot_" + String(family))
		return MELEE_STRIKE.get(family, &"melee_punch_01")
	if _is_wall_climb_state(player):
		return &"wall_climb"
	if _is_wall_slide_state(player):
		return &"wall_slide"
	if not player.is_on_floor():
		return &"jump" if player.velocity.y < 0.0 else &"fall"
	var moving := absf(player.velocity.x) > 12.0
	if _land_elapsed >= 0.0 and _land_elapsed < float(SET_TIMELINES[&"land"]) and not moving:
		return &"land"
	var weapon_id: StringName = player.call("get_active_weapon_id")
	if WeaponCatalog.is_ranged(weapon_id) and (player.get("weapon_reload_timers") as Dictionary).has(weapon_id):
		var reload_state := StringName("reload_" + String(family))
		if has_set_animation(reload_state) and not moving:
			return reload_state
	if moving:
		return &"run" if absf(player.velocity.x) >= RUN_SPEED_MIN else &"walk"
	if _aim_hold > 0.0 and WeaponCatalog.is_ranged(weapon_id):
		return StringName("aim_" + String(family))
	if READY_STANCE.has(family):
		return READY_STANCE[family]
	return &"idle"


func _update_set_presentation(player: CharacterBody2D, delta: float) -> void:
	_advance_visual_timers(player, delta)
	_advance_set_timers(player, delta)
	var state := _resolve_set_state(player)
	var legacy := state in LEGACY_STATES or not has_set_animation(state)
	var anim_name := state if legacy else StringName("b_" + String(state))
	visible = sprite_frames != null and sprite_frames.has_animation(anim_name)
	_fallback_visual.visible = not visible
	if not visible:
		return
	scale = Vector2.ONE * (LEGACY_SCALE if legacy else float(_set.get("scale", 1.0)))
	flip_h = _state_source.flip_h
	if not bool(player.get("network_remote_replica")) and state in [&"wall_slide", &"wall_climb"]:
		_apply_wall_facing(player)
	modulate = Color(1.0, 1.0, 1.0, _state_source.modulate.a)
	if state != _set_state:
		_set_elapsed = 0.0
	else:
		_set_elapsed += delta
	if legacy:
		_present_legacy_state(player, state, delta)
	elif bool(player.get("network_remote_replica")) and SET_TIMELINES.has(state):
		_set_manual_frame(anim_name, int(player.get("network_visual_frame")))
	elif SET_TIMELINES.has(state):
		var elapsed := _set_timeline_elapsed(state)
		_set_manual_frame(anim_name, _timeline_frame(elapsed, float(SET_TIMELINES[state]), sprite_frames.get_frame_count(anim_name)))
	elif state == &"jump":
		# Quadros 0-2 são o agachamento no chão; no ar o pulo é instantâneo: começa no 3.
		var count := sprite_frames.get_frame_count(anim_name)
		_set_manual_frame(anim_name, clampi(3 + floori(_air_elapsed * 14.0), 3, count - 1))
	elif state == &"fall":
		_set_manual_frame(anim_name, clampi(floori(_set_elapsed * 12.0), 0, sprite_frames.get_frame_count(anim_name) - 1))
	elif state.begins_with("reload_"):
		_set_manual_frame(anim_name, _reload_frame(player, sprite_frames.get_frame_count(anim_name)))
	elif animation != anim_name or (_is_looping(anim_name) and not is_playing()):
		play(anim_name)
	if not legacy:
		offset = Vector2.ZERO
	if _contact_shadow != null:
		_contact_shadow.visible = not state in [&"jump", &"fall", &"wall_slide", &"wall_climb"]
		_contact_shadow.position = Vector2(0.0, 35.0 * LEGACY_SCALE / scale.y)
	_set_state = state
	_last_state = state
	_update_held_weapon(player, state, legacy, delta)


func _present_legacy_state(player: CharacterBody2D, state: StringName, delta: float) -> void:
	if state == &"ground_slam":
		_set_manual_frame(&"ground_slam", _ground_slam_frame())
	elif animation != state or (_is_looping(state) and not is_playing()):
		play(state)
	_apply_frame_alignment(state)


func _advance_set_timers(player: CharacterBody2D, delta: float) -> void:
	var hurt_now := bool(player.get("is_hurt")) or (bool(player.get("network_prediction_only")) and bool(player.get("network_is_hurt")))
	if hurt_now and not _was_hurt:
		_hurt_elapsed = 0.0
	elif _hurt_elapsed >= 0.0:
		_hurt_elapsed += delta
	_was_hurt = hurt_now
	var downed_now := bool(player.get("is_downed"))
	if _was_downed and not downed_now:
		_get_up_elapsed = 0.0
	elif _get_up_elapsed >= 0.0:
		_get_up_elapsed += delta
	if downed_now:
		_hurt_elapsed = -1.0
	_was_downed = downed_now
	var on_floor := player.is_on_floor()
	if not on_floor:
		_air_elapsed = 0.0 if _was_on_floor else _air_elapsed + delta
		_land_elapsed = -1.0
	elif not _was_on_floor:
		_land_elapsed = 0.0
	elif _land_elapsed >= 0.0:
		_land_elapsed += delta
	_was_on_floor = on_floor
	if bool(player.get("is_attacking")) and WeaponCatalog.is_ranged(player.call("get_active_weapon_id")):
		_aim_hold = AIM_HOLD
		if _attack_visual_elapsed >= 0.0 and _attack_visual_elapsed < delta * 1.5:
			_recoil = 1.0
	else:
		_aim_hold = maxf(_aim_hold - delta, 0.0)
	_recoil = maxf(_recoil - delta * 10.0, 0.0)


func _set_timeline_elapsed(state: StringName) -> float:
	match state:
		&"hurt": return _hurt_elapsed
		&"get_up": return _get_up_elapsed
		&"land": return _land_elapsed
		&"dash": return _dash_visual_elapsed
	return _attack_visual_elapsed


func _reload_frame(player: CharacterBody2D, frame_count: int) -> int:
	var weapon_id: StringName = player.call("get_active_weapon_id")
	var remaining := float((player.get("weapon_reload_timers") as Dictionary).get(weapon_id, 0.0))
	var total := float(player.call("get_weapon_stats", weapon_id).get("reload_time", 1.5)) if player.has_method("get_weapon_stats") else 1.5
	var progress := 1.0 - clampf(remaining / maxf(total, 0.01), 0.0, 1.0)
	return clampi(floori(progress * frame_count), 0, frame_count - 1)


## Âncora da mão no quadro atual, em coordenadas locais deste nó (já espelhada).
func hand_local() -> Vector2:
	if _set.is_empty() or _set_state.is_empty():
		return Vector2.INF
	var spec: Dictionary = (_set.get("anims", {}) as Dictionary).get(_set_state, {})
	var hands: Array = spec.get("hands", [])
	if hands.is_empty():
		return Vector2.INF
	var hand: Vector2 = hands[clampi(frame, 0, hands.size() - 1)]
	if hand == Vector2.ZERO:
		return Vector2.INF
	return Vector2(-hand.x if flip_h else hand.x, hand.y)


## Ponta do cano da arma empunhada (mundo), para clarão e desenho do projétil.
func muzzle_global_position() -> Vector2:
	if _held_weapon == null or not _held_weapon.visible or _held_weapon.texture == null:
		return Vector2.INF
	var half := _held_weapon.texture.get_width() * 0.5 * absf(_held_weapon.scale.x)
	return _held_weapon.to_global(Vector2(half if not _held_weapon.flip_h else -half, 0.0) / _held_weapon.scale)


func _update_held_weapon(player: CharacterBody2D, state: StringName, legacy: bool, delta: float) -> void:
	var show := not legacy and (String(state).begins_with("aim_") or String(state).begins_with("shoot_") or String(state).begins_with("reload_"))
	var weapon_id: StringName = player.call("get_active_weapon_id") if player.has_method("get_active_weapon_id") else &""
	var hand := hand_local()
	if not show or hand == Vector2.INF or not WeaponCatalog.is_ranged(weapon_id):
		if _held_weapon != null:
			_held_weapon.visible = false
		return
	if _held_weapon == null:
		_held_weapon = Sprite2D.new()
		_held_weapon.name = "HeldWeapon"
		_held_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_held_weapon)
	var texture := WeaponCatalog.get_visual_texture(weapon_id, "world")
	_held_weapon.texture = texture
	_held_weapon.visible = texture != null
	if texture == null:
		return
	var facing := -1.0 if flip_h else 1.0
	var bow := WeaponCatalog.category(weapon_id) == &"bow"
	var size := texture.get_size()
	# Empunhadura: arcos pelo meio; armas de fogo pelo terço traseiro.
	var grip := Vector2(0.0 if bow else size.x * 0.18, 0.0)
	_held_weapon.flip_h = flip_h
	_held_weapon.scale = Vector2.ONE * minf(1.0, 44.0 / maxf(size.x, 1.0))
	var kick := -2.0 * _recoil * facing
	_held_weapon.position = hand + Vector2((size.x * 0.5 - grip.x) * _held_weapon.scale.x * facing + kick, 0.0)
	_held_weapon.z_index = 1
	if state.begins_with("reload_") and frame < 3:
		_held_weapon.rotation = 0.5 * facing                  # arma inclinada enquanto troca o pente
	else:
		_held_weapon.rotation = 0.0


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
	var is_reviving: bool = (revive_target is Node and is_instance_valid(revive_target)) or (bool(player.get("network_prediction_only")) and bool(player.get("network_is_reviving")))
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
		return
	# Keep the torso over the collision capsule in both facings: offset is not mirrored by
	# flip_h, so the correction changes sign when the sprite is flipped.
	var anchors: Array = (FRAME_ANCHORS.ANCHORS.get(_active_character, {}) as Dictionary).get(visual_state, []) as Array
	if frame >= 0 and frame < anchors.size():
		offset.x = float(anchors[frame]) if flip_h else -float(anchors[frame])


func _air_frame(vertical_velocity: float) -> int:
	if vertical_velocity <= -160.0:
		return 0
	if vertical_velocity < 60.0:
		return 1
	if vertical_velocity < 240.0:
		return 2
	return 3
