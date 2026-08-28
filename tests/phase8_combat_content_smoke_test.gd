extends SceneTree

const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const MAP_STATE_SCRIPT := preload("res://scene/biomes/biome_map_state.gd")
const HEAVY_SCENE := preload("res://entities/HeavyEnemy.tscn")
const BOSS_SCENE := preload("res://scene/biomes/boss_stage.tscn")
const PLAYER_SCENE := preload("res://entities/player.tscn")
const TRAP_CHEST_SCENE := preload("res://scene/interactables/trap_chest.tscn")

class FakeClientLan:
	extends Node
	func is_client() -> bool:
		return true

class FakeInteractor:
	extends Node2D
	var is_downed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_heavy_stats_and_resistance()
	_test_trap_state_round_trip()
	_test_trap_client_cannot_activate()
	_test_trap_authority_and_reward()
	await _test_boss_phase_and_results()
	await _test_wall_transfer_detection()
	print("PHASE8_COMBAT_CONTENT_SMOKE_TEST_OK")
	quit(0)


func _test_heavy_stats_and_resistance() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.configure_run(&"solo", &"pro")
	manager.prepare_new_run(800801)
	manager.activate_run()
	var heavy := HEAVY_SCENE.instantiate()
	root.add_child(heavy)
	manager.call("_configure_enemy_stats", heavy)
	assert(heavy.is_heavy() and not heavy.is_boss())
	assert(heavy.max_health == CombatStats.scaled_health(CombatStats.HEAVY_ENEMY_BASE_HP, &"pro"))
	assert(heavy.attack_damage == CombatStats.scaled_damage(CombatStats.HEAVY_ENEMY_BASE_DAMAGE, &"pro"))
	assert(heavy.attack_windup >= 0.5 and heavy.attack_recovery >= 0.45)
	assert(is_equal_approx(heavy.knockback_resistance, CombatStats.HEAVY_KNOCKBACK_RESISTANCE))
	heavy.take_damage(1, 1.0)
	var expected_velocity: float = float(heavy.KNOCKBACK_FORCE) * (1.0 - CombatStats.HEAVY_KNOCKBACK_RESISTANCE)
	assert(is_equal_approx(heavy.velocity.x, expected_velocity))
	await create_timer(0.11).timeout
	heavy.persistent_id = &"phase8_heavy_test"
	heavy.run_room_id = &"initial"
	heavy.take_damage(heavy.health)
	await create_timer(0.12).timeout
	await process_frame
	assert(not is_instance_valid(heavy))
	manager.free()


func _test_trap_state_round_trip() -> void:
	var event_id := &"stage_03_loot_02"
	var enemies: Array[StringName] = [&"stage_03_loot_02_event_01", &"stage_03_loot_02_event_02"]
	var state := MAP_STATE_SCRIPT.new(&"stage_03") as BiomeMapState
	assert(state.register_trap_event(event_id, enemies))
	assert(not state.register_trap_event(event_id, enemies))
	assert(state.get_trap_event_state(event_id) == BiomeMapState.TRAP_UNOPENED)
	assert(not state.transition_trap_event(event_id, BiomeMapState.TRAP_CLEARED))
	assert(state.transition_trap_event(event_id, BiomeMapState.TRAP_ACTIVE))
	var serialized := state.to_dictionary()
	var restored := MAP_STATE_SCRIPT.new() as BiomeMapState
	restored.apply_dictionary(serialized)
	assert(restored.stage_id == &"stage_03")
	assert(restored.get_trap_event_state(event_id) == BiomeMapState.TRAP_ACTIVE)
	assert(restored.get_trap_event_enemy_ids(event_id) == enemies)
	assert(restored.transition_trap_event(event_id, BiomeMapState.TRAP_CLEARED))
	assert(restored.transition_trap_event(event_id, BiomeMapState.TRAP_REWARDED))
	assert(not restored.transition_trap_event(event_id, BiomeMapState.TRAP_REWARDED))


