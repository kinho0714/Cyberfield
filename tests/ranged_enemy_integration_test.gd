extends SceneTree

const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const ROOM_CASES := {
	&"initial": {"path": "res://scene/levels/cyberfield_area_01.tscn", "totals": [1, 2, 3, 6], "ranged": [0, 0, 0, 0]},
	&"combat_01": {"path": "res://scene/levels/cyberfield_area_02.tscn", "totals": [1, 2, 3, 8], "ranged": [1, 1, 2, 2]},
	&"combat_02": {"path": "res://scene/levels/cyberfield_combat_02.tscn", "totals": [2, 3, 4, 7], "ranged": [1, 1, 2, 3]},
	&"boss_01": {"path": "res://scene/levels/cyberfield_boss_01.tscn", "totals": [1, 2, 3, 4], "ranged": [0, 1, 1, 2]},
}
const DIFFICULTIES := [&"normal", &"hard", &"pro", &"inferno_pro"]
const EXPECTED_HP := [7, 10, 15, 20]

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_scene_contracts()
	_test_target_selection()
	await _test_hybrid_combat_contracts()
	for room_id in ROOM_CASES:
		for difficulty_index in DIFFICULTIES.size():
			_test_room_case(room_id, difficulty_index)
	await _test_projectile_dash_interaction()
	if failures.is_empty():
		print("PASS: ranged enemy integration checks")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_scene_contracts() -> void:
	var ranged := (load("res://entities/RangedEnemy.tscn") as PackedScene).instantiate()
	_check(ranged.has_method("take_damage"), "RangedEnemy must accept the existing Player damage flow")
	_check(ranged.has_method("configure_health"), "RangedEnemy must accept difficulty health")
	_check(ranged.is_in_group("enemy"), "RangedEnemy must participate in enemy counts and melee hits")
	_check(is_equal_approx(ranged.aim_windup, 0.50), "RangedEnemy wind-up must default to 0.50 s")
	_check(is_equal_approx(ranged.aim_lock_before_shot, 0.12), "RangedEnemy aim lock must default to 0.12 s")
	_check(ranged.projectile_damage == 2, "RangedEnemy projectile damage must default to 2")
	_check(is_equal_approx(ranged.melee_distance, 72.0), "Melee choice must extend to 72 px")
	_check(is_equal_approx(ranged.ranged_distance, 88.0), "Ranged choice must begin above 88 px")
	_check(is_equal_approx(ranged.melee_windup, 0.12), "Melee wind-up must default to 0.12 s")
	_check(is_equal_approx(ranged.melee_recovery, 0.15), "Melee recovery must default to 0.15 s")
	_check(is_equal_approx(ranged.melee_cooldown, 0.20), "Melee cooldown must default to 0.20 s")
	_check(is_equal_approx(ranged.melee_horizontal_range, 42.0), "Melee horizontal range must default to 42 px")
	_check(not "retreat_active" in ranged, "Combat retreat state must be removed")
	_check(ranged.get_node("MeleeShapeCast").enabled == false, "Melee ShapeCast must be disabled outside impact")
	ranged.free()
	var projectile := (load("res://entities/ranged_projectile.tscn") as PackedScene).instantiate()
	_check(is_equal_approx(projectile.speed, 420.0), "Projectile speed must default to 420 px/s")
	_check(projectile.damage == 2, "Projectile damage must default to 2")
	_check(projectile.maximum_lifetime > 0.0, "Projectile must have a finite lifetime")
	projectile.free()


