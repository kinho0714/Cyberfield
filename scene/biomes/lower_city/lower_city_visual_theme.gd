extends Node2D
## Lower City night theme (30/10/2026). Presentation only.
## BiomeGenerator calls build() after layout, content and signature exist. Nothing here
## touches RNG, collision shapes, IDs or input; every choice derives from module indices,
## so LAN peers with the same layout see the same street. Art: original layers generated
## by tools/visual/lower_city_v2.py (backdrop, native size, drawn at 2x) and
## tools/experimental/lower_city_concept.py (tiles, lamp, rain). No private pixels.

const STREET := preload("res://assets/experimental/lower_city_concept/street_tile.png")
const CATWALK := preload("res://assets/experimental/lower_city_concept/catwalk_tile.png")
const WALL := preload("res://assets/experimental/lower_city_concept/wall_tile.png")
const SKY := preload("res://assets/environment/lower_city_v2/sky.png")
const FAR := preload("res://assets/environment/lower_city_v2/far.png")
const FAR_BEACONS := preload("res://assets/environment/lower_city_v2/far_beacons.png")
const FOG := preload("res://assets/environment/lower_city_v2/fog.png")
const MID := preload("res://assets/environment/lower_city_v2/mid.png")
const MID_GLOW := preload("res://assets/environment/lower_city_v2/mid_glow.png")
const MID_SIGNS := preload("res://assets/environment/lower_city_v2/mid_signs.png")
const RAIL := preload("res://assets/environment/lower_city_v2/rail.png")
const PUDDLES := preload("res://assets/environment/lower_city_v2/puddles.png")
const LAMP_CONE := preload("res://assets/experimental/lower_city_concept/lamp_cone.png")
const RAIN_DROP := preload("res://assets/experimental/lower_city_concept/rain_drop.png")

const FLOOR_TOP := 420.0
const MID_STREET_ROW := 660.0
# Floor-to-camera offset of the 1280x720 concept framing (floor 420, camera 384).
const REST_DEPTH := 36.0
const BACKDROP_LAYER := -10
# Backdrop textures are stored at native pixel size; every plane draws at this scale.
const PLANE_SCALE := 2.0
# Module cells were opaque and hid any backdrop; a light haze keeps room volume readable.
const MODULE_HAZE := Color(0.02, 0.035, 0.06, 0.22)
const MODULE_HAZE_DEEP := Color(0.02, 0.035, 0.06, 0.34)
const GROUND_FILL := Color(0.031, 0.047, 0.067)
const POLE_COLOR := Color(0.133, 0.18, 0.212)
const LAMP_COLOR := Color(1.0, 0.84, 0.59)
const LAMP_SLOTS := [150.0, 690.0]
const SOCKET_CLEARANCE := 110.0
const PUDDLE_REGIONS := [Rect2(420.0, 0.0, 140.0, 32.0), Rect2(1100.0, 0.0, 130.0, 32.0), Rect2(1500.0, 0.0, 120.0, 32.0)]
# Screen-space depth planes, back to front: texture, top y, x/y follow, drift px/s, tint, additive.
# The viaduct is tinted toward the sky: its deck must never read as a walkable platform.
const PLANES := [
	["far", -62.0, 0.15, 0.10, 0.0, Color(1.0, 1.0, 1.0, 1.0), false],
	["far_beacons", -62.0, 0.15, 0.10, 0.0, Color(1.0, 1.0, 1.0, 1.0), true],
	["fog", 245.0, 0.30, 0.20, -6.0, Color(1.0, 1.0, 1.0, 1.0), false],
	["mid", -207.0, 0.45, 0.30, 0.0, Color(1.0, 1.0, 1.0, 1.0), false],
	["mid_glow", -207.0, 0.45, 0.30, 0.0, Color(1.0, 1.0, 1.0, 1.0), true],
	["mid_signs", -207.0, 0.45, 0.30, 0.0, Color(1.0, 1.0, 1.0, 1.0), true],
	["rail", -54.0, 0.70, 0.60, 0.0, Color(0.5, 0.52, 0.66, 0.85), false],
	["fog", 311.0, 0.80, 0.80, 10.0, Color(1.0, 1.0, 1.0, 0.8), false],
]

var _floor_ref_y := FLOOR_TOP
var _add_material: CanvasItemMaterial
var _sky: Sprite2D
var _ground: Polygon2D
var _planes: Array[Dictionary] = []
var _signs: Sprite2D
var _sign_glow: Sprite2D
var _beacons: Sprite2D
var _rain: Array[CPUParticles2D] = []
var _clock := 0.0
var _flicker_at := 4.0
var _flicker_left := 0.0


func build(generator: Node2D) -> void:
	name = "LowerCityVisual"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_material = CanvasItemMaterial.new()
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if generator.has_method("get_start_position"):
		_floor_ref_y = generator.get_start_position().y + 36.0
	_skin_geometry(generator)
	var modules := generator.get_node_or_null("Modules")
	if modules != null:
		_build_street_dressing(modules)
	_build_backdrop()
	_build_rain()


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	_clock += delta
	var view := get_viewport_rect().size
	var center := camera.get_screen_center_position()
	_update_backdrop(center, camera.zoom.x, view, delta)
	_update_rain(center, view / camera.zoom)
	_update_lights(delta)


