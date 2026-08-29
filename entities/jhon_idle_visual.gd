class_name JhonIdleVisual
extends AnimatedSprite2D

const BASE_DASH_DURATION := 0.15
const DASH_FRAME_COUNT := 5
const ORIGINAL_ADDITIONAL_SHEETS: Dictionary = {
	&"fall": preload("res://assets/characters/jhon/variants/jhon_a_fall_72_v1.png"),
	&"wall_slide": preload("res://assets/characters/jhon/variants/jhon_a_wall_slide_72_v1.png"),
}
const VARIANT_SHEETS: Dictionary = {
	&"orange": {
		&"idle": preload("res://assets/characters/jhon/variants/jhon_orange_idle_72_v1.png"),
		&"walk": preload("res://assets/characters/jhon/variants/jhon_orange_walk_72_v1.png"),
		&"jump": preload("res://assets/characters/jhon/variants/jhon_orange_jump_72_v1.png"),
		&"attack": preload("res://assets/characters/jhon/variants/jhon_orange_attack_72_v1.png"),
		&"dash": preload("res://assets/characters/jhon/variants/jhon_orange_dash_72_v1.png"),
		&"fall": preload("res://assets/characters/jhon/variants/jhon_orange_fall_72_v1.png"),
		&"wall_slide": preload("res://assets/characters/jhon/variants/jhon_orange_wall_slide_72_v1.png"),
	},
	&"white": {
		&"idle": preload("res://assets/characters/jhon/variants/jhon_white_idle_72_v1.png"),
		&"walk": preload("res://assets/characters/jhon/variants/jhon_white_walk_72_v1.png"),
		&"jump": preload("res://assets/characters/jhon/variants/jhon_white_jump_72_v1.png"),
		&"attack": preload("res://assets/characters/jhon/variants/jhon_white_attack_72_v1.png"),
		&"dash": preload("res://assets/characters/jhon/variants/jhon_white_dash_72_v1.png"),
		&"fall": preload("res://assets/characters/jhon/variants/jhon_white_fall_72_v1.png"),
		&"wall_slide": preload("res://assets/characters/jhon/variants/jhon_white_wall_slide_72_v1.png"),
	},
	&"red": {
		&"idle": preload("res://assets/characters/jhon/variants/jhon_red_idle_72_v1.png"),
		&"walk": preload("res://assets/characters/jhon/variants/jhon_red_walk_72_v1.png"),
		&"jump": preload("res://assets/characters/jhon/variants/jhon_red_jump_72_v1.png"),
		&"attack": preload("res://assets/characters/jhon/variants/jhon_red_attack_72_v1.png"),
		&"dash": preload("res://assets/characters/jhon/variants/jhon_red_dash_72_v1.png"),
		&"fall": preload("res://assets/characters/jhon/variants/jhon_red_fall_72_v1.png"),
		&"wall_slide": preload("res://assets/characters/jhon/variants/jhon_red_wall_slide_72_v1.png"),
	},
}

@export var state_source_path: NodePath
@export var fallback_visual_path: NodePath

@onready var _state_source: AnimatedSprite2D = get_node(state_source_path) as AnimatedSprite2D
@onready var _fallback_visual: CanvasItem = get_node(fallback_visual_path) as CanvasItem

var _last_presentation: StringName = &""
var _last_attack_generation := -1
var _original_sprite_frames: SpriteFrames
var _variant_cache: Dictionary = {}
var _active_variant: StringName = &""


func _ready() -> void:
	_original_sprite_frames = sprite_frames.duplicate(true) as SpriteFrames
	_add_sheet_animation(_original_sprite_frames, &"fall", ORIGINAL_ADDITIONAL_SHEETS.get(&"fall") as Texture2D, 6, 8.0, false)
	_add_sheet_animation(_original_sprite_frames, &"wall_slide", ORIGINAL_ADDITIONAL_SHEETS.get(&"wall_slide") as Texture2D, 6, 8.0, true)
	sprite_frames = _original_sprite_frames
	_update_presentation()


