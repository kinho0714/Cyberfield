extends Node2D
## Biome visual theme (Operação Renascimento, 30/10/2026). Presentation only.
## One data-driven renderer for every gameplay biome: styles live in biome_styles.gd,
## generated with the art by tools/visual/biome_art.py. BiomeGenerator (and the boss
## stage) call build() after layout, content and signature exist. Nothing here touches
## RNG, collision shapes, IDs or input; choices derive from module indices, so LAN peers
## with the same layout see the same scenery. Effects obey VisualQuality.

const STYLES = preload("res://scene/biomes/visual/biome_styles.gd")
const FLOOR_TOP := 420.0
const GROUND_ROW := 660.0
const REST_DEPTH := 36.0
const BACKDROP_LAYER := -10
const PLANE_SCALE := 2.0
const LAMP_SLOTS := [150.0, 690.0]
const SOCKET_CLEARANCE := 96.0
const TRAIN_PERIOD := 34.0
const TRAIN_SPEED := 260.0
# Lit edge of the generator's sealed bulkheads, per dressing family.
const BULKHEAD_EDGE := {"city": Color("ff4fb4"), "industrial": Color("ffb347"), "lab": Color("39dff2"), "core": Color("ff2a6d")}

var style_id: StringName = &""
var _style: Dictionary = {}
var _textures: Dictionary = {}
var _add_material: CanvasItemMaterial
var _floor_ref_y := FLOOR_TOP
var _sky: Sprite2D
var _ground: Polygon2D
var _planes: Array[Dictionary] = []
var _anchor: Sprite2D
var _train: Sprite2D
var _rail: Sprite2D
var _blinkers: Array[CanvasItem] = []
var _pulsers: Array[CanvasItem] = []
var _spinners: Array[Node2D] = []
var _weather: Array[CPUParticles2D] = []
var _clock := 0.0
var _flicker_at := 4.0
var _flicker_left := 0.0


## generator: BiomeGenerator or the boss stage. skin_untagged: also skin bodies without
## a collision_role (authored scenes such as the boss stage).
func build(generator: Node2D, id: StringName, skin_untagged := false) -> void:
	style_id = id
	_style = STYLES.STYLES.get(id, {})
	name = "BiomeVisual"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_material = CanvasItemMaterial.new()
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if _style.is_empty():
		push_warning("Unknown biome visual style: %s" % id)
		return
	if generator.has_method("get_start_position"):
		_floor_ref_y = generator.get_start_position().y + 36.0
	_skin_geometry(generator, skin_untagged)
	var modules := generator.get_node_or_null("Modules")
	if modules != null:
		_dress_modules(modules)
	else:
		_soften_backgrounds(generator)
		_dress_flat(generator)
	_build_backdrop()
	_build_weather()


func _process(delta: float) -> void:
	if _style.is_empty():
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	_clock += delta
	var view := get_viewport_rect().size
	var center := camera.get_screen_center_position()
	_update_backdrop(center, camera.zoom.x, view, delta)
	_update_weather(center, view / camera.zoom)
	_update_lights(delta)


# ---------------------------------------------------------------- textures
func _tex(file: String) -> Texture2D:
	if _textures.has(file):
		return _textures[file]
	var path := String(_style.dir) + file + ".png"
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_textures[file] = texture
	return texture


# ---------------------------------------------------------------- playable surfaces
func _skin_geometry(generator: Node2D, skin_untagged: bool) -> void:
	var floor := _tex("floor_tile")
	var catwalk := _tex("catwalk_tile")
	var wall := _tex("wall_tile")
	for body in generator.find_children("*", "StaticBody2D", true, false):
		var role: StringName = body.get_meta("collision_role", &"solid_structure" if skin_untagged else &"")
		if role == &"procedural_guard_rail":
			_skin_bulkhead(body, generator, wall)
			continue
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
		var offset := _offset_in(body, generator)
		var left := offset.x - size.x * 0.5
		var top := offset.y - size.y * 0.5
		var texture: Texture2D = floor
		var v0 := 0.0
		if role == &"one_way_platform":
			texture = catwalk
		elif size.y > size.x * 1.5:
			texture = wall
			v0 = top
		if texture == null:
			continue
		visual.texture = texture
		visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# World-aligned U (no seams between modules); a slab taller than its tile shows the
		# tile once, stretched, so the lit top edge never repeats further down.
		var v1 := v0 + size.y
		if texture != wall and size.y > texture.get_height():
			v1 = v0 + texture.get_height()
		visual.uv = PackedVector2Array([
			Vector2(left, v0), Vector2(left + size.x, v0),
			Vector2(left + size.x, v1), Vector2(left, v1),
		])
		visual.color = Color.WHITE