func _test_hybrid_combat_contracts() -> void:
	var ranged := (load("res://entities/RangedEnemy.tscn") as PackedScene).instantiate()
	ranged.persistent_id = &"hybrid_test"
	root.add_child(ranged)
	ranged.global_position = Vector2(100, 100)
	var player := (load("res://entities/player.tscn") as PackedScene).instantiate()
	player.participant_id = &"hybrid_test_player"
	root.add_child(player)
	player.global_position = Vector2(130, 100)
	await physics_frame
	ranged.set_physics_process(false)
	player.set_physics_process(false)
	ranged.player = player
	var initial_health: int = player.health
	ranged._update_movement_and_attack(1.0 / 60.0)
	_check(ranged.state == ranged.State.MELEE_WINDUP, "Close Player must start MeleeWindup")
	var state_before_aim: int = ranged.state
	ranged._begin_aim()
	_check(ranged.state == state_before_aim, "Melee and ranged attacks must be mutually exclusive")
	ranged._update_melee_windup(ranged.melee_windup)
	_check(ranged.state == ranged.State.MELEE_IMPACT, "MeleeWindup must advance to MeleeImpact")
	ranged._apply_melee_impact()
	_check(player.health == initial_health - ranged.melee_damage, "MeleeImpact must deal exactly one configured damage")
	_check(ranged.state == ranged.State.MELEE_RECOVERY, "MeleeImpact must advance to MeleeRecovery")
	_check(not ranged.melee_shape_cast.enabled, "Melee ShapeCast must disable immediately after impact")
	var health_after_impact: int = player.health
	for frame in 3:
		await physics_frame
	_check(player.health == health_after_impact, "Melee attack must not deal continuous frame damage")
	ranged._update_melee_recovery(ranged.melee_recovery)
	ranged.melee_cooldown_timer = 0.0
	player.dash_invulnerability_timer = 1.0
	ranged._begin_melee()
	ranged._update_melee_windup(ranged.melee_windup)
	ranged._apply_melee_impact()
	_check(player.health == health_after_impact, "Dash invulnerability must also reject melee damage")
	ranged._update_melee_recovery(ranged.melee_recovery)
	ranged.melee_cooldown_timer = 0.0
	ranged._begin_melee()
	ranged.take_damage(1, 1.0)
	_check(ranged.state == ranged.State.HURT and not ranged.melee_shape_cast.enabled, "Hurt must cancel melee wind-up and disable its ShapeCast")
	var health_before_cancelled_impact: int = player.health
	ranged._apply_melee_impact()
	_check(player.health == health_before_cancelled_impact, "Cancelled melee must not produce delayed damage")
	ranged.free()
	player.free()
	await _test_five_melee_cycles()


func _test_five_melee_cycles() -> void:
	var ranged := (load("res://entities/RangedEnemy.tscn") as PackedScene).instantiate()
	ranged.persistent_id = &"cycle_test"
	root.add_child(ranged)
	ranged.global_position = Vector2(100, 100)
	var player := (load("res://entities/player.tscn") as PackedScene).instantiate()
	player.participant_id = &"cycle_test_player"
	root.add_child(player)
	player.global_position = Vector2(130, 100)
	await physics_frame
	ranged.set_physics_process(false)
	player.set_physics_process(false)
	ranged.player = player
	var delta := 1.0 / 60.0
	var elapsed := 0.0
	var attack_starts: Array[float] = []
	while attack_starts.size() < 5 and elapsed < 4.0:
		var previous_state: int = ranged.state
		ranged.melee_cooldown_timer = maxf(ranged.melee_cooldown_timer - delta, 0.0)
		match ranged.state:
			ranged.State.MELEE_WINDUP:
				ranged._update_melee_windup(delta)
			ranged.State.MELEE_IMPACT:
				ranged._apply_melee_impact()
			ranged.State.MELEE_RECOVERY:
				ranged._update_melee_recovery(delta)
			_:
				ranged._update_movement_and_attack(delta)
		if previous_state != ranged.State.MELEE_WINDUP and ranged.state == ranged.State.MELEE_WINDUP:
			attack_starts.append(elapsed)
		elapsed += delta
		await physics_frame
	_check(attack_starts.size() == 5, "A nearby Player must trigger at least five consecutive melee attacks")
	if attack_starts.size() == 5:
		for index in range(1, attack_starts.size()):
			var interval := attack_starts[index] - attack_starts[index - 1]
			_check(interval >= 0.45 and interval <= 0.55, "Melee start interval %.3f s must remain between 0.45 and 0.55 s" % interval)
		print("MELEE_INTERVALS: ", [attack_starts[1] - attack_starts[0], attack_starts[2] - attack_starts[1], attack_starts[3] - attack_starts[2], attack_starts[4] - attack_starts[3]])
	_check(is_zero_approx(ranged.velocity.x), "RangedEnemy must never retreat while it has a close target")
	ranged.state = ranged.State.IDLE
	ranged.is_attacking = false
	ranged.melee_cooldown_timer = 0.0
	player.global_position = Vector2(200, 100)
	await physics_frame
	ranged._update_movement_and_attack(delta)
	_check(ranged.combat_choice == &"ranged", "A Player above 88 px must select ranged combat")
	_check(ranged.state == ranged.State.AIM, "A distant visible Player must start aiming")
	player.global_position = Vector2(150, 100)
	ranged._update_aim(delta)
	_check(ranged.state == ranged.State.MELEE_WINDUP, "Entering 72 px during aim must cancel the shot and start melee immediately")
	ranged.free()
	player.free()