func _skin_geometry(generator: Node2D) -> void:
	for body in generator.find_children("*", "StaticBody2D", true, false):
		var role: StringName = body.get_meta("collision_role", &"")
		if role != &"solid_structure" and role != &"one_way_platform":
			continue
		var visual: Polygon2D = null
		var size := Vector2.ZERO
		for child in body.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				size = (child.shape as RectangleShape2D).size
			elif visual == null and child is Polygon2D and child.visible and child.color.a > 0.0:
				visual = child
		if visual == null or not size.is_finite() or size.x <= 0.0 or size.y <= 0.0:
			continue
		# Layout coordinates (no global transform before the biome enters the tree).
		var offset := _offset_in(body, generator)
		var left := offset.x - size.x * 0.5
		var top := offset.y - size.y * 0.5
		var texture: Texture2D = STREET
		var v0 := 0.0
		if role == &"one_way_platform":
			texture = CATWALK
		elif size.y > size.x * 1.5:
			texture = WALL
			v0 = top
		visual.texture = texture
		visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# World-aligned UVs: adjacent modules share seams; walkable tops start at tile row 0.
		visual.uv = PackedVector2Array([
			Vector2(left, v0), Vector2(left + size.x, v0),
			Vector2(left + size.x, v0 + size.y), Vector2(left, v0 + size.y),
		])
		visual.color = Color.WHITE


func _build_street_dressing(modules: Node) -> void:
	var dressing := Node2D.new()
	dressing.name = "StreetDressing"
	dressing.z_index = -9
	add_child(dressing)
	var reflections := Node2D.new()
	reflections.name = "StreetReflections"
	reflections.z_index = 1
	add_child(reflections)
	for module in modules.get_children():
		if not (module is Node2D):
			continue
		var index := int(module.get_meta("module_index", module.get_index()))
		var markers: Array[float] = []
		for child in module.get_children():
			if child is Polygon2D and child.z_index == -10:
				child.color = MODULE_HAZE if is_zero_approx(module.position.y) else MODULE_HAZE_DEEP
			elif child is Marker2D:
				markers.append(child.position.x)
		var lamp_x := -1.0
		if index % 3 != 1:
			for slot_index in LAMP_SLOTS.size():
				var x: float = LAMP_SLOTS[(slot_index + index) % LAMP_SLOTS.size()]
				if _slot_clear(x, markers):
					lamp_x = x
					break
		if lamp_x >= 0.0:
			_add_lamp(dressing, module.position + Vector2(lamp_x, FLOOR_TOP), lamp_x < 420.0)
		if index % 2 == 0:
			var region: Rect2 = PUDDLE_REGIONS[index % PUDDLE_REGIONS.size()]
			var puddle_x := 520.0 if lamp_x < 420.0 else 200.0
			var puddle := Sprite2D.new()
			puddle.texture = PUDDLES
			puddle.centered = false
			puddle.region_enabled = true
			puddle.region_rect = region
			puddle.material = _add_material
			puddle.modulate.a = 0.8
			puddle.position = module.position + Vector2(puddle_x, FLOOR_TOP + 2.0)
			reflections.add_child(puddle)


func _add_lamp(parent: Node2D, foot: Vector2, arm_right: bool) -> void:
	var arm_end := foot + Vector2(28.0 if arm_right else -28.0, -168.0)
	var pole := Polygon2D.new()
	pole.color = POLE_COLOR
	pole.polygon = _rect_polygon(Rect2(foot.x, foot.y - 170.0, 4.0, 170.0))
	parent.add_child(pole)
	var arm := Polygon2D.new()
	arm.color = POLE_COLOR
	arm.polygon = _rect_polygon(Rect2(minf(foot.x, arm_end.x), foot.y - 170.0, 32.0, 3.0))
	parent.add_child(arm)
	var head := Polygon2D.new()
	head.color = LAMP_COLOR
	head.polygon = _rect_polygon(Rect2(arm_end.x - 6.0, arm_end.y + 1.0, 12.0, 3.0))
	parent.add_child(head)
	var cone := Sprite2D.new()
	cone.texture = LAMP_CONE
	cone.centered = false
	cone.material = _add_material
	cone.position = Vector2(arm_end.x - LAMP_CONE.get_width() * 0.5, foot.y - LAMP_CONE.get_height() + 4.0)
	parent.add_child(cone)