## Sealed module edges (BiomeGenerator._add_guard_rail_bulkhead): flat teal slabs before.
func _skin_bulkhead(body: Node, generator: Node2D, wall: Texture2D) -> void:
	var bulkhead := body.get_node_or_null("Bulkhead") as Polygon2D
	if bulkhead != null and wall != null:
		var offset := _offset_in(body, generator)
		bulkhead.texture = wall
		bulkhead.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		bulkhead.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bulkhead.color = Color(0.72, 0.72, 0.78)
		var uv := PackedVector2Array()
		for point in bulkhead.polygon:
			uv.append(point + offset)
		bulkhead.uv = uv
	var edge := body.get_node_or_null("BulkheadEdge") as Polygon2D
	if edge != null:
		edge.color = BULKHEAD_EDGE.get(String(_style.dressing), edge.color)


func _soften_backgrounds(root: Node) -> void:
	for child in root.get_children():
		if child is Polygon2D and child.z_index == -10:
			child.color = _style.haze


# ---------------------------------------------------------------- dressing
func _dress_modules(modules: Node) -> void:
	var back := _layer("Dressing", -9)
	var front := _layer("DressingLight", 1)
	for module in modules.get_children():
		if not (module is Node2D):
			continue
		var index := int(module.get_meta("module_index", module.get_index()))
		var markers: Array[float] = []
		for child in module.get_children():
			if child is Polygon2D and child.z_index == -10:
				child.color = _style.haze if is_zero_approx(module.position.y) else _style.haze_deep
			elif child is Marker2D:
				markers.append(child.position.x)
		var spans := _floor_spans(module)
		var origin: Vector2 = module.position
		match String(_style.dressing):
			"city":
				_dress_city(back, front, origin, index, markers, spans)
			"industrial":
				_dress_industrial(back, front, origin, index, markers, spans)
			"lab":
				_dress_lab(back, front, origin, index, markers, spans)
			"core":
				if index % 2 == 0:
					_floor_prop(back, front, origin, 214.0, "pylon", "pylon_glow", Vector2(-14, -120), Vector2(-35, -135), markers, spans, &"pulse")


func _dress_city(back: Node2D, front: Node2D, origin: Vector2, index: int, markers: Array[float], spans: Array[Vector2]) -> void:
	if index % 2 == 1 and _fits(300.0, 520.0, spans):
		for x in range(300, 520, 48):
			_sprite(back, "fence", origin + Vector2(x, FLOOR_TOP - 52))
	if index % 3 != 1:
		var lx: float = LAMP_SLOTS[index % 2]
		if _clear(lx, markers) and _fits(lx - 4.0, lx + 4.0, spans):
			_sprite(back, "lamp", origin + Vector2(lx - 20, FLOOR_TOP - 180))
			_sprite(back, "lamp_cone", origin + Vector2(lx - 75, FLOOR_TOP - 156), true)
			_sprite(back, "lamp_glow", origin + Vector2(lx - 36, FLOOR_TOP - 190), true)
	if index % 4 == 2:
		_floor_prop(back, front, origin, 436.0, "board", "board_glow", Vector2(-56, -86), Vector2(-75, -98), markers, spans)
	if index % 3 == 1:
		_floor_prop(back, front, origin, 635.0, "crates", "", Vector2(-35, -30), Vector2.ZERO, markers, spans)
		_floor_prop(back, front, origin, 685.0, "ac", "", Vector2(-13, -20), Vector2.ZERO, markers, spans)
	var rx := 520.0 if index % 2 == 0 else 180.0
	if _fits(rx, rx + 160.0, spans):
		_sprite(front, "reflection", origin + Vector2(rx, FLOOR_TOP + 2), true)


