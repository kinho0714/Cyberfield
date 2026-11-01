class_name WeaponFx
extends RefCounted
## Apresentação das armas do arsenal (01/11/2026). Só visual: não altera dano/tempos.
## A folha oficial do personagem não muda; a arma aparece como sprite sobreposto durante
## o golpe/disparo e cada categoria tem seu rastro de golpe ou clarão de cano.

const FX_DIR := "res://assets/fx/arsenal/"
const SWING_SHEETS := {&"slash": ["swing_slash.png", 5], &"smash": ["swing_smash.png", 5]}
const MUZZLE_SHEETS := {&"small": "muzzle_small.png", &"pulse": "muzzle_pulse.png", &"wide": "muzzle_wide.png", &"beam": "muzzle_beam.png", &"arc": "muzzle_arc.png"}
const HAND_OFFSET := Vector2(14.0, -30.0)

static var _frames: Dictionary = {}


## Golpe corpo a corpo: arma girando no arco do golpe + rastro da categoria.
static func swing(player: Node2D, weapon_id: StringName, facing: float, rarity: StringName = &"common") -> void:
	if not _ready_for(player):
		return
	var category := WeaponCatalog.category(weapon_id)
	var kind := StringName((WeaponCatalog.CATEGORIES.get(category, {}) as Dictionary).get("swing", &"slash"))
	var parent := player.get_parent()
	var texture := WeaponCatalog.get_visual_texture(weapon_id, "world")
	if texture != null:
		var pivot := Node2D.new()
		pivot.z_index = 9
		parent.add_child(pivot)
		pivot.global_position = player.global_position + Vector2(HAND_OFFSET.x * 0.4 * facing, HAND_OFFSET.y)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.offset = Vector2(2.0, -texture.get_height() * 0.5)
		sprite.scale = Vector2.ONE * minf(1.2, 34.0 / maxf(texture.get_width(), 1.0))
		sprite.flip_v = facing < 0.0
		pivot.add_child(sprite)
		# Ângulo do golpe para a direita; espelhado (PI - a) para a esquerda.
		var start := -1.9 if kind == &"smash" else -1.3
		var finish := 0.7 if kind == &"smash" else 0.9
		var duration := 0.19 if kind == &"smash" else 0.14
		pivot.rotation = start if facing > 0.0 else PI - start
		var tween := pivot.create_tween()
		tween.tween_property(pivot, "rotation", finish if facing > 0.0 else PI - finish, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(pivot, "modulate:a", 0.0, 0.08)
		tween.tween_callback(pivot.queue_free)
	if VisualQuality.profile() == VisualQuality.MINIMAL:
		return
	var spec: Array = SWING_SHEETS.get(kind, SWING_SHEETS[&"slash"])
	var trail := _sheet(parent, String(spec[0]), int(spec[1]), 28.0)
	if trail != null:
		trail.global_position = player.global_position + Vector2(24.0 * facing, -30.0)
		trail.flip_h = facing < 0.0
		trail.scale = Vector2(1.5, 1.5)
		trail.modulate = RarityTable.color(rarity).lerp(WeaponCatalog.category_color(weapon_id), 0.6)


## Disparo: arma na mão com recuo + clarão do cano da categoria.
static func fire(player: Node2D, weapon_id: StringName, origin: Vector2, direction: Vector2) -> void:
	if not _ready_for(player):
		return
	var parent := player.get_parent()
	var texture := WeaponCatalog.get_visual_texture(weapon_id, "world")
	if texture != null:
		var held := Sprite2D.new()
		held.texture = texture
		held.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		held.flip_h = direction.x < 0.0
		held.scale = Vector2.ONE * minf(1.2, 40.0 / maxf(texture.get_width(), 1.0))
		held.z_index = 9
		parent.add_child(held)
		var rest := player.global_position + Vector2(HAND_OFFSET.x * signf(direction.x), HAND_OFFSET.y + 4.0)
		held.global_position = rest - direction * 5.0
		var tween := held.create_tween()
		tween.tween_property(held, "global_position", rest, 0.09)
		tween.tween_interval(0.08)
		tween.tween_property(held, "modulate:a", 0.0, 0.07)
		tween.tween_callback(held.queue_free)
	var kind := StringName((WeaponCatalog.CATEGORIES.get(WeaponCatalog.category(weapon_id), {}) as Dictionary).get("muzzle", &"small"))
	muzzle(player, origin, direction, kind, WeaponCatalog.category_color(weapon_id))


static func muzzle(anchor: Node2D, origin: Vector2, direction: Vector2, kind: StringName, tint: Color) -> void:
	if not _ready_for(anchor) or VisualQuality.profile() == VisualQuality.MINIMAL:
		return
	var flash := _sheet(anchor.get_parent(), String(MUZZLE_SHEETS.get(kind, MUZZLE_SHEETS[&"small"])), 3, 30.0)
	if flash == null:
		return
	flash.global_position = origin
	flash.rotation = direction.angle()
	flash.scale = Vector2(1.5, 1.5)
	flash.modulate = Color(tint, 1.0).lightened(0.25)


static func _sheet(parent: Node, file: String, frames: int, fps: float) -> AnimatedSprite2D:
	var path := FX_DIR + file
	if parent == null or not ResourceLoader.exists(path):
		return null
	if not _frames.has(path):
		_frames[path] = VisualSpriteFactory.build_sprite_frames({&"play": {"texture": load(path), "frames": frames, "fps": fps, "loop": false}})
	var effect := AnimatedSprite2D.new()
	effect.sprite_frames = _frames[path]
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.material = CombatFx._additive_material()
	effect.z_index = 21
	parent.add_child(effect)
	effect.animation_finished.connect(effect.queue_free)
	effect.play(&"play")
	return effect


static func _ready_for(node: Node2D) -> bool:
	return node != null and node.is_inside_tree() and node.get_parent() != null and CombatFx._on_screen(node)