func _test_target_selection() -> void:
	var ranged := (load("res://entities/RangedEnemy.tscn") as PackedScene).instantiate()
	ranged.persistent_id = &"target_test"
	root.add_child(ranged)
	ranged.global_position = Vector2.ZERO
	var p1 := (load("res://entities/player.tscn") as PackedScene).instantiate()
	p1.participant_id = &"player_1"
	root.add_child(p1)
	p1.global_position = Vector2(100, 0)
	var p2 := (load("res://entities/player.tscn") as PackedScene).instantiate()
	p2.participant_id = &"player_2"
	root.add_child(p2)
	p2.global_position = Vector2(120, 0)
	ranged._select_active_player()
	_check(ranged.player == p1, "RangedEnemy must select the nearest active Player")
	p2.global_position.x = 90.0
	ranged._select_active_player()
	_check(ranged.player == p1, "Target switch margin must prevent co-op target thrashing")
	p2.global_position.x = 70.0
	ranged._select_active_player()
	_check(ranged.player == p2, "RangedEnemy must switch when the alternative is beyond the margin")
	p2.is_downed = true
	ranged._select_active_player()
	_check(ranged.player == p1, "RangedEnemy must ignore downed Players")
	p1.visible = false
	ranged._select_active_player()
	_check(ranged.player == null, "RangedEnemy must ignore hidden Players")
	ranged.free()
	p1.free()
	p2.free()


func _test_projectile_dash_interaction() -> void:
	var player := (load("res://entities/player.tscn") as PackedScene).instantiate()
	player.participant_id = &"projectile_test_player"
	root.add_child(player)
	player.global_position = Vector2(100, 100)
	player.dash_invulnerability_timer = 1.0
	var initial_health: int = player.health
	var projectile := (load("res://entities/ranged_projectile.tscn") as PackedScene).instantiate()
	root.add_child(projectile)
	projectile.setup(Vector2(75, 100), Vector2.RIGHT, null, 420.0, 2)
	for frame in 8:
		await physics_frame
	_check(player.health == initial_health, "Dash invulnerability must reject projectile damage")
	_check(not is_instance_valid(projectile), "Projectile must be destroyed after touching an invulnerable dashing Player")
	player.free()


func _test_room_case(room_id: StringName, difficulty_index: int) -> void:
	var manager := Node.new()
	manager.set_script(RUN_MANAGER_SCRIPT)
	root.add_child(manager)
	var difficulty: StringName = DIFFICULTIES[difficulty_index]
	manager.configure_run(&"solo", difficulty)
	manager.start_new_run(123456)
	var data: Dictionary = ROOM_CASES[room_id]
	var room := (load(data.path) as PackedScene).instantiate()
	root.add_child(room)
	manager.enter_room_by_path(data.path)
	manager.prepare_room(room_id, room)
	var enemies := _find_group(room, &"enemy")
	var ranged := enemies.filter(func(enemy: Node) -> bool: return enemy.is_in_group("ranged_enemy"))
	_check(enemies.size() == data.totals[difficulty_index], "%s/%s total: expected %d, got %d" % [room_id, difficulty, data.totals[difficulty_index], enemies.size()])
	_check(ranged.size() == data.ranged[difficulty_index], "%s/%s ranged: expected %d, got %d" % [room_id, difficulty, data.ranged[difficulty_index], ranged.size()])
	var ids: Dictionary = {}
	for enemy in enemies:
		_check(not enemy.persistent_id.is_empty(), "%s/%s has an empty persistent enemy ID" % [room_id, difficulty])
		_check(not ids.has(enemy.persistent_id), "%s/%s has duplicate ID %s" % [room_id, difficulty, enemy.persistent_id])
		ids[enemy.persistent_id] = true
	for enemy in ranged:
		_check(enemy.health == EXPECTED_HP[difficulty_index], "%s/%s ranged HP: expected %d, got %d" % [room_id, difficulty, EXPECTED_HP[difficulty_index], enemy.health])
	room.free()
	manager.free()


func _find_group(node: Node, group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	if node.is_in_group(group_name):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_group(child, group_name))
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