func _dress_industrial(back: Node2D, front: Node2D, origin: Vector2, index: int, markers: Array[float], spans: Array[Vector2]) -> void:
	_sprite(back, "pipes", origin + Vector2(40.0 if index % 2 else 760.0, FLOOR_TOP - 200))
	if index % 3 != 1:
		var lx: float = LAMP_SLOTS[index % 2]
		if _clear(lx, markers) and _fits(lx, lx + 12.0, spans):
			_sprite(back, "lamp", origin + Vector2(lx - 10, FLOOR_TOP - 190))
			_sprite(back, "lamp_cone", origin + Vector2(lx - 48, FLOOR_TOP - 172), true)
			_sprite(back, "lamp_glow", origin + Vector2(lx + 7, FLOOR_TOP - 196), true)
	if index % 2 == 0:
		_floor_prop(back, front, origin, 432.0, "vent", "vent_glow", Vector2(-32, -44), Vector2(-60, -92), markers, spans, &"pulse")
	if index % 3 == 1:
		_floor_prop(back, front, origin, 622.0, "barrels", "", Vector2(-22, -30), Vector2.ZERO, markers, spans)
		_floor_prop(back, front, origin, 286.0, "post", "post_glow", Vector2(-6, -46), Vector2(-15, -52), markers, spans, &"blink")
	if index % 4 == 0:
		var gear := _sprite(back, "gear", origin + Vector2(564, 164))
		if gear != null:
			gear.centered = true  # spins around its own centre
			_spinners.append(gear)


func _dress_lab(back: Node2D, front: Node2D, origin: Vector2, index: int, markers: Array[float], spans: Array[Vector2]) -> void:
	var hx := 260.0 if index % 2 else 560.0
	_sprite(back, "hang_lamp", origin + Vector2(hx, 0))
	_sprite(back, "hang_cone", origin + Vector2(hx - 50, 136), true)
	if index % 3 != 1:
		var lx: float = LAMP_SLOTS[index % 2]
		_floor_prop(back, front, origin, lx, "tank", "tank_glow", Vector2(-17, -92), Vector2(-40, -106), markers, spans, &"pulse")
	if index % 2 == 0:
		_floor_prop(back, front, origin, 432.0, "terminal", "terminal_glow", Vector2(-32, -46), Vector2(-45, -70), markers, spans, &"blink")
	if index % 3 == 1:
		_floor_prop(back, front, origin, 635.0, "rack", "", Vector2(-15, -70), Vector2.ZERO, markers, spans)
		_floor_prop(back, front, origin, 667.0, "rack", "", Vector2(-15, -70), Vector2.ZERO, markers, spans)


func _dress_flat(root: Node2D) -> void:
	# Authored arenas (boss stage): a pair of props at the edges of the main floor.
	if String(_style.dressing) != "core":
		return
	var back := _layer("Dressing", -9)
	var front := _layer("DressingLight", 1)
	var floor_y := _floor_ref_y
	for x in [200.0, 1400.0]:
		var spans: Array[Vector2] = [Vector2(-INF, INF)]
		var markers: Array[float] = []
		_floor_prop(back, front, Vector2(0.0, floor_y - FLOOR_TOP), x, "pylon", "pylon_glow", Vector2(-14, -120), Vector2(-35, -135), markers, spans, &"pulse")


func _floor_prop(back: Node2D, front: Node2D, origin: Vector2, x: float, file: String, glow_file: String,
		offset: Vector2, glow_offset: Vector2, markers: Array[float], spans: Array[Vector2], animation: StringName = &"") -> void:
	var texture := _tex(file)
	if texture == null or not _clear(x, markers) or not _fits(x + offset.x, x + offset.x + texture.get_width(), spans):
		return
	_sprite(back, file, origin + Vector2(x, FLOOR_TOP) + offset)
	if glow_file.is_empty():
		return
	var glow := _sprite(front, glow_file, origin + Vector2(x, FLOOR_TOP) + glow_offset, true)
	if glow != null:
		if animation == &"pulse":
			_pulsers.append(glow)
		elif animation == &"blink":
			_blinkers.append(glow)


func _floor_spans(module: Node) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for child in module.get_children():
		if not (child is StaticBody2D) or child.get_meta("collision_role", &"") != &"solid_structure":
			continue
		for shape_node in child.get_children():
			if shape_node is CollisionShape2D and shape_node.shape is RectangleShape2D:
				var size: Vector2 = shape_node.shape.size
				var top: float = child.position.y + shape_node.position.y - size.y * 0.5
				if absf(top - FLOOR_TOP) < 1.0 and size.x > size.y:
					var left: float = child.position.x + shape_node.position.x - size.x * 0.5
					spans.append(Vector2(left, left + size.x))
	return spans


