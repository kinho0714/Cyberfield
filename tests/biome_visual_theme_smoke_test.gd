extends SceneTree
## 30/10: every gameplay biome (and the boss arena) gets its own visual theme.
## Run separately with Godot --headless --path . --script res://tests/biome_visual_theme_smoke_test.gd

const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const THEME := preload("res://scene/biomes/visual/biome_visual_theme.gd")
const BIOMES := {
	"res://scene/biomes/lower_city/lower_city_biome.tscn": &"lower_city_night",
	"res://scene/biomes/industrial/industrial_biome.tscn": &"industrial_forge",
	"res://scene/biomes/lab/lab_biome.tscn": &"lab_cryo",
}
const BOSS_STAGE := preload("res://scene/biomes/boss_stage.tscn")
const SEED := 20261030


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.configure_run(&"solo", &"normal")
	manager.prepare_new_run(SEED)
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	for path: String in BIOMES:
		var biome := (load(path) as PackedScene).instantiate() as BiomeGenerator
		assert(biome.generate(SEED, manager), "generation failed: %s" % path)
		var report := biome.get_generation_report()
		root.add_child(biome)
		camera.global_position = biome.get_start_position()
		await process_frame
		await process_frame
		var theme := biome.get_node_or_null("BiomeVisual")
		assert(theme != null and theme.get_script() == THEME, "theme missing: %s" % path)
		assert(theme.style_id == BIOMES[path], "wrong style: %s" % path)
		var backdrop := theme.get_node_or_null("BiomeBackdrop") as CanvasLayer
		assert(backdrop != null and backdrop.layer < 0, "backdrop must stay behind the world")
		var textured := 0
		for body in biome.find_children("*", "StaticBody2D", true, false):
			if body.get_meta("collision_role", &"") in [&"solid_structure", &"one_way_platform"]:
				for child in body.get_children():
					if child is Polygon2D and child.visible and child.color.a > 0.0:
						assert(child.texture != null, "untextured surface in %s" % path)
						assert(child.uv.size() == child.polygon.size())
						textured += 1
		assert(textured > 0)
		for module in biome.get_node("Modules").get_children():
			for child in module.get_children():
				if child is Polygon2D and child.z_index == -10:
					assert(child.color.a < 0.5, "opaque module background hides the backdrop")
		# Presentation only: the theme never feeds layout, content or the signature.
		var again := (load(path) as PackedScene).instantiate() as BiomeGenerator
		assert(again.generate(SEED, manager))
		assert(again.get_generation_report().signature == report.signature)
		assert(again.get_generation_report().enemy_count == report.enemy_count)
		again.free()
		biome.queue_free()
		await process_frame

	var boss := BOSS_STAGE.instantiate()
	root.add_child(boss)
	boss.setup(manager)
	await process_frame
	var boss_theme := boss.get_node_or_null("BiomeVisual")
	assert(boss_theme != null and boss_theme.style_id == &"core_reactor", "boss arena theme missing")
	assert((boss.get_node("Floor/FloorVisual") as Polygon2D).texture != null, "boss floor untextured")
	boss.queue_free()
	camera.queue_free()
	await process_frame
	manager.free()
	print("BIOME_VISUAL_THEME_SMOKE_TEST_OK")
	quit(0)
