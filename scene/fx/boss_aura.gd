extends Node2D
## Boss presence (Operação Renascimento, 30/10/2026). Presentation only, attached as a
## child of the stage-6 boss: a pulsing carmine aura behind it, a ground ring and rising
## sparks. It reads boss_phase_two_active and is_dead but never writes gameplay state.
## Placeholder for a dedicated boss sprite set (still pending: needs new art).

const CARMINE := Color("ff2a6d")

var _aura: Sprite2D
var _ring: Sprite2D
var _sparks: CPUParticles2D
var _clock := 0.0


func _ready() -> void:
	name = "BossAura"
	z_index = -1
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_aura = Sprite2D.new()
	_aura.texture = _radial()
	_aura.scale = Vector2(2.6, 3.2)
	_aura.position = Vector2(0.0, -46.0)
	_aura.material = additive
	add_child(_aura)
	_ring = Sprite2D.new()
	_ring.texture = load("res://assets/fx/heal_ring.png") as Texture2D
	_ring.region_enabled = true
	_ring.region_rect = Rect2(64.0 * 5.0, 0.0, 64.0, 40.0)
	_ring.scale = Vector2(2.4, 1.6)
	_ring.position = Vector2(0.0, -6.0)
	_ring.modulate = CARMINE
	_ring.material = additive
	add_child(_ring)
	var amount := roundi(24.0 * VisualQuality.particle_scale())
	if amount > 0:
		_sparks = CPUParticles2D.new()
		_sparks.amount = amount
		_sparks.lifetime = 1.4
		_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_sparks.emission_rect_extents = Vector2(40.0, 6.0)
		_sparks.direction = Vector2.UP
		_sparks.spread = 18.0
		_sparks.gravity = Vector2(0.0, -30.0)
		_sparks.initial_velocity_min = 20.0
		_sparks.initial_velocity_max = 50.0
		_sparks.scale_amount_min = 2.0
		_sparks.scale_amount_max = 2.0
		_sparks.color = Color(CARMINE, 0.8)
		_sparks.material = additive
		add_child(_sparks)


func _process(delta: float) -> void:
	var boss := get_parent()
	if boss == null:
		return
	if bool(boss.get("is_dead")):
		visible = false
		return
	var phase_two := bool(boss.get("boss_phase_two_active"))
	_clock += delta * (2.4 if phase_two else 1.3)
	var level := (0.30 if phase_two else 0.20) + 0.08 * sin(_clock * 2.0)
	_aura.modulate = Color(CARMINE, level)
	_ring.self_modulate.a = 0.5 + 0.3 * sin(_clock * 2.0)
	if _sparks != null:
		_sparks.speed_scale = 1.6 if phase_two else 1.0


static func _radial() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
