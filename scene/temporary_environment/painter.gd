extends RefCounted
## TEMPORARY ENVIRONMENT LIBRARY V2.
## Presentation only: deterministic composition, no gameplay RNG and no frame callbacks.
const DATA = preload("res://scene/temporary_environment/layouts.gd")
const TEXTURES = {
	"industrial_details": preload("res://assets/temporary_environment/architecture/industrial_details.png"),
	"outpost_services": preload("res://assets/temporary_environment/architecture/outpost_services.png"),
	"facade": preload("res://assets/temporary_environment/city/facade.png"),
	"far": preload("res://assets/temporary_environment/city/far.png"),
	"mid": preload("res://assets/temporary_environment/city/mid.png"),
	"hotel": preload("res://assets/temporary_environment/city/hotel.png"),
	"open": preload("res://assets/temporary_environment/city/open.png"),
	"control": preload("res://assets/temporary_environment/city/control.png"),
	"control_large": preload("res://assets/temporary_environment/city/control_large.png"),
	"antenna": preload("res://assets/temporary_environment/city/antenna.png"),
	"sign": preload("res://assets/temporary_environment/city/sign.png"),
	"advert": preload("res://assets/temporary_environment/city/advert.png"),
	"street_far": preload("res://assets/temporary_environment/backgrounds/street_far.png"),
	"lab_2": preload("res://assets/temporary_environment/lab/lab_2.png"),
	"lab_3": preload("res://assets/temporary_environment/lab/lab_3.png"),
	"lab_4": preload("res://assets/temporary_environment/lab/lab_4.png"),
	"lab_5": preload("res://assets/temporary_environment/lab/lab_5.png"),
	"lab_6": preload("res://assets/temporary_environment/lab/lab_6.png"),
	"lab_7": preload("res://assets/temporary_environment/lab/lab_7.png"),
	"lab_8": preload("res://assets/temporary_environment/lab/lab_8.png"),
	"factory": preload("res://assets/temporary_environment/industrial/factory.png"),
}

const CITY_IDENTITIES := [
	"alley",
	"commercial",
	"infrastructure",
	"residential",
	"rooftop",
	"workshop",
	"passage",
	"commercial",
	"infrastructure",
	"rooftop",
	"residential",
	"workshop",
]

const ROLE_LAYOUT_POOLS := {
	"city": {
		"start": [0, 4, 6],
		"exit": [5, 9, 11],
		"reward": [1, 6, 7, 10, 3, 8],
		"combat": [2, 3, 8, 11, 0, 5],
		"traversal": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
	},
	"industrial": {
		"start": [0, 2],
		"exit": [3, 5],
		"reward": [1, 4],
		"combat": [0, 2, 3, 5],
		"traversal": [0, 1, 2, 3, 4, 5],
	},
	"lab": {
		"start": [0, 2],
		"exit": [3, 5],
		"reward": [1, 4],
		"combat": [0, 2, 3, 5],
		"traversal": [0, 1, 2, 3, 4, 5],
	},
}


static func layout_id(family: String, variant: int, grid: Vector2, role: String = "") -> String:
	var count := 12 if family == "city" else 6
	var code := absi(variant * 17 + roundi(grid.x / 840.0) * 30 + roundi(grid.y / 480.0) * 41)
	var index := code % count
	var family_pools: Dictionary = ROLE_LAYOUT_POOLS.get(family, {})
	if not family_pools.is_empty():
		var pool: Array = family_pools.get(role, family_pools.get("traversal", []))
		if not pool.is_empty():
			index = int(pool[code % pool.size()])
	return "%s_%d" % [family, index]


static func identity_for_layout(id: String, role: String = "") -> String:
	if id.begins_with("city_"):
		var index := clampi(int(id.get_slice("_", 1)), 0, CITY_IDENTITIES.size() - 1)
		if role == "reward":
			return "workshop" if index in [3, 8, 11] else "residential" if index in [6, 10] else "commercial"
		if role == "combat":
			return "alley" if index in [0, 5] else "rooftop" if index in [3, 11] else "infrastructure"
		if role in ["start", "exit"]:
			return "transition"
		return String(CITY_IDENTITIES[index])
	if id.begins_with("industrial_"):
		return "heavy_industrial" if int(id.get_slice("_", 1)) % 2 == 0 else "maintenance"
	if id.begins_with("lab_"):
		return "research" if int(id.get_slice("_", 1)) % 2 == 0 else "technical_services"
	return id