func _test_trap_authority_and_reward() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.configure_run(&"lan", &"pro")
	manager.prepare_new_run(812345)
	manager.enter_generated_biome({"biome_id": &"lower_city", "display_name": "CIDADE BAIXA", "module_count": 20})
	manager.activate_run()
	var event_id := &"lower_city_loot_03"
	var enemies: Array[StringName] = [&"lower_city_loot_03_event_01", &"lower_city_loot_03_event_02"]
	assert(manager.activate_trap_event(event_id, enemies))
	assert(not manager.activate_trap_event(event_id, enemies))
	assert(manager.trap_events_activated == 1)
	manager.room_states[&"lower_city"].required_enemies[enemies[0]] = true
	manager.room_states[&"lower_city"].required_enemies[enemies[1]] = true
	manager.register_enemy_death(&"lower_city", enemies[0])
	assert(manager.get_current_map_state().get_trap_event_state(event_id) == BiomeMapState.TRAP_ACTIVE)
	manager.register_enemy_death(&"lower_city", enemies[1])
	assert(manager.get_current_map_state().get_trap_event_state(event_id) == BiomeMapState.TRAP_CLEARED)
	assert(manager.trap_events_cleared == 1)
	var before_money: int = manager.dirty_money
	var reward: int = manager.claim_trap_event_reward(event_id)
	assert(reward > 0 and manager.dirty_money == before_money + reward)
	assert(manager.claim_trap_event_reward(event_id) == 0)
	assert(manager.dirty_money == before_money + reward and manager.trap_events_rewarded == 1)
	manager.free()


func _test_trap_client_cannot_activate() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	manager.add_to_group("run_manager")
	root.add_child(manager)
	manager.configure_run(&"lan", &"normal")
	manager.prepare_new_run(823456)
	manager.enter_generated_biome({"biome_id": &"lower_city", "display_name": "CIDADE BAIXA", "module_count": 20})
	manager.activate_run()
	var fake_client := FakeClientLan.new()
	fake_client.add_to_group("lan_session")
	root.add_child(fake_client)
	var chest := TRAP_CHEST_SCENE.instantiate() as TrapChest
	chest.trap_id = &"lower_city_loot_authority"
	chest.event_spawn_positions = [Vector2(140.0, 100.0), Vector2(260.0, 100.0), Vector2(380.0, 100.0)]
	root.add_child(chest)
	assert(manager.get_current_map_state().get_trap_event_enemy_ids(chest.trap_id).size() == 2)
	var interactor := FakeInteractor.new()
	root.add_child(interactor)
	interactor.global_position = chest.global_position
	chest.interact(interactor)
	assert(manager.get_current_map_state().get_trap_event_state(chest.trap_id) == BiomeMapState.TRAP_UNOPENED)
	fake_client.free()
	chest.interact(interactor)
	assert(manager.get_current_map_state().get_trap_event_state(chest.trap_id) == BiomeMapState.TRAP_ACTIVE)
	for enemy_value: Variant in get_nodes_in_group(&"enemy"):
		var enemy := enemy_value as Node
		if String(enemy.get("persistent_id")).begins_with("lower_city_loot_authority_event_"):
			enemy.free()
	interactor.free()
	chest.free()
	manager.free()


func _test_boss_phase_and_results() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.configure_run(&"solo", &"normal")
	manager.prepare_new_run(899991)
	manager.activate_run()
	manager.stage_index = 5
	manager.enter_boss_stage()
	var boss_stage := BOSS_SCENE.instantiate()
	root.add_child(boss_stage)
	boss_stage.setup(manager)
	manager.prepare_boss_stage(boss_stage)
	var boss := boss_stage.get_node("Entities/PrototypeBoss")
	var initial_speed: float = boss.move_speed
	var initial_cooldown: float = boss.attack_cooldown
	boss.take_damage((int(boss.max_health) + 1) / 2)
	assert(boss.boss_phase_two_active)
	assert(boss.move_speed > initial_speed and boss.attack_cooldown < initial_cooldown)
	manager.register_enemy_death(&"boss_stage_06", boss.persistent_id)
	manager.finish_run()
	assert(manager.run_is_completed and manager.boss_defeated)
	assert(bool(manager.last_run_results.get("boss_defeated", false)))
	assert(int((manager.last_run_results.get("completion_rewards", {}) as Dictionary).get("boss_money", 0)) > 0)
	assert((manager.last_run_results.get("trap_events", {}) as Dictionary).has("rewarded"))
	boss_stage.free()
	manager.free()
	await process_frame


func _test_wall_transfer_detection() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	player.global_position = Vector2(200.0, 200.0)
	var wall := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12.0, 160.0)
	collision.shape = shape
	wall.add_child(collision)
	root.add_child(wall)
	wall.global_position = Vector2(218.0, 200.0)
	await physics_frame
	assert((player.call("_nearby_wall_normal", 1.0) as Vector2).x < 0.0)
	wall.global_position = Vector2(260.0, 200.0)
	await physics_frame
	assert((player.call("_nearby_wall_normal", 1.0) as Vector2) == Vector2.ZERO)
	assert(player.WALL_TRANSFER_ASSIST_DISTANCE <= 20.0)
	assert(player.WALL_JUMP_STAMINA_COST > 0.0)
	assert(player.MAX_JUMPS == 2 and player.DASH_SPEED > player.SPEED)
	wall.free()
	player.free()
