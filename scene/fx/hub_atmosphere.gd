extends Node2D
## Laboratory hub atmosphere (Operação Renascimento, 30/10/2026). Presentation only and
## position-independent: it never moves or hides the approved lab kit. Coloured light
## washes behind the actors, drifting dust in front, and a slow holographic sweep.
## Obeys VisualQuality (no sweep or flicker outside FULL; dust scales with particles).

const ROOM := Vector2(1280.0, 720.0)
const CYAN := Color("39dff2")
const MAGENTA := Color("ff4fb4")
const SWEEP_PERIOD := 9.0

var _sweep: Polygon2D
var _washes: Array[Sprite2D] = []
var _clock := 0.0


func _ready() -> void:
	name = "HubAtmosphere"
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var behind := Node2D.new()
	behind.z_index = -4
	add_child(behind)
	for spec: Array in [[Vector2(180, 380), CYAN, 0.16], [Vector2(1100, 380), MAGENTA, 0.14], [Vector2(640, 90), CYAN, 0.08]]:
		var wash := Sprite2D.new()
		wash.texture = _radial(spec[1])
		wash.position = spec[0]
		wash.scale = Vector2(5.5, 4.0)
		wash.material = additive
		wash.modulate.a = float(spec[2])
		behind.add_child(wash)
		_washes.append(wash)
	if VisualQuality.profile() == VisualQuality.FULL:
		_sweep = Polygon2D.new()
		_sweep.polygon = PackedVector2Array([Vector2(0, 0), Vector2(ROOM.x, 0), Vector2(ROOM.x, 2), Vector2(0, 2)])
		_sweep.color = Color(CYAN, 0.10)
		_sweep.material = additive
		behind.add_child(_sweep)
	var amount := roundi(26.0 * VisualQuality.particle_scale())
	if amount > 0:
		var dust := CPUParticles2D.new()
		dust.amount = amount
		dust.lifetime = 7.0
		dust.preprocess = 7.0
		dust.position = ROOM * 0.5
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		dust.emission_rect_extents = ROOM * 0.5
		dust.direction = Vector2(0.3, -1.0)
		dust.spread = 40.0
		dust.gravity = Vector2(1.0, -2.0)
		dust.initial_velocity_min = 3.0
		dust.initial_velocity_max = 9.0
		dust.color = Color(0.75, 0.95, 1.0, 0.35)
		dust.z_index = 5
		add_child(dust)


func _process(delta: float) -> void:
	_clock += delta
	var breathe := 0.92 + 0.08 * sin(_clock * 0.9)
	for wash in _washes:
		wash.self_modulate.a = breathe
	if _sweep != null:
		_sweep.position.y = fposmod(_clock, SWEEP_PERIOD) / SWEEP_PERIOD * ROOM.y


static func _radial(colour: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(colour, 1.0))
	gradient.set_color(1, Color(colour, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