static func paint(canvas: CanvasItem, id: String, role: String = "", protected: Array[Rect2] = []) -> void:
	var commands: Array = DATA.LAYOUTS.get(id, [])
	var quiet := _quiet_region(role)
	for command in commands:
		var bounds: Array = command[1]
		var target := Rect2(bounds[0], bounds[1], bounds[2], bounds[3])
		var tag := String(command[4])
		if tag in ["detail", "focal", "ground", "architecture", "mid_depth"]:
			if not _placement_clear(target, protected, quiet):
				continue
		var tint := Color(String(command[3]))
		var asset_id := String(command[0])
		if asset_id.is_empty():
			canvas.draw_rect(target, tint)
		else:
			var region: Array = command[2]
			var source := Rect2(region[0], region[1], region[2], region[3])
			var motion := Vector2.ZERO
			if tag == "far":
				motion = canvas.get_meta("temp_far_offset", Vector2.ZERO)
			elif tag == "mid_depth":
				motion = canvas.get_meta("temp_mid_offset", Vector2.ZERO)
			var moved := Rect2(target.position + motion, target.size)
			var clipped := moved.intersection(target)
			if clipped.has_area():
				var ratio := source.size / target.size
				source.position += (clipped.position - moved.position) * ratio
				source.size = clipped.size * ratio
				canvas.draw_texture_rect_region(TEXTURES[asset_id], clipped, source, tint)
	_paint_identity_overlay(canvas, id, role, protected, quiet)


static func paint_background(canvas: CanvasItem, family: String, area: Rect2, far_offset: Vector2, mid_offset: Vector2) -> void:
	if not area.has_area():
		return
	match family:
		"city":
			_paint_lower_city_background(canvas, area, far_offset, mid_offset)
		"house":
			_paint_city_background(canvas, area, far_offset, mid_offset)
		"industrial":
			_paint_industrial_background(canvas, area, far_offset, mid_offset)
		"lab":
			_paint_lab_background(canvas, area, far_offset, mid_offset)
		_:
			canvas.draw_rect(area, Color("13232e"))


static func surface(canvas: CanvasItem, area: Rect2, kind: String, family: String = "") -> void:
	if not area.has_area():
		return
	var base := Color("293941")
	var edge := Color("99afa8") if kind != "wall" else Color("637e80")
	var inset := Color("52686b")
	var seam := Color("203139")
	match family:
		"city":
			base = Color("30383a")
			edge = Color("9a9986") if kind != "wall" else Color("6f746b")
			inset = Color("5f6258")
			seam = Color("232b2d")
		"industrial":
			base = Color("293234")
			edge = Color("a79b78") if kind != "wall" else Color("74735f")
			inset = Color("645f4c")
			seam = Color("1d2729")
		"lab":
			base = Color("21363b")
			edge = Color("91b5b7") if kind != "wall" else Color("607f82")
			inset = Color("55777a")
			seam = Color("152a30")
	var snapshot := _environment_snapshot(canvas)
	var world_tint: Color = snapshot.get("world_tint", Color.WHITE)
	var world_strength := float(snapshot.get("world_strength", 0.0))
	base = base.lerp(world_tint, world_strength)
	edge = edge.lerp(world_tint, world_strength * 0.55)
	inset = inset.lerp(world_tint, world_strength * 0.75)
	canvas.draw_rect(area, base)
	var top := Rect2(area.position, Vector2(area.size.x, minf(4.0, area.size.y)))
	canvas.draw_rect(top, edge)
	if kind == "wall":
		canvas.draw_rect(Rect2(area.position, Vector2(minf(3.0, area.size.x), area.size.y)), edge.darkened(0.15))
	elif area.size.y > 6.0:
		canvas.draw_rect(Rect2(area.position + Vector2(0, 4), Vector2(area.size.x, 2)), inset)
	var x := area.position.x + 64.0
	while x < area.end.x:
		canvas.draw_rect(Rect2(Vector2(x, area.position.y + minf(6.0, area.size.y)),
			Vector2(minf(2.0, area.end.x - x), maxf(0.0, area.size.y - 6.0))), seam)
		x += 96.0


static func _quiet_region(role: String) -> Rect2:
	match role:
		"start":
			return Rect2(0, 200, 380, 220)
		"combat":
			return Rect2(168, 140, 504, 280)
		"reward":
			return Rect2(220, 180, 400, 240)
		"exit":
			return Rect2(220, 220, 400, 200)
	return Rect2()


