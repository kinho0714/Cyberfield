extends Node
## Opt-in bounded local telemetry. No player IDs, save contents, network data or uploads.
signal capture_completed(path: String)
@export_range(1.0, 300.0, 1.0) var duration_seconds := 60.0
var output_path := ""
var _started := 0
var _frames: Array[float] = []
var _samples: Array[Dictionary] = []
var _sample_elapsed := 0.0
const MAX_FRAMES := 36000

func _ready() -> void:
	_started = Time.get_ticks_usec()
	output_path = "user://performance/capture_%d_%s.json" % [int(Time.get_unix_time_from_system()), Crypto.new().generate_random_bytes(4).hex_encode()]

func _process(delta: float) -> void:
	_frames.append(delta * 1000.0)
	_sample_elapsed += delta
	if _sample_elapsed >= 1.0:
		_sample_elapsed = 0.0
		_samples.append({"elapsed_seconds": (Time.get_ticks_usec() - _started) / 1000000.0,
			"process_seconds": Performance.get_monitor(Performance.TIME_PROCESS),
			"physics_seconds": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
			"nodes": get_tree().get_node_count(), "enemies": get_tree().get_nodes_in_group("enemy").size(),
			"static_memory_bytes": OS.get_static_memory_usage(),
			"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	if (Time.get_ticks_usec() - _started) / 1000000.0 >= duration_seconds or _frames.size() >= MAX_FRAMES:
		finish()

func finish() -> void:
	set_process(false)
	_frames.sort()
	var report := {"schema": 1, "headless": DisplayServer.get_name() == "headless", "frames": _frames.size(),
		"frame_delta_ms_p50": _percentile(0.5), "frame_delta_ms_p95": _percentile(0.95), "frame_delta_ms_p99": _percentile(0.99),
		"elapsed_seconds": (Time.get_ticks_usec() - _started) / 1000000.0, "samples": _samples,
		"note": "Frame delta includes cap/waits. Process monitor is not a per-script profiler. Headless has no rendered FPS/GPU measurement."}
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report))
		file.close()
		print("CYBERFIELD_PERFORMANCE ", JSON.stringify({"headless": report.headless, "frames": report.frames, "frame_delta_ms_p50": report.frame_delta_ms_p50, "frame_delta_ms_p95": report.frame_delta_ms_p95, "frame_delta_ms_p99": report.frame_delta_ms_p99, "local_file": output_path}))
		capture_completed.emit(output_path)
	else:
		push_warning("Não foi possível gravar a captura de desempenho local.")
	queue_free()

func _percentile(ratio: float) -> float:
	return _frames[clampi(ceili((_frames.size() - 1) * ratio), 0, _frames.size() - 1)] if not _frames.is_empty() else 0.0