static func _fits(x0: float, x1: float, spans: Array[Vector2]) -> bool:
	for span in spans:
		if x0 >= span.x and x1 <= span.y:
			return true
	return false


static func _clear(x: float, markers: Array[float]) -> bool:
	for marker_x in markers:
		if absf(marker_x - x) < SOCKET_CLEARANCE:
			return false
	return true


func _layer(node_name: String, z: int) -> Node2D:
	var layer := Node2D.new()
	layer.name = node_name
	layer.z_index = z
	add_child(layer)
	return layer


func _sprite(parent: Node2D, file: String, at: Vector2, additive := false) -> Sprite2D:
	var texture := _tex(file)
	if texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at
	if additive:
		sprite.material = _add_material
	parent.add_child(sprite)
	return sprite


# ---------------------------------------------------------------- backdrop
func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BiomeBackdrop"
	layer.layer = BACKDROP_LAYER
	add_child(layer)
	var root := Node2D.new()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(root)
	_sky = Sprite2D.new()
	_sky.texture = _tex("sky")
	_sky.centered = false
	root.add_child(_sky)
	for plane: Array in _style.planes:
		var texture := _tex(String(plane[0]))
		if texture == null:
			continue
		var role := String(plane[7])
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.scale = Vector2.ONE * PLANE_SCALE
		sprite.modulate = plane[5]
		if bool(plane[6]):
			sprite.material = _add_material
		if role == "under":
			# Street level and below: never an empty strip under the skyline.
			_ground = Polygon2D.new()
			_ground.color = _style.ground_fill
			_ground.polygon = PackedVector2Array([Vector2.ZERO, Vector2(8192, 0), Vector2(8192, 8192), Vector2(0, 8192)])
			root.add_child(_ground)
		root.add_child(sprite)
		var tint: Color = plane[5]
		_planes.append({"sprite": sprite, "top": float(plane[1]), "follow": Vector2(plane[2], plane[3]),
			"speed": float(plane[4]), "drift": 0.0, "role": role, "base": tint.a})
		if role == "anchor":
			_anchor = sprite
		elif role == "rail":
			_rail = sprite
	var train_texture := _tex("train")
	if train_texture != null and _rail != null:
		_train = Sprite2D.new()
		_train.texture = train_texture
		_train.centered = false
		_train.scale = Vector2.ONE * PLANE_SCALE
		_train.modulate = _rail.modulate
		root.add_child(_train)


func _update_backdrop(center: Vector2, zoom: float, view: Vector2, delta: float) -> void:
	var floor_y := to_global(Vector2(0.0, _floor_ref_y)).y
	var depth := clampf((floor_y - center.y) * zoom, -view.y * 1.2, view.y * 1.2) - REST_DEPTH
	if _sky.texture != null:
		_sky.scale = view / _sky.texture.get_size()
	var anchor_y := 0.0
	for plane in _planes:
		var sprite := plane.sprite as Sprite2D
		var follow := plane.follow as Vector2
		plane["drift"] = float(plane.drift) + float(plane.speed) * delta
		# Whole texture pixels only: fractional offsets shimmer on nearest-filtered art.
		var scroll := (center.x * zoom * follow.x - float(plane.drift)) / PLANE_SCALE
		var y := roundf(float(plane.top) + depth * follow.y)
		var rows := float(sprite.texture.get_height())
		if plane.role == "anchor":
			anchor_y = y
		elif plane.role == "under":
			y = anchor_y + GROUND_ROW
			_ground.position = Vector2(0.0, y)
			# Below street level the substructure repeats down to the screen edge, so
			# shafts and descents never show an empty (black) fill.
			rows = maxf(rows, ceilf((view.y - y) / PLANE_SCALE) + 1.0)
		sprite.region_rect = Rect2(roundf(scroll), 0.0, ceilf(view.x / PLANE_SCALE) + 1.0, rows)
		sprite.position = Vector2(0.0, y)
	if _train != null:
		var cycle := fposmod(_clock, TRAIN_PERIOD)
		_train.position = Vector2(view.x + 40.0 - cycle * TRAIN_SPEED, _rail.position.y + 300.0 - 32.0)
		_train.visible = _train.position.x > -_train.texture.get_width() * PLANE_SCALE


