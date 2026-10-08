extends SceneTree

const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const TEMP_PRESENTATION := preload("res://scene/biomes/lower_city/lower_city_presentation.gd")
const BIOME_SCENES := [
	"res://scene/biomes/lower_city/lower_city_biome.tscn",
	"res://scene/biomes/industrial/industrial_biome.tscn",
	"res://scene/biomes/lab/lab_biome.tscn",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.configure_run(&"solo", &"normal")
	manager.prepare_new_run(20261006)
	for path in BIOME_SCENES:
		var biome := load(path).instantiate() as BiomeGenerator
		assert(biome != null and biome.generate(20261006, manager), "Generation failed: %s" % path)
		root.add_child(biome)
		var visible_surfaces := 0
		var exits := 0
		for node in biome.find_children("*", "", true, false):
			assert(node.get_script() != TEMP_PRESENTATION, "Temporary renderer still instanced: %s" % path)
			assert(node.name != "TemporaryParallax", "Run parallax still instanced: %s" % path)
			if node is StaticBody2D and node.get_meta("collision_role", &"") in [&"solid_structure", &"one_way_platform"]:
				var has_visible_surface := false
				for child in node.get_children():
					if child is Polygon2D and child.visible:
						has_visible_surface = true
				assert(has_visible_surface, "Invisible platform/floor: %s" % path)
				visible_surfaces += 1
			if node is Area2D and node.has_method("interact") and node.has_node("Door") and node.has_node("Frame"):
				assert(node.get_node("Door").visible and node.get_node("Frame").visible, "Invisible exit: %s" % path)
				exits += 1
		assert(visible_surfaces > 0 and exits == 2, "Missing playable geometry/exits: %s" % path)
		biome.free()
	manager.free()
	print("ENVIRONMENT_CLEANUP_SMOKE_TEST_OK")
	quit(0)