static func _placement_clear(target: Rect2, protected: Array[Rect2], quiet: Rect2) -> bool:
	if quiet.has_area() and target.intersects(quiet):
		return false
	for area in protected:
		if target.intersects(area):
			return false
	return true


static func _paint_identity_overlay(canvas: CanvasItem, id: String, role: String, protected: Array[Rect2], quiet: Rect2) -> void:
	if id.begins_with("city_"):
		_paint_city_identity(canvas, identity_for_layout(id, role), protected, quiet)
	elif id.begins_with("industrial_"):
		_paint_industrial_identity(canvas, id, role, protected, quiet)
	elif id.begins_with("lab_"):
		_paint_lab_identity(canvas, id, role, protected, quiet)


static func _paint_city_identity(canvas: CanvasItem, identity: String, protected: Array[Rect2], quiet: Rect2) -> void:
	match identity:
		"alley":
			_arch_rect(canvas, Rect2(24, 76, 22, 282), Color("35444a"), protected, quiet)
			_arch_rect(canvas, Rect2(790, 92, 18, 266), Color("303e45"), protected, quiet)
			canvas.draw_polyline(PackedVector2Array([Vector2(48, 92), Vector2(220, 120), Vector2(422, 104), Vector2(612, 132), Vector2(788, 98)]), Color("1a272f"), 4.0)
			canvas.draw_polyline(PackedVector2Array([Vector2(54, 112), Vector2(250, 148), Vector2(454, 128), Vector2(640, 158), Vector2(784, 126)]), Color("25363d"), 2.0)
		"residential":
			_arch_rect(canvas, Rect2(458, 62, 310, 126), Color("283b43"), protected, quiet)
			for row in 2:
				for column in 5:
					_arch_rect(canvas, Rect2(480 + column * 54, 80 + row * 48, 30, 24), Color("41525a"), protected, quiet)
					_arch_rect(canvas, Rect2(484 + column * 54, 84 + row * 48, 22, 16), Color("172832"), protected, quiet)
			_asset(canvas, "facade", Rect2(684, 270, 64, 128), Rect2(224, 16, 32, 64), Color(0.55, 0.62, 0.60, 0.82), protected, quiet)
		"commercial":
			_arch_rect(canvas, Rect2(40, 88, 260, 72), Color("303e42"), protected, quiet)
			_arch_rect(canvas, Rect2(42, 158, 256, 5), Color("6b6658"), protected, quiet)
			_asset(canvas, "advert", Rect2(74, -8, 70, 184), Rect2(0, 0, 35, 92), Color(0.72, 0.76, 0.62, 0.78), protected, quiet)
			_asset(canvas, "sign", Rect2(746, 18, 38, 152), Rect2(0, 0, 19, 76), Color(0.62, 0.75, 0.72, 0.82), protected, quiet)
			_asset(canvas, "open", Rect2(676, 78, 28, 88), Rect2(0, 0, 14, 44), Color(0.78, 0.66, 0.48, 0.76), protected, quiet)
		"workshop":
			_arch_rect(canvas, Rect2(42, 96, 330, 12), Color("5f6259"), protected, quiet)
			_arch_rect(canvas, Rect2(64, 108, 8, 170), Color("4a5351"), protected, quiet)
			_arch_rect(canvas, Rect2(352, 108, 8, 170), Color("4a5351"), protected, quiet)
			_asset(canvas, "outpost_services", Rect2(92, 130, 64, 96), Rect2(0, 0, 32, 48), Color(0.68, 0.72, 0.68, 0.82), protected, quiet)
			_asset(canvas, "control_large", Rect2(226, 176, 124, 60), Rect2(0, 0, 62, 30), Color(0.62, 0.69, 0.67, 0.78), protected, quiet)
		"infrastructure":
			_arch_rect(canvas, Rect2(38, 68, 764, 10), Color("47555a"), protected, quiet)
			for column_x in [70, 238, 602, 770]:
				_arch_rect(canvas, Rect2(column_x, 78, 10, 148), Color("3d4a50"), protected, quiet)
			canvas.draw_polyline(PackedVector2Array([Vector2(76, 116), Vector2(240, 92), Vector2(420, 124), Vector2(606, 94), Vector2(776, 118)]), Color("26363e"), 4.0)
		"rooftop":
			_arch_rect(canvas, Rect2(28, 326, 784, 18), Color("455154"), protected, quiet)
			_arch_rect(canvas, Rect2(52, 344, 128, 36), Color("303b3e"), protected, quiet)
			_arch_rect(canvas, Rect2(648, 344, 138, 36), Color("303b3e"), protected, quiet)
			_asset(canvas, "antenna", Rect2(726, 30, 44, 192), Rect2(0, 0, 22, 96), Color(0.42, 0.52, 0.56, 0.80), protected, quiet)
		"passage":
			_arch_rect(canvas, Rect2(112, 76, 616, 34), Color("36454b"), protected, quiet)
			_arch_rect(canvas, Rect2(130, 110, 18, 176), Color("344148"), protected, quiet)
			_arch_rect(canvas, Rect2(692, 110, 18, 176), Color("344148"), protected, quiet)
			_arch_rect(canvas, Rect2(148, 116, 544, 5), Color("65706d"), protected, quiet)
		"transition":
			_arch_rect(canvas, Rect2(620, 72, 154, 12), Color("526166"), protected, quiet)
			_arch_rect(canvas, Rect2(620, 84, 10, 154), Color("3c4c53"), protected, quiet)
			_arch_rect(canvas, Rect2(764, 84, 10, 154), Color("3c4c53"), protected, quiet)
			for strip_y in [104, 142, 180]:
				_arch_rect(canvas, Rect2(642, strip_y, 100, 4), Color("66736f"), protected, quiet)


