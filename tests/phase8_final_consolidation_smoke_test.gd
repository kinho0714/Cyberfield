extends SceneTree

const MAIN_SCENE := preload("res://scene/main.tscn")
const PLAYER_SCENE := preload("res://entities/player.tscn")
const BANDAGE_SCRIPT := preload("res://scene/interactables/bandage_pickup.gd")
const TELEPORTER_SCRIPT := preload("res://scene/biomes/biome_teleporter.gd")

class FakeBiome:
	extends Node2D
	func get_map_graph() -> Dictionary:
		return {"modules": [], "teleporters": [], "content_entries": []}
	func get_module_index_at(_position: Vector2) -> int:
		return -1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_prediction_and_local_attack_feedback()
	await _test_collective_fast_travel_and_results()
	_test_bandage_visual()
	print("PHASE8_FINAL_CONSOLIDATION_SMOKE_TEST_OK")
	quit(0)


func _test_prediction_and_local_attack_feedback() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	player.network_prediction_only = true
	player.global_position = Vector2(100.0, 100.0)
	player.is_attacking = true
	player.anim.play("attack")
	player.apply_network_state({"position": Vector2(108.0, 100.0), "velocity": Vector2(220.0, 0.0), "animation": &"idle", "is_attacking": false}, true)
	assert(player.global_position == Vector2(100.0, 100.0))
	assert(player.is_attacking and player.anim.animation == &"attack")
	player.apply_network_state({"position": Vector2(140.0, 100.0), "velocity": Vector2(220.0, 0.0)}, true)
	assert(player.network_correction_velocity.x > 0.0 and player.global_position == Vector2(100.0, 100.0))
	player.is_attacking = false
	player.equipped_weapons[1] = &"arc_emitter"
	player.attack(1)
	assert(player.weapon_cooldowns[1] > 0.0 and player.anim.animation == &"attack")
	assert(get_nodes_in_group("network_projectile").is_empty())
	player.free()
	await process_frame


func _test_collective_fast_travel_and_results() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.mode_selected = true
	main.current_is_generated_biome = true
	main.run_manager.configure_run(&"lan", &"normal", -1, 4)
	main.run_manager.prepare_new_run(812812)
	main.run_manager.activate_run()
	main._create_network_players(4)
	await process_frame
	var biome := FakeBiome.new()
	main.room_container.add_child(biome)
	main.current_room = biome
	var origin := TELEPORTER_SCRIPT.new() as BiomeTeleporter
	origin.teleporter_id = &"origin"
	biome.add_child(origin)
	origin.global_position = Vector2(200.0, 300.0)
	origin.arrival_position = origin.global_position
	var destination := TELEPORTER_SCRIPT.new() as BiomeTeleporter
	destination.teleporter_id = &"destination"
	biome.add_child(destination)
	destination.global_position = Vector2(900.0, 300.0)
	destination.arrival_position = Vector2(900.0, 250.0)
	main.run_manager.activate_map_teleporter(&"origin")
	main.run_manager.activate_map_teleporter(&"destination")
	for player in main.get_players():
		player.global_position = origin.global_position
	var before := (main._find_player(&"player_1") as Node2D).global_position
	for slot in range(1, 4):
		assert(not main.submit_fast_travel_confirmation(StringName("player_%d" % slot), &"origin", &"destination"))
		assert((main._find_player(&"player_1") as Node2D).global_position == before)
	assert(main.submit_fast_travel_confirmation(&"player_4", &"origin", &"destination"))
	for player in main.get_players():
		assert(player.global_position.distance_to(destination.arrival_position) < 100.0)
	for player in main.get_players():
		player.global_position = origin.global_position
	assert(not main.submit_fast_travel_confirmation(&"player_1", &"origin", &"destination"))
	main.cancel_fast_travel_confirmation(&"player_1")
	assert(main.fast_travel_vote_origin.is_empty() and main.fast_travel_confirmations.is_empty())

	main.current_is_hub = true
	main.current_is_generated_biome = false
	main.run_manager.last_run_results = {
		"completed": true, "elapsed_time": 125.0, "difficulty": &"normal", "stage_index": 5, "money_earned": 240,
		"participants": {&"player_1": {"intellect": 1, "health": 2, "strength": 3}, &"player_2": {"intellect": 2, "health": 1, "strength": 1}},
		"weapons_found": {&"player_1": [&"scrap_blade"], &"player_2": [&"arc_emitter"]}, "boss_defeated": true,
		"trap_events": {"activated": 2, "cleared": 2, "rewarded": 1},
	}
	var results := main.get_node("RunResultUI") as RunResultUI
	results.show_latest_results()
	assert(not main._find_player(&"player_1").input_enabled and not main._find_player(&"player_2").input_enabled)
	results.close_result(&"player_2")
	assert(main._find_player(&"player_2").input_enabled and not main._find_player(&"player_1").input_enabled)
	results.close_result(&"player_3")
	results.close_result(&"player_4")
	results.close_result(&"player_1")
	assert(main._find_player(&"player_1").input_enabled)
	main.free()
	await process_frame


func _test_bandage_visual() -> void:
	var bandage := BANDAGE_SCRIPT.new() as BandagePickup
	root.add_child(bandage)
	var polygons := bandage.get_children().filter(func(child: Node) -> bool: return child is Polygon2D)
	var lines := bandage.get_children().filter(func(child: Node) -> bool: return child is Line2D)
	assert(polygons.size() >= 2 and not lines.is_empty())
	assert(bandage.has_method("claim_authoritative") and is_equal_approx(bandage.HEAL_RATIO, 0.10))
	bandage.free()
