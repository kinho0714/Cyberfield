extends SceneTree
## 30/10: the Lower City night theme is applied to the real generated biome.
## Run separately with Godot --headless --path . --script res://tests/lower_city_visual_theme_smoke_test.gd

const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const LOWER_CITY := preload("res://scene/biomes/lower_city/lower_city_biome.tscn")
const INDUSTRIAL := preload("res://scene/biomes/industrial/industrial_biome.tscn")
const THEME := preload("res://scene/biomes/lower_city/lower_city_visual_theme.gd")
const SEED := 20261030


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.configure_run(&"solo", &"normal")
	manager.prepare_new_run(SEED)
	var biome := LOWER_CITY.instantiate() as BiomeGenerator
	assert(biome.generate(SEED, manager))
	var report := biome.get_generation_report()
	root.add_child(biome)
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	camera.global_position = biome.get_start_position()
	await process_frame
	await process_frame

	var theme := biome.get_node_or_null("LowerCityVisual")
	assert(theme != null and theme.get_script() == THEME, "theme not applied to the gameplay biome")
	var backdrop := theme.get_node_or_null("LowerCityBackdrop") as CanvasLayer
	assert(backdrop != null and backdrop.layer < 0, "backdrop must stay behind the world")
	var textured := 0
	for body in biome.find_children("*", "StaticBody2D", true, false):
		if body.get_meta("collision_role", &"") in [&"solid_structure", &"one_way_platform"]:
			for child in body.get_children():
				if child is Polygon2D and child.visible and child.color.a > 0.0:
					assert(child.texture != null, "playable surface left untextured")
					assert(child.uv.size() == child.polygon.size())
					textured += 1
	assert(textured > 0)
	var hazed := 0
	for module in biome.get_node("Modules").get_children():
		for child in module.get_children():
			if child is Polygon2D and child.z_index == -10:
				assert(child.color.a < 0.5, "opaque module background hides the backdrop")
				hazed += 1
	assert(hazed > 0)

	# Presentation only: the theme never feeds layout, content or the signature.
	var again := LOWER_CITY.instantiate() as BiomeGenerator
	assert(again.generate(SEED, manager))
	assert(again.get_generation_report().signature == report.signature)
	assert(again.get_generation_report().enemy_count == report.enemy_count)
	again.free()
	var industrial := INDUSTRIAL.instantiate() as BiomeGenerator
	assert(industrial.generate(SEED, manager))
	assert(industrial.get_node_or_null("LowerCityVisual") == null, "theme leaked into another biome")
	industrial.free()

	biome.queue_free()
	camera.queue_free()
	await process_frame
	manager.free()
	print("LOWER_CITY_VISUAL_THEME_SMOKE_TEST_OK")
	quit(0)
