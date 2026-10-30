extends SceneTree
## Operação Renascimento — render evidence from the REAL game flow (main.tscn → hub →
## every stage → boss). Not a replacement for the physical Android test.
## Run (needs a display, e.g. xvfb-run):
##   godot --path . --script res://tests/renascimento_capture.gd -- <out_dir> [width height]
## Writes <out_dir>/<label>.png and prints one "RENASCIMENTO_REPORT" line per capture
## describing which visual systems are actually present in the loaded room.

var game: Node
var out_dir := "user://renascimento_captures"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var size := Vector2i(1280, 720)
	if args.size() > 2:
		size = Vector2i(int(args[1]), int(args[2]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = size
	game = load("res://scene/main.tscn").instantiate()
	game.get_node("LocalSettings").settings_path = out_dir.path_join("settings.cfg")
	game.get_node("MetaProgression").save_path = out_dir.path_join("meta.json")
	root.add_child(game)
	await _capture("menu")
	game.get_node("ModeSelect").play_button.pressed.emit()
	await _capture("ui_mode_select")
	game.get_node("ModeSelect").show_main_page()
	await game.start_configured_run(&"solo", &"normal", -1)
	await _capture("hub_stage0")
	await _ui_captures()
	await _pan_capture("hub_stage0")
	var meta: Node = game.get_node("MetaProgression")
	for stage in [1, 2, 3]:
		meta.house_stage = stage
		game._load_laboratory_hub()
		await _capture("hub_stage%d" % stage)
	meta.house_stage = 0
	game._load_laboratory_hub()
	await game._begin_run_from_hub(56243)
	await _capture("stage0_lower_city")
	await _pan_capture("stage0_lower_city")
	await _deep_capture("stage0_lower_city")
	await _combat_capture()
	var run_manager: Node = game.get_node("RunManager")
	for stage in [1, 2, 5]:
		run_manager.stage_index = stage
		game._load_current_stage(56243 + stage)
		await _capture("stage%d" % stage)
		await _pan_capture("stage%d" % stage)
		await _deep_capture("stage%d" % stage)
	game.queue_free()
	await process_frame
	print("RENASCIMENTO_CAPTURE_OK")
	quit()


func _ui_captures() -> void:
	var player: Node = game.get_players()[0]
	game.get_node("PauseMenu").open_menu()
	await _capture("ui_pause")
	game.get_node("PauseMenu").close_menu()
	game.get_node("InventoryUI").open_inventory()
	await _capture("ui_inventory")
	game.get_node("InventoryUI").close_inventory()
	game.get_node("MetaLabUI").open_terminal(player)
	await _capture("ui_meta_lab")
	game.get_node("MetaLabUI").close_terminal()
	var options: Array[StringName] = [&"health_capacity", &"strength_power", &"health_recovery"]
	game.get_node("AttributeChoiceUI").open_network_for(player, options)
	await _capture("ui_attribute_choice")
	game.get_node("AttributeChoiceUI").hide()
	await _capture("ui_closed")


func _combat_capture() -> void:
	# Hit, kill and dash next to the camera: CombatFx must put nodes on screen.
	var player: Node2D = game.get_players()[0]
	var enemy: Node2D = null
	for candidate in game.current_room.find_children("*", "CharacterBody2D", true, false):
		if candidate.is_in_group("enemy") and candidate.has_method("take_damage"):
			enemy = candidate
			break
	if enemy == null:
		print("RENASCIMENTO_REPORT combat {\"enemy\": null}")
		return
	enemy.global_position = player.global_position + Vector2(90.0, 0.0)
	game.gameplay_camera.global_position = player.global_position
	game.gameplay_camera.reset_smoothing()
	for i in 20:
		await process_frame
	print("RENASCIMENTO_REPORT combat_state profile=%s hurt=%s dead=%s on_screen=%s" % [VisualQuality.profile(),
		enemy.get("is_hurt"), enemy.get("is_dead"), CombatFx._on_screen(enemy)])
	var cam: Camera2D = enemy.get_viewport().get_camera_2d()
	print("RENASCIMENTO_REPORT combat_pos enemy=%s player=%s cam=%s center=%s vp=%s inside=%s" % [enemy.global_position, player.global_position,
		cam, cam.get_screen_center_position() if cam else Vector2.ZERO, enemy.get_viewport_rect(), enemy.is_inside_tree()])
	var before: int = _fx_count()
	enemy.take_damage(1, 1.0, 1.5)
	print("RENASCIMENTO_REPORT combat_hit_fx %d" % (_fx_count() - before))
	await _capture("combat_hit", 1)
	before = _fx_count()
	player._start_dash()
	await create_timer(0.1).timeout
	print("RENASCIMENTO_REPORT combat_dash_fx %d" % (_fx_count() - before))
	await _capture("combat_dash", 1)
	before = _fx_count()
	enemy.take_damage(9999, 1.0, 1.0)
	print("RENASCIMENTO_REPORT combat_death_fx %d" % (_fx_count() - before))
	await _capture("combat_death", 1)


func _deep_capture(label: String) -> void:
	# The lowest generated module: shafts and descents below street level.
	var modules: Node = game.current_room.get_node_or_null("Modules")
	if modules == null:
		return
	var deepest: Node2D = null
	for module in modules.get_children():
		if module is Node2D and (deepest == null or module.position.y > deepest.position.y):
			deepest = module
	if deepest == null or deepest.position.y <= 0.0:
		return
	var player: Node2D = game.get_players()[0]
	var start := player.global_position
	player.global_position = deepest.global_position + Vector2(640.0, 380.0)
	game.gameplay_camera.global_position = player.global_position
	game.gameplay_camera.reset_smoothing()
	await _capture(label + "_deep")
	player.global_position = start
	game.gameplay_camera.global_position = start
	game.gameplay_camera.reset_smoothing()


func _pan_capture(label: String) -> void:
	var players: Array = game.get_players()
	if players.is_empty():
		return
	var player: Node2D = players[0]
	var start := player.global_position
	player.global_position = start + Vector2(900.0, 0.0)
	game.gameplay_camera.global_position = player.global_position
	game.gameplay_camera.reset_smoothing()
	await _capture(label + "_pan")
	player.global_position = start
	game.gameplay_camera.global_position = start
	game.gameplay_camera.reset_smoothing()


func _fx_count() -> int:
	var count := 0
	for node in game.find_children("*", "", true, false):
		if node is CPUParticles2D or (node is CanvasItem and (node as CanvasItem).material is CanvasItemMaterial):
			count += 1
	return count


func _capture(label: String, frames := 6) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png(out_dir.path_join(label + ".png"))
	print("RENASCIMENTO_REPORT %s %s" % [label, JSON.stringify(_report())])


func _report() -> Dictionary:
	var room: Node = game.current_room if is_instance_valid(game.current_room) else null
	if room == null:
		return {"room": null}
	var report := {"room": String(room.name), "biome_visual": false, "backdrop": false,
		"backdrop_sprites": 0, "backdrop_null": 0, "dressing_sprites": 0, "skinned_surfaces": 0,
		"weather": 0, "temporary_parallax": room.get_node_or_null("TemporaryParallax") != null,
		"hub_presentation": false, "hub_atmosphere": room.get_node_or_null("HubAtmosphere") != null,
		"camera": str(game.gameplay_camera.global_position), "zoom": game.gameplay_camera.zoom.x}
	var visual := room.get_node_or_null("BiomeVisual")
	if visual != null:
		report.biome_visual = true
		var backdrop := visual.get_node_or_null("BiomeBackdrop")
		report.backdrop = backdrop != null
		if backdrop != null:
			for sprite in backdrop.find_children("*", "Sprite2D", true, false):
				report.backdrop_sprites += 1
				if (sprite as Sprite2D).texture == null:
					report.backdrop_null += 1
		for layer_name in ["Dressing", "DressingLight"]:
			var layer := visual.get_node_or_null(layer_name)
			if layer != null:
				report.dressing_sprites += layer.get_child_count()
		report.weather = visual.find_children("*", "CPUParticles2D", false, false).size()
	for polygon in room.find_children("*", "Polygon2D", true, false):
		if (polygon as Polygon2D).texture != null:
			report.skinned_surfaces += 1
	for child in room.get_children():
		if child.get_script() != null and String(child.get_script().resource_path).ends_with("casa_jhon_presentation.gd"):
			report.hub_presentation = true
	return report
