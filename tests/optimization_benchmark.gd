extends SceneTree
## CPU microbenchmarks, not rendered FPS. Always use an isolated project/userdata.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var started := Time.get_ticks_usec()
	var game: Node = load("res://scene/main.tscn").instantiate()
	var scope := "user://benchmark_" + Crypto.new().generate_random_bytes(12).hex_encode()
	game.get_node("MetaProgression").save_path = scope.path_join("legacy.json")
	game.get_node("LocalSettings").settings_path = scope.path_join("settings.cfg")
	root.add_child(game)
	await process_frame
	game.campaigns.store.root_path = scope.path_join("campaigns")
	var startup_us := Time.get_ticks_usec() - started
	if not await game.campaigns.start_new("Disposable benchmark"):
		quit(1)
		return
	started = Time.get_ticks_usec()
	await game._begin_run_from_hub(1947)
	var transition_us := Time.get_ticks_usec() - started
	await process_frame
	var samples: Array[int] = []
	for batch in 7:
		started = Time.get_ticks_usec()
		for index in 100:
			game.campaigns.geography.sample()
		samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	var hud: Node = game.get_node("RunDebugHUD")
	started = Time.get_ticks_usec()
	for index in 500:
		hud._process(0.0)
	var hud_us := Time.get_ticks_usec() - started
	var frame_times: Array[float] = []
	var physics_times: Array[float] = []
	for index in 120:
		await physics_frame
		frame_times.append(Performance.get_monitor(Performance.TIME_PROCESS))
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	frame_times.sort()
	physics_times.sort()
	# Measure save transactions at an explicit idle boundary, not active coroutines.
	for enemy in get_nodes_in_group("enemy"):
		if enemy.has_method("cancel_attack"):
			enemy.cancel_attack()
	var remote_input_times: Array[int] = []
	for batch in 3:
		started = Time.get_ticks_usec()
		for index in 100:
			game.lan_session._apply_remote_input(&"player_2", {})
		remote_input_times.append(Time.get_ticks_usec() - started)
	remote_input_times.sort()
	var capture_times: Array[int] = []
	var save_times: Array[int] = []
	for index in 3:
		started = Time.get_ticks_usec()
		var snapshot: Dictionary = preload("res://scene/persistence/session_snapshot.gd").capture(game)
		capture_times.append(Time.get_ticks_usec() - started)
		if snapshot.is_empty():
			quit(1)
			return
		started = Time.get_ticks_usec()
		if not game.campaigns.save_now():
			quit(1)
			return
		save_times.append(Time.get_ticks_usec() - started)
	capture_times.sort()
	save_times.sort()
	print("OPTIMIZATION_BENCHMARK ", JSON.stringify({"remote_input_100_median_us": remote_input_times[1], "snapshot_capture_median_us": capture_times[1], "save_transaction_median_us": save_times[1], "startup_us": startup_us, "transition_us": transition_us, "world_sample_100_median_us": samples[3], "hud_500_us": hud_us, "headless_process_p50_seconds": frame_times[60], "headless_process_p95_seconds": frame_times[114], "headless_physics_p95_seconds": physics_times[114], "nodes": get_node_count(), "enemies": get_nodes_in_group("enemy").size(), "static_memory_bytes": OS.get_static_memory_usage(), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "physics_seconds": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS), "script_frame_seconds": Performance.get_monitor(Performance.TIME_PROCESS)}))
	await game.return_to_main_menu()
	game.free()
	await process_frame
	quit()
