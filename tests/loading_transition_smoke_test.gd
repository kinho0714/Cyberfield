extends SceneTree
const SNAPSHOT := preload("res://scene/persistence/session_snapshot.gd")
var failures := 0
var blocked_frames := 0
var cancel_next := false
var game: Node

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func audit_input() -> void:
	if game == null or not game.loading.active:
		return
	blocked_frames += 1
	if cancel_next:
		cancel_next = false
		game.loading.cancel()
	game._set_all_player_input(true)
	for player in game.get_players():
		check(not player.input_enabled, "no input while loading, including restored players")

func check_visual_ready() -> void:
	check(game.current_room.get_node_or_null("BiomeVisual") != null, "visual theme exists before control release")
	for body in game.current_room.find_children("*", "StaticBody2D", true, false):
		if body.get_meta("collision_role", &"") in [&"solid_structure", &"one_way_platform"]:
			for child in body.get_children():
				if child is Polygon2D and child.visible and child.color.a > 0.0:
					check(child.texture != null, "async visual surfaces fully prepared")

func run() -> void:
	game = load("res://scene/main.tscn").instantiate()
	var scope := "user://loading_test_" + Crypto.new().generate_random_bytes(12).hex_encode()
	game.get_node("MetaProgression").save_path = scope.path_join("legacy.json")
	game.get_node("LocalSettings").settings_path = scope.path_join("settings.cfg")
	root.add_child(game)
	print("LOADING_STEP await process_frame")
	await process_frame
	process_frame.connect(audit_input)
	game.campaigns.store.root_path = scope.path_join("campaigns")
	print("LOADING_STEP check(await game.campaigns.start_new(\"Disposable loading\"), \"create campaign through loading\")")
	check(await game.campaigns.start_new("Disposable loading"), "create campaign through loading")
	check(game.campaigns.geography.is_processing(), "exploration sampling active only with campaign")
	check(not game.campaigns.private_gameplay.is_physics_processing(), "solo cooperative bridge idle")
	check(not game.loading.active and not paused and game.get_players()[0].input_enabled, "release after hub ready")
	check(not game.lan_session.is_processing(), "solo LAN processing disabled")
	print("LOADING_STEP await game._begin_run_from_hub(1947)")
	await game._begin_run_from_hub(1947)
	check(game.current_is_generated_biome and not game.loading.active, "generated city ready")
	check_visual_ready()
	var sync_room: Node = load(game.LOWER_CITY_BIOME_SCENE).instantiate()
	print("LOADING_STEP check(sync_room.generate(game.run_manager.area_seed_value, game.run_manager), \"synchronous deterministic reference\")")
	check(sync_room.generate(game.run_manager.area_seed_value, game.run_manager), "synchronous deterministic reference")
	check(sync_room.get_map_graph() == game.current_room.get_map_graph(), "async construction preserves complete deterministic graph")
	sync_room.free()
	var tracker: Node = game.campaigns.geography
	var area: String = tracker.remember_current_area()
	check(not area.is_empty(), "archive before transition")
	print("LOADING_STEP await game.request_biome_advance(&\"fixture_a\", &\"next_biome\")")
	await game.request_biome_advance(&"fixture_a", &"next_biome")
	check(not game.loading.active and game.run_manager.get_stage_biome_kind() == &"industrial", "industrial region transaction finished")
	check_visual_ready()
	print("LOADING_STEP await game.request_biome_advance(&\"fixture_b\", &\"next_biome\")")
	await game.request_biome_advance(&"fixture_b", &"next_biome")
	check(not game.loading.active and game.run_manager.get_stage_biome_kind() == &"lab", "laboratory region transaction finished")
	check_visual_ready()
	print("LOADING_STEP check(await tracker.revisit_area_async(area), \"async revisit restores archive\")")
	check(await tracker.revisit_area_async(area), "async revisit restores archive")
	check(game.campaigns.save_now(), "save stable state")
	var revision: int = game.campaigns.active.revision
	var disk_before: Array[Dictionary] = game.campaigns.store.load_revisions(game.campaigns.active.campaign_id)
	game.is_transitioning = true
	game.loading.begin()
	game._set_all_player_input(false)
	check(not game.loading.begin(), "duplicate begin rejected")
	check(not game.campaigns.save_now(), "loading cannot overwrite snapshot")
	print("LOADING_STEP var missing: PackedScene = await game.loading.load_scene(\"res://missing_loading_fixture.tscn\")")
	var missing: PackedScene = await game.loading.load_scene("res://missing_loading_fixture.tscn")
	check(missing == null, "missing resource handled")
	print("LOADING_STEP await game.loading.finish(false)")
	await game.loading.finish(false)
	game.is_transitioning = false
	game._set_all_player_input(true)
	check(paused and not game.get_players()[0].input_enabled, "failure overlay keeps simulation and controls blocked")
	check(not game.campaigns.save_now(), "failure overlay cannot overwrite snapshot")
	game.loading.dismiss_error()
	check(not paused and game.get_players()[0].input_enabled, "dismiss failure restores previous controls")
	check(game.campaigns.active.revision == revision, "failed load does not create revision")
	check(disk_before == game.campaigns.store.load_revisions(game.campaigns.active.campaign_id), "failed load preserves persisted contents")
	game.loading.begin()
	await process_frame
	await process_frame
	var cancel_position: Vector2 = game.loading._close.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 91
		touch.position = root.get_final_transform() * cancel_position
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame
	check(game.loading.cancelled, "Android touch cancels without mouse emulation")
	print("LOADING_STEP check(await game.loading.load_scene(game.LABORATORY_HUB_SCENE) == null, \"cancelled transaction refuses resources\")")
	check(await game.loading.load_scene(game.LABORATORY_HUB_SCENE) == null, "cancelled transaction refuses resources")
	print("LOADING_STEP await game.loading.finish(false)")
	await game.loading.finish(false)
	var old_stage: int = game.run_manager.stage_index
	var old_room: Node = game.current_room
	cancel_next = true
	print("LOADING_STEP await game.request_biome_advance(&\"fixture_cancel\", &\"next_biome\")")
	await game.request_biome_advance(&"fixture_cancel", &"next_biome")
	check(game.run_manager.stage_index == old_stage and game.current_room == old_room, "cancelled region transition rolls back run and room")
	check(disk_before == game.campaigns.store.load_revisions(game.campaigns.active.campaign_id), "interruption preserves last valid disk snapshot")
	var id: String = game.campaigns.active.campaign_id
	print("LOADING_STEP await game.return_to_main_menu()")
	await game.return_to_main_menu()
	print("LOADING_STEP check(await game.campaigns.continue_campaign(id), \"continue restores snapshot behind overlay\")")
	check(await game.campaigns.continue_campaign(id), "continue restores snapshot behind overlay")
	check(game.get_players()[0].input_enabled and not paused, "restore releases control exactly at completion")
	print("LOADING_STEP await game.return_to_laboratory()")
	await game.return_to_laboratory()
	check(game.current_is_hub and not game.loading.active, "death return ready")
	var hub_nodes := get_node_count()
	for index in 3:
		await game._begin_run_from_hub(1947)
		await game.return_to_laboratory()
		await process_frame
		check(get_node_count() <= hub_nodes + 4, "repeated transitions do not accumulate room nodes")
	# A caller-owned pause must survive a loading transaction (modal integration).
	paused = true
	game.loading.begin()
	print("LOADING_STEP await game.loading.finish()")
	await game.loading.finish()
	check(paused, "preserve caller pause ownership")
	paused = false
	check(game.begin_performance_capture(1.0) == OK, "opt-in local performance recorder")
	check(game.begin_performance_capture() == ERR_ALREADY_IN_USE, "no duplicate recorder")
	var recorder: Node = game.get_node("PerformanceCapture")
	var report_path: String = recorder.output_path
	print("LOADING_STEP await physics_frame")
	await physics_frame
	recorder.finish()
	check(FileAccess.file_exists(report_path), "bounded telemetry persisted locally")
	var metrics: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	check(metrics is Dictionary and metrics.headless and metrics.frames > 0, "headless evidence explicitly labeled")
	check(blocked_frames > 5, "input checked during real asynchronous preparation")
	print("LOADING_STEP await game.return_to_main_menu()")
	await game.return_to_main_menu()
	process_frame.disconnect(audit_input)
	game.free()
	game = null
	print("LOADING_STEP await process_frame")
	await process_frame
	print("LOADING_TRANSITION_REPORT failures=", failures, " blocked_frames=", blocked_frames)
	quit(0 if failures == 0 else 1)