static func _paint_industrial_identity(canvas: CanvasItem, id: String, role: String, protected: Array[Rect2], quiet: Rect2) -> void:
	var index := int(id.get_slice("_", 1))
	var x_shift := 24.0 + float(index % 3) * 28.0
	_arch_rect(canvas, Rect2(x_shift, 58, 780 - x_shift, 14), Color("56584c"), protected, quiet)
	for column_x in [x_shift + 24, x_shift + 232, x_shift + 492, 778.0]:
		_arch_rect(canvas, Rect2(column_x, 72, 12, 188), Color("444b48"), protected, quiet)
	_asset(canvas, "industrial_details", Rect2(x_shift + 50, 90, 160, 64), Rect2(64, 112, 80, 32), Color(0.55, 0.60, 0.56, 0.78), protected, quiet)
	if index % 2 == 1 or role == "reward":
		_asset(canvas, "factory", Rect2(650, 278, 64, 64), Rect2(172, 104, 32, 32), Color(0.68, 0.65, 0.52, 0.82), protected, quiet)
	else:
		_asset(canvas, "control_large", Rect2(626, 176, 124, 60), Rect2(0, 0, 62, 30), Color(0.60, 0.63, 0.56, 0.76), protected, quiet)


static func _paint_lab_identity(canvas: CanvasItem, id: String, role: String, protected: Array[Rect2], quiet: Rect2) -> void:
	var index := int(id.get_slice("_", 1))
	var panel_x := 60.0 + float(index % 3) * 48.0
	_arch_rect(canvas, Rect2(panel_x, 54, 690, 8), Color("5d7d80"), protected, quiet)
	_arch_rect(canvas, Rect2(panel_x, 62, 8, 202), Color("3f5b61"), protected, quiet)
	_arch_rect(canvas, Rect2(panel_x + 682, 62, 8, 202), Color("3f5b61"), protected, quiet)
	for panel_column_x in [panel_x + 36, panel_x + 184, panel_x + 332, panel_x + 480]:
		_arch_rect(canvas, Rect2(panel_column_x, 88, 104, 50), Color("20383f"), protected, quiet)
		_arch_rect(canvas, Rect2(panel_column_x + 6, 94, 92, 3), Color("67999b"), protected, quiet)
	var lab_asset := "lab_5" if index % 2 == 0 else "lab_3"
	_asset(canvas, lab_asset, Rect2(92, 250, 96, 96), Rect2(0, 0, 32, 32), Color(0.68, 0.78, 0.73, 0.86), protected, quiet)
	if role == "reward":
		_asset(canvas, "lab_4", Rect2(664, 278, 64, 64), Rect2(0, 0, 32, 32), Color(0.64, 0.78, 0.76, 0.90), protected, quiet)


static func _arch_rect(canvas: CanvasItem, target: Rect2, color: Color, protected: Array[Rect2], quiet: Rect2) -> void:
	if _placement_clear(target, protected, quiet):
		canvas.draw_rect(target, color)


