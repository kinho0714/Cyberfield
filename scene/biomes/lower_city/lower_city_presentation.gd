extends Node2D
## RECOMPOSITION: single environment language, physics remains in BiomeGenerator.
const TEMP_ENV = preload("res://scene/temporary_environment/painter.gd")
const INTERACTIVES = preload("res://assets/environment/cidade_baixa/gameplay/cidade_baixa_gameplay_interactives_v1.png")

@export var content_biome_id: StringName = &"biome_01"
var surface := Rect2()
var kind := "floor"
var variant := 0
var room_role := "traversal"
var _temporary_family := "city"
var _interactives: Texture2D = INTERACTIVES


func _ready() -> void:
	if kind == "module":
		add_to_group("temporary_environment_view")
	var context: Node = get_parent()
	while context != null:
		if context is BiomeGenerator and context.biome_definition != null:
			content_biome_id = ContentRegistry.biome_id(context.biome_definition.biome_id)
			break
		context = context.get_parent()
	var entry := ContentRegistry.biome(content_biome_id)
	_temporary_family = String(entry.get("temporary_environment_family", "city"))
	_interactives = ContentRegistry.atlas_texture(entry, "interactives", INTERACTIVES)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -8 if kind == "module" else -2


func _draw() -> void:
	if kind == "module":
		_draw_district_module()
	elif kind == "exit":
		# Retain the interactive landmark; no physics or interaction changes.
		var region := Rect2(24, 24, 110, 97)
		draw_texture_rect_region(_interactives,
			Rect2(Vector2(-55, -49), region.size), region)
	else:
		TEMP_ENV.surface(self, surface, kind)


func _draw_district_module() -> void:
	var module := get_parent() as Node2D
	var protected: Array[Rect2] = []
	var platform_shadows: Array[Rect2] = []
	# Read-only inspection at draw time: the generator has already built its children.
	for child in module.get_children():
		if child is StaticBody2D:
			for shape_node in child.get_children():
				if shape_node is CollisionShape2D and shape_node.shape is RectangleShape2D:
					var size: Vector2 = shape_node.shape.size
					var area := Rect2(child.position + shape_node.position - size * 0.5, size)
					protected.append(area.grow(10.0))
					if child.get_meta("collision_role", &"") == &"one_way_platform":
						platform_shadows.append(area.grow(6.0).intersection(Rect2(0, 0, 840, 420)))
		elif child is Marker2D:
			# Existing socket positions protect actors, loot and exits from decorative detail.
			protected.append(Rect2(child.position - Vector2(44, 96), Vector2(88, 108)))
	var id := TEMP_ENV.layout_id(_temporary_family, variant, module.position)
	TEMP_ENV.paint(self, id, room_role, protected)
	for shadow in platform_shadows:
		if shadow.has_area():
			draw_rect(shadow, Color("15232d"))