func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LowerCityBackdrop"
	layer.layer = BACKDROP_LAYER
	add_child(layer)
	var root := Node2D.new()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(root)
	_sky = Sprite2D.new()
	_sky.texture = SKY
	_sky.centered = false
	root.add_child(_sky)
	var textures := {"far": FAR, "far_beacons": FAR_BEACONS, "fog": FOG, "mid": MID, "mid_glow": MID_GLOW,
		"mid_signs": MID_SIGNS, "rail": RAIL}
	for plane: Array in PLANES:
		if String(plane[0]) == "rail":
			# Street level below the mid buildings: never an empty strip under the skyline.
			_ground = Polygon2D.new()
			_ground.color = GROUND_FILL
			_ground.polygon = _rect_polygon(Rect2(0.0, 0.0, 8192.0, 8192.0))
			root.add_child(_ground)
		var sprite := Sprite2D.new()
		sprite.texture = textures[String(plane[0])]
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.scale = Vector2.ONE * PLANE_SCALE
		sprite.modulate = plane[5]
		if bool(plane[6]):
			sprite.material = _add_material
		root.add_child(sprite)
		_planes.append({"sprite": sprite, "top": plane[1], "follow": Vector2(plane[2], plane[3]), "speed": plane[4], "drift": 0.0})
		if String(plane[0]) == "mid_glow":
			_sign_glow = sprite
		elif String(plane[0]) == "mid_signs":
			_signs = sprite
		elif String(plane[0]) == "far_beacons":
			_beacons = sprite


func _build_rain() -> void:
	for config: Array in [[120, 520.0, 0.30, 0.9], [60, 780.0, 0.55, 1.0]]:
		var amount := roundi(float(config[0]) * VisualQuality.particle_scale())
		if amount <= 0:
			continue  # MINIMAL profile: no rain particles
		var rain := CPUParticles2D.new()
		rain.texture = RAIN_DROP
		rain.amount = amount
		rain.lifetime = 2.0
		rain.preprocess = 2.0
		rain.z_index = 30
		rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		rain.emission_rect_extents = Vector2(760.0, 4.0)
		rain.direction = Vector2(-0.18, 1.0)
		rain.spread = 2.0
		rain.gravity = Vector2.ZERO
		rain.initial_velocity_min = float(config[1])
		rain.initial_velocity_max = float(config[1]) * 1.15
		rain.particle_flag_align_y = true
		rain.scale_amount_min = float(config[3])
		rain.scale_amount_max = float(config[3])
		rain.color = Color(1.0, 1.0, 1.0, float(config[2]))
		add_child(rain)
		_rain.append(rain)


func _update_backdrop(center: Vector2, zoom: float, view: Vector2, delta: float) -> void:
	var floor_y := to_global(Vector2(0.0, _floor_ref_y)).y
	var depth := clampf((floor_y - center.y) * zoom, -view.y * 1.2, view.y * 1.2) - REST_DEPTH
	_sky.scale = view / SKY.get_size()
	for plane in _planes:
		var sprite := plane.sprite as Sprite2D
		var follow := plane.follow as Vector2
		plane["drift"] = float(plane.drift) + float(plane.speed) * delta
		# Whole texture pixels only: fractional offsets shimmer on nearest-filtered pixel art.
		var scroll := (center.x * zoom * follow.x - float(plane.drift)) / PLANE_SCALE
		sprite.region_rect = Rect2(roundf(scroll), 0.0, ceilf(view.x / PLANE_SCALE) + 1.0, sprite.texture.get_height())
		sprite.position = Vector2(0.0, roundf(float(plane.top) + depth * follow.y))
		if sprite.texture == MID:
			_ground.position = Vector2(0.0, sprite.position.y + MID_STREET_ROW)


func _update_rain(center: Vector2, world_view: Vector2) -> void:
	var origin := to_local(center) - Vector2(0.0, world_view.y * 0.5 + 40.0)
	for rain in _rain:
		rain.position = origin
		rain.emission_rect_extents = Vector2(world_view.x * 0.5 + 120.0, 4.0)


func _update_lights(delta: float) -> void:
	# Neon: steady glow with a rare, short brown-out; never a strobe. No RNG.
	_flicker_at -= delta
	if _flicker_at <= 0.0 and VisualQuality.allows_flicker():
		_flicker_left = 0.22
		_flicker_at = 4.0 + fposmod(_clock * 7.31, 5.0)
	var level := 1.0
	if _flicker_left > 0.0:
		_flicker_left -= delta
		level = 0.35 if int(_flicker_left * 40.0) % 2 == 0 else 0.85
	_signs.modulate.a = level
	_sign_glow.modulate.a = level * (0.85 + 0.15 * sin(_clock * 1.7))
	# Aviation beacons: slow 0.5 Hz blink; steady when flicker is disabled.
	_beacons.modulate.a = 1.0 if not VisualQuality.allows_flicker() or fposmod(_clock, 2.0) < 1.0 else 0.25


static func _slot_clear(x: float, markers: Array[float]) -> bool:
	for marker_x in markers:
		if absf(marker_x - x) < SOCKET_CLEARANCE:
			return false
	return true


static func _offset_in(node: Node, root: Node) -> Vector2:
	var offset := Vector2.ZERO
	var current := node
	while current != null and current != root:
		if current is Node2D:
			offset += (current as Node2D).position
		current = current.get_parent()
	return offset


static func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
