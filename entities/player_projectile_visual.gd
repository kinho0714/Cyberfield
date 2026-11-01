class_name PlayerProjectileVisual
extends ProjectileVisual
## Arte dos projéteis do arsenal (tools/visual/arsenal_art.py). Cada categoria tem
## silhueta e impacto próprios para ser reconhecida em combate.

const SPECS := {
	&"scrap_round": {"frames": 4, "impact": &"kinetic", "gravity": 0.0},
	&"corp_round": {"frames": 4, "impact": &"kinetic", "gravity": 0.0},
	&"pellet": {"frames": 4, "impact": &"kinetic", "gravity": 0.0},
	&"turret_round": {"frames": 4, "impact": &"kinetic", "gravity": 0.0},
	&"pulse_bolt": {"frames": 4, "impact": &"pulse", "gravity": 0.0},
	&"rifle_beam": {"frames": 4, "impact": &"pulse", "gravity": 0.0},
	&"arc_arrow": {"frames": 4, "impact": &"plasma", "gravity": 260.0},
	&"neon_arrow": {"frames": 4, "impact": &"plasma", "gravity": 170.0},
}
const DIR := "res://assets/arsenal/projectiles/"
const IMPACT_FRAMES := 5
const SCALE := 1.5

static var _cache: Dictionary = {}

var visual_id: StringName = &"scrap_round"


static func gravity_for(id: StringName) -> float:
	return float((SPECS.get(id, {}) as Dictionary).get("gravity", 0.0))


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * SCALE
	if not _cache.has(visual_id):
		var spec: Dictionary = SPECS.get(visual_id, SPECS[&"scrap_round"])
		var definitions := {}
		var move_path := DIR + "%s.png" % String(visual_id)
		var impact_path := DIR + "%s_impact.png" % String(spec.impact)
		if ResourceLoader.exists(move_path):
			definitions[&"movement"] = {"texture": load(move_path), "frames": int(spec.frames), "fps": 16.0, "loop": true}
		if ResourceLoader.exists(impact_path):
			definitions[&"impact"] = {"texture": load(impact_path), "frames": IMPACT_FRAMES, "fps": IMPACT_FPS, "loop": false}
		_cache[visual_id] = VisualSpriteFactory.build_sprite_frames(definitions)
	sprite_frames = _cache[visual_id]
	if sprite_frames.has_animation(&"movement"):
		play(&"movement")


func show_impact() -> void:
	if sprite_frames != null and sprite_frames.has_animation(&"impact"):
		# O impacto não gira com a flecha.
		global_rotation = 0.0
		play(&"impact")
	else:
		visible = false


func show_pierce() -> void:
	var flash := create_tween()
	modulate = Color(2.0, 2.0, 2.0)
	flash.tween_property(self, "modulate", Color.WHITE, 0.08)


func get_impact_duration() -> float:
	return float(IMPACT_FRAMES) / IMPACT_FPS