func _process(_delta: float) -> void:
	_update_presentation()


func _update_presentation() -> void:
	var player := get_parent() as CharacterBody2D
	if player == null or _state_source == null or _fallback_visual == null:
		visible = false
		return
	_ensure_player_variant(player)
	var any_attack: bool = bool(player.get("is_attacking"))
	var melee_attack: bool = any_attack and _is_melee_attack(player)
	var dash_active: bool = (
		float(player.get("dash_timer")) > 0.0
		or absf(player.velocity.x) >= 500.0
	)
	var wall_slide_active: bool = _is_wall_slide_visual_state(player)
	var fallback_only: bool = (
		bool(player.get("is_ground_slamming"))
		or bool(player.get("is_hurt"))
		or bool(player.get("is_healing"))
		or bool(player.get("is_downed"))
		or (any_attack and not melee_attack)
	)
	var presentation_animation: StringName = &""
	if not fallback_only:
		if dash_active:
			presentation_animation = &"dash"
		elif melee_attack:
			presentation_animation = &"attack"
		elif wall_slide_active:
			presentation_animation = &"wall_slide"
		elif _state_source.animation == &"idle" and absf(player.velocity.x) < 1.0:
			presentation_animation = &"idle"
		elif _state_source.animation == &"walk" and absf(player.velocity.x) > 12.0:
			presentation_animation = &"walk"
		elif _state_source.animation == &"jump" and _can_show_jump(player):
			presentation_animation = &"jump"
		elif _state_source.animation == &"jump" and _can_show_fall(player):
			presentation_animation = &"fall"
	visible = presentation_animation != &""
	_fallback_visual.visible = not visible
	flip_h = _state_source.flip_h
	if wall_slide_active:
		_apply_wall_facing(player)
	modulate = Color(1.0, 1.0, 1.0, _state_source.modulate.a)
	if presentation_animation == &"jump":
		animation = &"jump"
		pause()
		frame = _jump_frame_for_velocity(player.velocity.y)
	elif presentation_animation == &"fall":
		if _last_presentation != &"fall":
			play(&"fall")
	elif presentation_animation == &"attack":
		var attack_generation: int = int(player.get("attack_generation"))
		if _last_presentation != &"attack" or attack_generation != _last_attack_generation:
			play(&"attack")
		_last_attack_generation = attack_generation
	elif presentation_animation == &"dash":
		if float(player.get("dash_timer")) > 0.0:
			animation = &"dash"
			pause()
			frame = _dash_frame(player)
		elif _last_presentation != &"dash":
			play(&"dash")
	elif visible and (animation != presentation_animation or not is_playing()):
		play(presentation_animation)
	_last_presentation = presentation_animation


func _ensure_player_variant(player: CharacterBody2D) -> void:
	var participant_id: StringName = StringName(player.get("participant_id"))
	var requested_variant: StringName = _variant_for_participant(participant_id)
	if requested_variant == _active_variant:
		return
	if requested_variant == &"original":
		sprite_frames = _original_sprite_frames
	else:
		var cached_value: Variant = _variant_cache.get(requested_variant)
		if cached_value is SpriteFrames:
			sprite_frames = cached_value as SpriteFrames
		else:
			var sheets_value: Variant = VARIANT_SHEETS.get(requested_variant)
			if not (sheets_value is Dictionary):
				return
			var generated_frames: SpriteFrames = _build_variant_frames(sheets_value as Dictionary)
			_variant_cache[requested_variant] = generated_frames
			sprite_frames = generated_frames
	_active_variant = requested_variant
	_last_presentation = &""


func _variant_for_participant(participant_id: StringName) -> StringName:
	match participant_id:
		&"player_2": return &"orange"
		&"player_3": return &"white"
		&"player_4": return &"red"
		_: return &"original"


