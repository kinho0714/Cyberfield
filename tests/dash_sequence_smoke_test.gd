extends SceneTree
const SEQUENCE := preload("res://scene/combat/dash_sequence.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for count in [1, 2, 3]:
		var budget := SEQUENCE.new()
		for index in count:
			check(budget.try_start(), "dash %d" % index)
			check(not budget.try_start(), "same tick spam blocked")
			budget.advance(10.0)
			check(budget.used == index + 1, "no recovery during movement")
			budget.finish()
			budget.advance(0.149)
			check(not budget.try_start(), "minimum interval after end")
			budget.advance(0.001)
		check(budget.available() == 3 - count, "budget consumed")
		if count == 3:
			check(not budget.try_start(), "fourth immediate dash denied")
		budget.advance(0.599)
		check(budget.available() == 3 - count, "recovery not early")
		budget.advance(0.001)
		check(budget.available() == 3, "full recovery with one/two/three")
	for fps in [30, 60, 120]:
		var budget := SEQUENCE.new()
		budget.try_start()
		budget.finish()
		for tick in fps:
			budget.advance(1.0 / fps)
		check(budget.available() == 3, "simulation time independent of FPS")
	var player: CharacterBody2D = load("res://entities/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player._start_dash()
	check(player.dash_timer > 0.0 and player.get_dash_available() == 2, "real player entry")
	player._start_dash()
	check(player.get_dash_available() == 2, "direct entry spam denied")
	player.set_input_enabled(false)
	check(not player.dash_sequence.active and player.dash_timer == 0.0, "interruption releases active movement")
	player.set_input_enabled(true)
	player.dash_sequence.advance(0.75)
	check(player.get_dash_available() == 3, "interruption recovery")
	player.dash_used = 2
	player.dash_idle_seconds = 0.3
	var snapshot_properties: Dictionary = preload("res://scene/persistence/session_snapshot.gd").properties(player)
	check(snapshot_properties.has("dash_used") and snapshot_properties.has("dash_idle_seconds"), "budget has data-only persistence fields")
	player.dash_sequence.reset()
	preload("res://scene/persistence/session_snapshot.gd").apply_properties(player, snapshot_properties)
	check(player.get_dash_available() == 1 and is_equal_approx(player.dash_idle_seconds, 0.3), "budget restored without refilling")
	await create_timer(0.35).timeout
	player.queue_free()
	await process_frame
	print("DASH_SEQUENCE_REPORT failures=", failures)
	quit(0 if failures == 0 else 1)
