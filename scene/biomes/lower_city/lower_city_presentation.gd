extends Node2D
## Static presentation only: native atlas pixels, no physics, RNG consumption or frame loop.
const STRUCTURE = preload("res://assets/environment/cidade_baixa/structural/structural/cidade_baixa_structural_tileset_v1.png")
const PROPS = preload("res://assets/environment/cidade_baixa/props/cidade_baixa_props_v1.png")
const INTERACTIVES = preload("res://assets/environment/cidade_baixa/gameplay/cidade_baixa_gameplay_interactives_v1.png")
const FAR = preload("res://assets/environment/cidade_baixa/backgrounds/cidade_baixa_background_far_v1.png")
const REGIONS := {
	"floor_standard_01": Rect2(30, 19, 67, 41),
	"floor_standard_02": Rect2(159, 19, 66, 41),
	"wall_standard_01": Rect2(30, 73, 68, 45),
	"platform_thin_01": Rect2(227, 239, 122, 13),
	"crate_wood_01": Rect2(16, 16, 35, 31),
	"crate_wood_02": Rect2(67, 16, 35, 31),
	"crate_wood_03": Rect2(118, 16, 37, 31),
	"container_green_01": Rect2(171, 16, 42, 31),
	"biome_exit_01": Rect2(24, 24, 110, 97),
}

@export var content_biome_id: StringName = &"biome_01"
var _structure: Texture2D = STRUCTURE
var _props: Texture2D = PROPS
var _interactives: Texture2D = INTERACTIVES
var _far: Texture2D = FAR

var surface := Rect2()
var kind := "floor"
var variant := 0


func _ready() -> void:
	var context: Node = get_parent()
	while context != null:
		if context is BiomeGenerator and context.biome_definition != null:
			content_biome_id = ContentRegistry.biome_id(context.biome_definition.biome_id)
			break
		context = context.get_parent()
	var entry := ContentRegistry.biome(content_biome_id)
	_structure = ContentRegistry.atlas_texture(entry, "structure", STRUCTURE)
	_props = ContentRegistry.atlas_texture(entry, "props", PROPS)
	_interactives = ContentRegistry.atlas_texture(entry, "interactives", INTERACTIVES)
	_far = ContentRegistry.atlas_texture(entry, "background_far", FAR)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -8 if kind == "module" else -2


func _draw() -> void:
	if kind == "module":
		_draw_district_module()
		return
	if kind == "exit":
		var region: Rect2 = REGIONS["biome_exit_01"]
		draw_texture_rect_region(_interactives,
			Rect2(Vector2(-region.size.x * 0.5, 48 - region.size.y), region.size), region)
		return
	var id := "floor_standard_01" if variant % 2 == 0 else "floor_standard_02"
	if kind == "wall":
		id = "wall_standard_01"
	elif kind == "platform":
		id = "platform_thin_01"
	var region: Rect2 = REGIONS[id]
	# Clip final cells to the EXISTING collision rectangle; never rescale pixels,
	# bridge a traversal gap or extend the silhouette beyond a thin platform.
	var y := surface.position.y
	while y < surface.end.y:
		var x := surface.position.x
		while x < surface.end.x:
			var extent := Vector2(minf(region.size.x, surface.end.x - x),
				minf(region.size.y, surface.end.y - y))
			draw_texture_rect_region(_structure, Rect2(Vector2(x, y), extent),
				Rect2(region.position, extent))
			x += region.size.x
		y += region.size.y


func _surface_region(region: Rect2, area: Rect2, tint: Color) -> void:
	var y := area.position.y
	while y < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			var extent := Vector2(minf(region.size.x, area.end.x - x), minf(region.size.y, area.end.y - y))
			draw_texture_rect_region(_structure, Rect2(Vector2(x, y), extent), Rect2(region.position, extent), tint)
			x += region.size.x
		y += region.size.y


func _draw_district_module() -> void:
	# Back architecture is darker than solid traversal geometry; openings stay clear.
	var tone := Color(0.36, 0.44, 0.53) if variant % 2 == 0 else Color(0.43, 0.37, 0.43)
	_surface_region(Rect2(30, 73, 68, 45), Rect2(24, 40, 792, 380), tone)
	# Audit Pass 3: MID/NEAR are opaque concept strips with embedded labels.
	# _far is a finite, non-repeatable vista. Use sparingly, at native resolution.
	if variant % 3 == 0:
		draw_texture(_far, Vector2(170, 86), Color(0.42, 0.52, 0.65))
	_surface_region(Rect2(29, 132, 133, 18), Rect2(24, 26, 792, 18), Color("68757e"))
	for x in [32, 784]:
		_surface_region(Rect2(674, 256, 20, 60), Rect2(x, 46, 20, 374), Color("5b6570"))
	# Services run along the upper back wall, never over actors/telegraphs.
	_surface_region(Rect2(23, 459, 145, 41), Rect2(80, 250, 664, 24), Color("78808a"))
	var neon := Color("37aebc") if variant % 3 != 1 else Color("b4457c")
	draw_rect(Rect2(228, 244, 166, 3), neon)
	draw_polyline(PackedVector2Array([Vector2(78, 52), Vector2(150, 71), Vector2(340, 64), Vector2(510, 75), Vector2(764, 49)]), Color("0d1621"), 3)
	# Recessed base trim visually anchors the facade; it adds no collision.
	_surface_region(Rect2(159, 73, 66, 45), Rect2(24, 390, 792, 30), Color("293841"))
	# Deterministic small industrial clusters: floor ends, not central shaft/exit.
	var crates := [Rect2(16, 16, 35, 31), Rect2(67, 16, 35, 31), Rect2(171, 16, 42, 31)]
	for index in 2:
		var region: Rect2 = crates[(variant + index) % crates.size()]
		var x: float = 92 + index * 608
		draw_texture_rect_region(_props, Rect2(Vector2(x, 420 - region.size.y), region.size), region)
		var barrel := Rect2(229, 16, 29, 35)
		draw_texture_rect_region(_props, Rect2(x + 42, 385, 29, 35), barrel)
	var machine := Rect2(390, 229, 52, 49) if variant % 2 == 0 else Rect2(458, 229, 44, 44)
	draw_texture_rect_region(_props, Rect2(Vector2(56, 310), machine.size), machine, Color(0.75, 0.8, 0.9))