func _build_variant_frames(sheets: Dictionary) -> SpriteFrames:
	var result: SpriteFrames = SpriteFrames.new()
	result.remove_animation(&"default")
	_add_sheet_animation(result, &"idle", sheets.get(&"idle") as Texture2D, 4, 4.0, true)
	_add_sheet_animation(result, &"walk", sheets.get(&"walk") as Texture2D, 8, 8.0, true)
	_add_sheet_animation(result, &"jump", sheets.get(&"jump") as Texture2D, 5, 5.0, false)
	_add_sheet_animation(result, &"attack", sheets.get(&"attack") as Texture2D, 5, 16.666667, false)
	_add_sheet_animation(result, &"dash", sheets.get(&"dash") as Texture2D, 5, 33.333333, false)
	_add_sheet_animation(result, &"fall", sheets.get(&"fall") as Texture2D, 6, 8.0, false)
	_add_sheet_animation(result, &"wall_slide", sheets.get(&"wall_slide") as Texture2D, 6, 8.0, true)
	return result


func _add_sheet_animation(frames: SpriteFrames, animation_name: StringName, texture: Texture2D, frame_count: int, fps: float, loops: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for frame_index in frame_count:
		var atlas_frame: AtlasTexture = AtlasTexture.new()
		atlas_frame.atlas = texture
		atlas_frame.region = Rect2(frame_index * 96.0, 0.0, 96.0, 96.0)
		frames.add_frame(animation_name, atlas_frame)


func _is_melee_attack(player: CharacterBody2D) -> bool:
	var weapons_value: Variant = player.get("equipped_weapons")
	if not (weapons_value is Array):
		return false
	var weapons: Array = weapons_value as Array
	var active_slot: int = int(player.get("active_weapon_slot"))
	if active_slot < 0 or active_slot >= weapons.size():
		return false
	var weapon_id: StringName = StringName(weapons[active_slot])
	if weapon_id.is_empty():
		return false
	var definition: Dictionary = WeaponCatalog.get_definition(weapon_id)
	return StringName(definition.get("type", &"melee")) == &"melee"


func _dash_frame(player: CharacterBody2D) -> int:
	var duration_bonus: float = float(player.get("dash_duration_bonus"))
	var total_duration: float = maxf(BASE_DASH_DURATION * (1.0 + duration_bonus), 0.001)
	var remaining: float = clampf(float(player.get("dash_timer")), 0.0, total_duration)
	var progress: float = 1.0 - remaining / total_duration
	return clampi(floori(progress * DASH_FRAME_COUNT), 0, DASH_FRAME_COUNT - 1)


func _can_show_jump(player: CharacterBody2D) -> bool:
	var wall_transfer_timer: float = float(player.get("wall_transfer_assist_timer"))
	if player.is_on_wall() and wall_transfer_timer <= 0.0:
		return false
	return not player.is_on_floor() and player.velocity.y <= 60.0


func _can_show_fall(player: CharacterBody2D) -> bool:
	return not player.is_on_floor() and not _is_wall_slide_visual_state(player) and player.velocity.y > 60.0


func _is_wall_slide_visual_state(player: CharacterBody2D) -> bool:
	var wall_transfer_timer: float = float(player.get("wall_transfer_assist_timer"))
	return not player.is_on_floor() and player.is_on_wall() and wall_transfer_timer <= 0.0


func _apply_wall_facing(player: CharacterBody2D) -> void:
	var wall_normal: Vector2 = player.get_wall_normal()
	if wall_normal.x > 0.0:
		# Left wall: its collision normal points right, into the shaft.
		flip_h = false
	elif wall_normal.x < 0.0:
		# Right wall: its collision normal points left, into the shaft.
		flip_h = true


func _jump_frame_for_velocity(vertical_velocity: float) -> int:
	if vertical_velocity <= -280.0:
		return 0
	if vertical_velocity <= -120.0:
		return 1
	if vertical_velocity < 60.0:
		return 2
	if vertical_velocity < 220.0:
		return 3
	return 4