static func _asset(canvas: CanvasItem, asset_id: String, target: Rect2, source: Rect2, tint: Color, protected: Array[Rect2], quiet: Rect2) -> void:
	if _placement_clear(target, protected, quiet):
		canvas.draw_texture_rect_region(TEXTURES[asset_id], target, source, tint)


static func _paint_lower_city_background(canvas: CanvasItem, area: Rect2, far_offset: Vector2, mid_offset: Vector2) -> void:
	# City-specific licensed temporary silhouettes and facades. The approved
	# House still uses its original background composition below.
	var snapshot := _environment_snapshot(canvas)
	var sky_top: Color = snapshot.get("sky_top", Color("08131f"))
	var sky_horizon: Color = snapshot.get("sky_horizon", Color("102231"))
	var far_tint: Color = snapshot.get("far_tint", Color("71839a"))
	var mid_tint: Color = snapshot.get("mid_tint", Color("6c7682"))
	canvas.draw_rect(area, sky_top)
	var row := floori((area.position.y - 480.0) / 480.0) * 480
	while row < area.end.y + 480.0:
		var haze := Rect2(area.position.x, row - 90.0, area.size.x, 175.0)
		if haze.intersects(area):
			canvas.draw_rect(haze.intersection(area), sky_horizon.darkened(0.35))
		_tiled_texture(canvas, "far", area, Rect2(0, 0, 144, 124), Vector2(432, 372),
			row - 232.0 + far_offset.y, far_offset.x, Color(far_tint.r, far_tint.g, far_tint.b, 0.65))
		_tiled_texture(canvas, "mid", area, Rect2(0, 0, 493, 209), Vector2(493, 209),
			row + 85.0 + mid_offset.y, mid_offset.x, Color(mid_tint.r, mid_tint.g, mid_tint.b, 0.78))
		row += 480
	_paint_celestial_body(canvas, area, snapshot)


static func _paint_city_background(canvas: CanvasItem, area: Rect2, far_offset: Vector2, mid_offset: Vector2) -> void:
	var snapshot := _environment_snapshot(canvas)
	var sky_top: Color = snapshot.get("sky_top", Color("08131f"))
	var sky_horizon: Color = snapshot.get("sky_horizon", Color("102231"))
	var far_tint: Color = snapshot.get("far_tint", Color("71839a"))
	var mid_tint: Color = snapshot.get("mid_tint", Color("6c7682"))
	canvas.draw_rect(area, sky_top)
	var row := floori((area.position.y - 480.0) / 480.0) * 480
	while row < area.end.y + 480.0:
		var sky_band := Rect2(area.position.x, row - 360.0, area.size.x, 260.0)
		if sky_band.intersects(area):
			canvas.draw_rect(sky_band, sky_top)
		var haze_band := Rect2(area.position.x, row - 100.0, area.size.x, 180.0)
		if haze_band.intersects(area):
			canvas.draw_rect(haze_band, sky_horizon.darkened(0.34))
		_tiled_texture(canvas, "street_far", area, Rect2(0, 0, 256, 192), Vector2(512, 384),
			row - 220.0 + far_offset.y, far_offset.x, Color(far_tint.r, far_tint.g, far_tint.b, 0.68))
		_tiled_texture(canvas, "mid", area, Rect2(0, 0, 493, 209), Vector2(493, 209),
			row + 58.0 + mid_offset.y, mid_offset.x, Color(mid_tint.r, mid_tint.g, mid_tint.b, 0.72))
		row += 480
	_paint_celestial_body(canvas, area, snapshot)


static func _paint_industrial_background(canvas: CanvasItem, area: Rect2, far_offset: Vector2, mid_offset: Vector2) -> void:
	var snapshot := _environment_snapshot(canvas)
	var sky_top: Color = snapshot.get("sky_top", Color("0b1518")).darkened(0.28)
	var sky_horizon: Color = snapshot.get("sky_horizon", Color("152326")).darkened(0.42)
	canvas.draw_rect(area, sky_top)
	var row := floori((area.position.y - 480.0) / 480.0) * 480
	while row < area.end.y + 480.0:
		var far_x := floori((area.position.x - far_offset.x) / 320.0) * 320.0 + far_offset.x - 320.0
		while far_x < area.end.x + 320.0:
			var tower := Rect2(far_x, row - 150.0 + far_offset.y, 104, 354)
			if tower.intersects(area):
				canvas.draw_rect(tower, Color("142124"))
				canvas.draw_rect(Rect2(tower.position + Vector2(14, 28), Vector2(76, 8)), Color("263537"))
				canvas.draw_rect(Rect2(tower.position + Vector2(44, -42), Vector2(16, 42)), Color("1a292c"))
			far_x += 320.0
		var haze_band := Rect2(area.position.x, row - 80.0, area.size.x, 150.0)
		if haze_band.intersects(area):
			canvas.draw_rect(haze_band, Color(sky_horizon.r, sky_horizon.g, sky_horizon.b, 0.34))
		_tiled_texture(canvas, "industrial_details", area, Rect2(64, 112, 80, 32), Vector2(160, 64),
			row + 118.0 + mid_offset.y, mid_offset.x, Color(0.43, 0.48, 0.43, 0.68))
		var beam_y := row + 212.0 + mid_offset.y
		if beam_y > area.position.y - 20 and beam_y < area.end.y + 20:
			canvas.draw_rect(Rect2(area.position.x, beam_y, area.size.x, 12), Color("303b39"))
		row += 480
	_paint_celestial_body(canvas, area, snapshot)