# ---------------------------------------------------------------- weather
func _build_weather() -> void:
	var configs: Array = {
		"rain": [[120, Vector2(-0.18, 1.0), 520.0, 2.0, Color(0.75, 0.8, 1.0, 0.35), Vector2.ZERO, 1.0], [60, Vector2(-0.18, 1.0), 780.0, 2.0, Color(0.8, 0.85, 1.0, 0.55), Vector2.ZERO, 1.0]],
		"embers": [[40, Vector2(0.2, -1.0), 50.0, 4.0, Color(1.0, 0.55, 0.2, 0.9), Vector2(8.0, -14.0), 2.0]],
		"dust": [[28, Vector2(0.4, -0.2), 10.0, 6.0, Color(0.7, 0.95, 1.0, 0.45), Vector2(2.0, -1.0), 1.5]],
		"sparks": [[34, Vector2(0.0, -1.0), 70.0, 3.0, Color(1.0, 0.25, 0.35, 0.9), Vector2(0.0, -10.0), 2.0]],
	}.get(String(_style.weather), [])
	var rain_drop := _tex("rain_drop")
	for config: Array in configs:
		var amount := roundi(float(config[0]) * VisualQuality.particle_scale())
		if amount <= 0:
			continue
		var particles := CPUParticles2D.new()
		particles.amount = amount
		particles.lifetime = float(config[3])
		particles.preprocess = float(config[3])
		particles.z_index = 30
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.direction = config[1]
		particles.spread = 2.0 if String(_style.weather) == "rain" else 25.0
		particles.gravity = config[5]
		particles.initial_velocity_min = float(config[2])
		particles.initial_velocity_max = float(config[2]) * 1.2
		particles.color = config[4]
		particles.scale_amount_min = float(config[6])
		particles.scale_amount_max = float(config[6])
		if String(_style.weather) == "rain":
			particles.texture = rain_drop
			particles.particle_flag_align_y = true
		add_child(particles)
		_weather.append(particles)


func _update_weather(center: Vector2, world_view: Vector2) -> void:
	var raining := String(_style.weather) == "rain"
	for particles in _weather:
		# Rain falls from above the view; embers, dust and sparks rise through it.
		particles.position = to_local(center) - Vector2(0.0, world_view.y * 0.5 + 40.0) if raining else to_local(center) + Vector2(0.0, world_view.y * 0.25)
		particles.emission_rect_extents = Vector2(world_view.x * 0.5 + 120.0, 4.0 if raining else world_view.y * 0.3)


# ---------------------------------------------------------------- lights
func _update_lights(delta: float) -> void:
	var flicker := VisualQuality.allows_flicker()
	_flicker_at -= delta
	if _flicker_at <= 0.0 and flicker:
		_flicker_left = 0.22
		_flicker_at = 4.0 + fposmod(_clock * 7.31, 5.0)
	var level := 1.0
	if _flicker_left > 0.0:
		_flicker_left -= delta
		level = 0.35 if int(_flicker_left * 40.0) % 2 == 0 else 0.85
	var pulse := 0.75 + 0.25 * sin(_clock * 1.6)
	for plane in _planes:
		var sprite := plane.sprite as Sprite2D
		match String(plane.role):
			"signs":
				sprite.modulate.a = float(plane.base) * level
			"glow":
				sprite.modulate.a = float(plane.base) * level * (0.85 + 0.15 * sin(_clock * 1.7))
			"beacons":
				sprite.modulate.a = 1.0 if not flicker or fposmod(_clock, 2.0) < 1.0 else 0.25
			"pulse":
				sprite.modulate.a = float(plane.base) * pulse
	for glow in _pulsers:
		glow.modulate.a = pulse
	for glow in _blinkers:
		glow.modulate.a = 1.0 if not flicker or fposmod(_clock, 1.4) < 0.9 else 0.3
	for gear in _spinners:
		gear.rotation += delta * 0.6


static func _offset_in(node: Node, root: Node) -> Vector2:
	var offset := Vector2.ZERO
	var current := node
	while current != null and current != root:
		if current is Node2D:
			offset += (current as Node2D).position
		current = current.get_parent()
	return offset
