extends Node2D
## Architectural composition in world space. Geometry and interaction nodes stay in the Hub.
const STRUCTURE = preload("res://assets/environment/casa_jhon/assets/structural/casa_jhon_structural_base_stage0_v1.png")
const DOMESTIC = preload("res://assets/environment/casa_jhon/assets/props/casa_jhon_props_domestic_stage0_v1.png")
const WORKSHOP = preload("res://assets/environment/casa_jhon/assets/props/casa_jhon_props_workshop_stage0_v1.png")
const FLOOR_Y := 643.0


func _ready() -> void:
	z_index = -20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _tile(region: Rect2, area: Rect2, tint: Color) -> void:
	var y := area.position.y
	while y < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			var extent := Vector2(minf(region.size.x, area.end.x - x), minf(region.size.y, area.end.y - y))
			draw_texture_rect_region(STRUCTURE, Rect2(Vector2(x, y), extent), Rect2(region.position, extent), tint)
			x += region.size.x
		y += region.size.y


func _prop(texture: Texture2D, region: Rect2, feet: Vector2, factor: float = 2.0) -> void:
	# Explicit integer display scale: doors ~140px, furniture ~116px, player ~64px.
	# PNGs remain byte-identical; nearest filtering preserves original pixels.
	var extent := region.size * factor
	draw_texture_rect_region(texture, Rect2(feet - Vector2(extent.x * 0.5, extent.y), extent), region)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 2560, 768), Color("080e17"))
	# Continuous walls establish a habitable interior instead of isolated props.
	var zones := [Rect2(0, 278, 320, 365), Rect2(320, 278, 880, 365),
		Rect2(1200, 278, 720, 365), Rect2(1920, 278, 640, 365)]
	var tones := [Color("63574b"), Color("8b7560"), Color("526a73"), Color("48575c")]
	for index in zones.size():
		_tile(Rect2(107, 0, 50, 61), zones[index], tones[index])
		# Dark dado separates back wall from objects and traversable floor.
		draw_rect(Rect2(zones[index].position.x, 563, zones[index].size.x, 80), Color(0.015, 0.025, 0.035, 0.42))
	_tile(Rect2(0, 0, 51, 61), Rect2(0, FLOOR_Y, 2560, 125), Color("a3a0a0"))
	_tile(Rect2(218, 0, 69, 24), Rect2(0, 262, 2560, 24), Color("93909b"))
	# Back-wall columns/cables do not represent blocking partitions.
	for x in [20, 320, 1200, 1920, 2532]:
		_tile(Rect2(258, 69, 12, 70), Rect2(x, 282, 12, 361), Color("817b80"))
	for x in range(40, 2500, 240):
		draw_polyline(PackedVector2Array([Vector2(x, 294), Vector2(x + 80, 316), Vector2(x + 160, 312), Vector2(x + 240, 294)]), Color("171c23"), 4)
	for x in [180, 640, 1040, 1540, 2220]:
		draw_line(Vector2(x, 278), Vector2(x, 344), Color("242b30"), 4)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 8, 345), Vector2(x + 8, 345), Vector2(x + 108, 630), Vector2(x - 108, 630)]), Color(1, 0.62, 0.22, 0.045))
		draw_rect(Rect2(x - 14, 340, 28, 5), Color("ffbe68"))
	# Entrance, domestic clusters, operations anchors, workshop, storage.
	_prop(STRUCTURE, Rect2(0, 69, 45, 70), Vector2(150, FLOOR_Y))
	_prop(DOMESTIC, Rect2(0, 0, 75, 58), Vector2(430, FLOOR_Y))
	_prop(DOMESTIC, Rect2(80, 0, 54, 58), Vector2(630, FLOOR_Y))
	_prop(DOMESTIC, Rect2(140, 0, 55, 58), Vector2(780, FLOOR_Y))
	_prop(DOMESTIC, Rect2(233, 0, 39, 58), Vector2(866, FLOOR_Y))
	_prop(DOMESTIC, Rect2(258, 74, 61, 72), Vector2(700, 492))
	_prop(DOMESTIC, Rect2(199, 74, 57, 72), Vector2(532, FLOOR_Y))
	# These align exactly with the preserved functional terminal/portal positions.
	_prop(DOMESTIC, Rect2(60, 74, 58, 72), Vector2(960, FLOOR_Y))
	_prop(STRUCTURE, Rect2(158, 69, 46, 70), Vector2(1120, FLOOR_Y))
	draw_rect(Rect2(1070, 489, 100, 4), Color("39dff2"))
	# Upper 40px contain the bench artwork; the labels in the atlas below are not drawn.
	_prop(WORKSHOP, Rect2(0, 0, 132, 40), Vector2(1450, FLOOR_Y), 2.0)
	_prop(WORKSHOP, Rect2(140, 0, 76, 40), Vector2(1710, FLOOR_Y), 2.0)
	_prop(DOMESTIC, Rect2(258, 74, 61, 72), Vector2(1570, 492))
	_prop(DOMESTIC, Rect2(120, 74, 78, 72), Vector2(1800, FLOOR_Y))
	_prop(DOMESTIC, Rect2(0, 74, 58, 72), Vector2(2050, FLOOR_Y))
	_prop(DOMESTIC, Rect2(0, 74, 58, 72), Vector2(2200, FLOOR_Y))
	_prop(STRUCTURE, Rect2(390, 69, 20, 70), Vector2(2350, FLOOR_Y), 3.0)
	_prop(DOMESTIC, Rect2(258, 74, 61, 72), Vector2(2160, 490))
	_prop(STRUCTURE, Rect2(0, 69, 45, 70), Vector2(2460, FLOOR_Y))