static func _paint_lab_background(canvas: CanvasItem, area: Rect2, far_offset: Vector2, mid_offset: Vector2) -> void:
	var snapshot := _environment_snapshot(canvas)
	var ambient: Color = snapshot.get("world_tint", Color("30445a"))
	canvas.draw_rect(area, Color("07151a").lerp(ambient, 0.12))
	var row := floori((area.position.y - 480.0) / 480.0) * 480
	while row < area.end.y + 480.0:
		var panel_x := floori((area.position.x - far_offset.x) / 272.0) * 272.0 + far_offset.x - 272.0
		while panel_x < area.end.x + 272.0:
			var panel := Rect2(panel_x, row - 104.0 + far_offset.y, 244, 252)
			if panel.intersects(area):
				canvas.draw_rect(panel, Color("10262d"))
				canvas.draw_rect(Rect2(panel.position + Vector2(10, 12), panel.size - Vector2(20, 24)), Color("0c1d23"))
				canvas.draw_rect(Rect2(panel.position + Vector2(18, 28), Vector2(panel.size.x - 36, 4)), Color("31525a"))
			panel_x += 272.0
		var light_y := row + 74.0 + mid_offset.y
		if light_y > area.position.y - 16 and light_y < area.end.y + 16:
			canvas.draw_rect(Rect2(area.position.x, light_y, area.size.x, 5), Color("416d73"))
		_tiled_texture(canvas, "outpost_services", area, Rect2(32, 48, 16, 32), Vector2(32, 64),
			row + 154.0 + mid_offset.y, mid_offset.x, Color(0.50, 0.62, 0.62, 0.70), 176.0)
		row += 480


static func _environment_snapshot(canvas: CanvasItem) -> Dictionary:
	var value: Variant = canvas.get_meta("temp_environment_snapshot", {})
	return value as Dictionary if value is Dictionary else {}


static func _paint_celestial_body(canvas: CanvasItem, area: Rect2, snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var normalized := float(snapshot.get("normalized_time", 0.0))
	var bounds_value: Variant = canvas.get_meta("temp_environment_bounds", area)
	var bounds := bounds_value as Rect2 if bounds_value is Rect2 else area
	if not bounds.has_area():
		bounds = area
	var x := lerpf(bounds.position.x + bounds.size.x * 0.08, bounds.end.x - bounds.size.x * 0.08, normalized)
	var arc := sin(normalized * PI)
	var y := bounds.position.y + 92.0 - arc * 120.0
	var position := Vector2(x, y)
	if not area.grow(40.0).has_point(position):
		return
	var phase := StringName(snapshot.get("phase", &"day"))
	var is_night := phase in [&"night", &"late_night"]
	var body_color := Color(0.73, 0.82, 1.0, 0.78) if is_night else Color(1.0, 0.79, 0.46, 0.82)
	canvas.draw_circle(position, 18.0 if is_night else 22.0, body_color)


static func _tiled_texture(canvas: CanvasItem, asset_id: String, area: Rect2, source: Rect2, target_size: Vector2,
	y: float, x_offset: float, tint: Color, step_override: float = 0.0) -> void:
	var step_x := step_override if step_override > 0.0 else target_size.x
	var x := floori((area.position.x - x_offset) / step_x) * step_x + x_offset - step_x
	while x < area.end.x + step_x:
		var target := Rect2(Vector2(x, y), target_size)
		if target.intersects(area):
			canvas.draw_texture_rect_region(TEXTURES[asset_id], target, source, tint)
		x += step_x
