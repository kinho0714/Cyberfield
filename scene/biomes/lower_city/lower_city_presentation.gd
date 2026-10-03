extends Node2D
## Static presentation only: native atlas pixels, no physics, RNG consumption or frame loop.
const STRUCTURE = preload("res://assets/environment/cidade_baixa/structural/structural/cidade_baixa_structural_tileset_v1.png")
const PROPS = preload("res://assets/environment/cidade_baixa/props/cidade_baixa_props_v1.png")
const INTERACTIVES = preload("res://assets/environment/cidade_baixa/gameplay/cidade_baixa_gameplay_interactives_v1.png")
const FAR = preload("res://assets/environment/cidade_baixa/backgrounds/cidade_baixa_background_far_v1.png")
const MID = preload("res://assets/environment/cidade_baixa/backgrounds/cidade_baixa_background_mid_v1.png")
const NEAR = preload("res://assets/environment/cidade_baixa/backgrounds/cidade_baixa_background_near_v1.png")
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

var surface := Rect2()
var kind := "floor"
var variant := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -2


func _draw() -> void:
	if kind == "module":
		# Finite non-repeatable strips, never stretched into fullscreen scenery.
		draw_texture(FAR, Vector2(170, 70), Color(0.7, 0.7, 0.7))
		draw_texture(MID, Vector2(170, 123), Color(0.7, 0.7, 0.7))
		draw_texture(NEAR, Vector2(170, 177), Color(0.7, 0.7, 0.7))
		var ids := ["crate_wood_01", "crate_wood_02", "crate_wood_03", "container_green_01"]
		for index in 2:
			var region: Rect2 = REGIONS[ids[(variant + index) % ids.size()]]
			var origin := Vector2(90 + index * 640, 420 - region.size.y)
			draw_texture_rect_region(PROPS, Rect2(origin, region.size), region)
		return
	if kind == "exit":
		var region: Rect2 = REGIONS["biome_exit_01"]
		draw_texture_rect_region(INTERACTIVES,
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
			draw_texture_rect_region(STRUCTURE, Rect2(Vector2(x, y), extent),
				Rect2(region.position, extent))
			x += region.size.x
		y += region.size.y
