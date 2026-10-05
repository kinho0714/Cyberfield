extends RefCounted
## TEMPORARY ENVIRONMENT LIBRARY V1: shared textures, no nodes or frame callbacks.
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


static func layout_id(family: String, variant: int, grid: Vector2) -> String:
	var count := 12 if family == "city" else 6
	var code := absi(variant * 17 + roundi(grid.x / 840.0) * 30 + roundi(grid.y / 480.0) * 41)
	return "%s_%d" % [family, code % count]


static func paint(canvas: CanvasItem, id: String, role: String = "", protected: Array[Rect2] = []) -> void:
	var commands: Array = DATA.LAYOUTS.get(id, [])
	var quiet := Rect2()
	match role:
		"start": quiet = Rect2(0, 200, 380, 220)
		"combat": quiet = Rect2(168, 140, 504, 280)
		"reward": quiet = Rect2(220, 180, 400, 240)
		"exit": quiet = Rect2(220, 220, 400, 200)
	for command in commands:
		var bounds: Array = command[1]
		var target := Rect2(bounds[0], bounds[1], bounds[2], bounds[3])
		var tag := String(command[4])
		if tag in ["detail", "focal", "ground", "architecture", "mid_depth"]:
			if quiet.has_area() and target.intersects(quiet):
				continue
			var obstructs := false
			for area in protected:
				if target.intersects(area):
					obstructs = true
					break
			if obstructs:
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
			# Finite window clipping: source/target stay proportional, no scaling or wrap seams.
			var moved := Rect2(target.position + motion, target.size)
			var clipped := moved.intersection(target)
			if clipped.has_area():
				var ratio := source.size / target.size
				source.position += (clipped.position - moved.position) * ratio
				source.size = clipped.size * ratio
				canvas.draw_texture_rect_region(TEXTURES[asset_id], clipped, source, tint)


static func surface(canvas: CanvasItem, area: Rect2, kind: String) -> void:
	# All strokes stay INSIDE the authoritative collision rectangle, including tiny final pieces.
	if not area.has_area():
		return
	canvas.draw_rect(area, Color("293941"))
	var top := Rect2(area.position, Vector2(area.size.x, minf(4.0, area.size.y)))
	canvas.draw_rect(top, Color("99afa8") if kind != "wall" else Color("637e80"))
	if kind == "wall":
		canvas.draw_rect(Rect2(area.position, Vector2(minf(3.0, area.size.x), area.size.y)), Color("6d8786"))
	elif area.size.y > 6.0:
		canvas.draw_rect(Rect2(area.position + Vector2(0, 4), Vector2(area.size.x, 2)), Color("52686b"))
	# Wide seams establish material without repeating dense old atlas motifs.
	var x := area.position.x + 64.0
	while x < area.end.x:
		canvas.draw_rect(Rect2(Vector2(x, area.position.y + minf(6.0, area.size.y)),
			Vector2(minf(2.0, area.end.x - x), maxf(0.0, area.size.y - 6.0))), Color("203139"))
		x += 96.0
