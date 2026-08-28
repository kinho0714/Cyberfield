extends Node

signal state_changed
signal run_completed
signal run_lost

enum RunState { MENU, HUB, PREPARING, ACTIVE, COMPLETED, LOST }

const ENEMY_SCENE := preload("res://entities/Enemy.tscn")
const RANGED_ENEMY_SCENE := preload("res://entities/RangedEnemy.tscn")
const MONEY_PICKUP_SCENE := preload("res://scene/interactables/dirty_money_pickup.tscn")
const BANDAGE_PICKUP_SCRIPT := preload("res://scene/interactables/bandage_pickup.gd")
const BANDAGE_DROP_CHANCE := 0.11
const BIOME_MAP_STATE := preload("res://scene/biomes/biome_map_state.gd")
const ATTRIBUTE_IDS := [&"intellect", &"health", &"strength"]
const ATTRIBUTE_TRIPLE_CHOICE_CHANCE := 0.60
const CHALLENGE_BASIC_COUNTS := {&"normal": 2, &"hard": 3, &"pro": 4, &"inferno_pro": 5}
const RANGED_COUNTS := {
	&"combat_01": {&"normal": 1, &"hard": 1, &"pro": 2, &"inferno_pro": 2},
	&"combat_02": {&"normal": 1, &"hard": 1, &"pro": 2, &"inferno_pro": 3},
	&"boss_01": {&"normal": 0, &"hard": 1, &"pro": 1, &"inferno_pro": 2},
}
const DIFFICULTY_CONFIGS := {
	&"normal": {"label": "Normal", "extra_enemies": 0},
	&"hard": {"label": "Difícil", "extra_enemies": 1},
	&"pro": {"label": "Pro", "extra_enemies": 2},
	&"inferno_pro": {"label": "Inferno do Pro", "extra_enemies": 3},
}
const RUN_SEQUENCE := [
	{"id": &"initial", "path": "res://scene/levels/cyberfield_area_01.tscn", "type": &"Inicial", "combat": true},
	{"id": &"combat_01", "path": "res://scene/levels/cyberfield_area_02.tscn", "type": &"Combate", "combat": true},
	{"id": &"reward_01", "path": "res://scene/levels/cyberfield_reward_01.tscn", "type": &"Recompensa", "combat": false},
	{"id": &"combat_02", "path": "res://scene/levels/cyberfield_combat_02.tscn", "type": &"Combate", "combat": true},
	{"id": &"boss_01", "path": "res://scene/levels/cyberfield_boss_01.tscn", "type": &"Chefe", "combat": true},
	{"id": &"completed", "path": "res://scene/levels/cyberfield_run_complete.tscn", "type": &"Conclusão", "combat": false},
]

var run_active := false
var run_state: RunState = RunState.MENU
var run_is_completed := false
var seed_value := 0
var current_room_index := 0
var room_states: Dictionary = {}
var participants: Dictionary = {}
var participant_progress: Dictionary = {}
var run_is_lost := false
var game_mode: StringName = &"none"
var player_count := 0
var difficulty: StringName = &"normal"
var extra_enemy_count := 0
var enemy_health := CombatStats.COMMON_ENEMY_BASE_HP
var ranged_enemy_health := CombatStats.RANGED_ENEMY_BASE_HP
var boss_health := CombatStats.BOSS_BASE_HP
var enemy_melee_damage := CombatStats.COMMON_ENEMY_BASE_DAMAGE
var ranged_melee_damage := CombatStats.RANGED_MELEE_BASE_DAMAGE
var ranged_projectile_damage := CombatStats.RANGED_PROJECTILE_BASE_DAMAGE
var p2_joypad_device_id := -1
var p2_joypad_name := ""
var dirty_money := 0
var current_biome_id: StringName
var current_biome_name := ""
var generated_module_count := 0
var generation_fallback := false
var generation_failure_reason := ""
var selected_exit_id: StringName
var selected_exit_destination: StringName
var collected_biome_loot: Dictionary = {}
var stage_index := 0
var current_stage_id: StringName = &""
var stage_history: Array[Dictionary] = []
var map_states: Dictionary = {}
var run_elapsed_time := 0.0
var total_money_earned := 0
var weapons_found: Dictionary = {}
var last_run_results: Dictionary = {}


func _process(delta: float) -> void:
	if run_active:
		run_elapsed_time += delta


func configure_run(mode: StringName, selected_difficulty: StringName, joypad_device_id: int = -1) -> void:
	if not DIFFICULTY_CONFIGS.has(selected_difficulty):
		push_error("Unknown difficulty: %s" % selected_difficulty)
		selected_difficulty = &"normal"
	var config: Dictionary = DIFFICULTY_CONFIGS[selected_difficulty]
	game_mode = mode
	player_count = 2 if mode in [&"coop", &"lan"] else 1
	difficulty = selected_difficulty
	extra_enemy_count = config.extra_enemies
	_apply_difficulty_stats()
	p2_joypad_device_id = joypad_device_id if is_coop() else -1
	p2_joypad_name = Input.get_joy_name(p2_joypad_device_id) if p2_joypad_device_id >= 0 else ""
	state_changed.emit()


func set_game_mode(mode: StringName) -> void:
	configure_run(mode, difficulty, p2_joypad_device_id)


func is_coop() -> bool:
	return game_mode in [&"coop", &"lan"]


func prepare_hub() -> void:
	run_state = RunState.HUB
	run_active = false
	run_is_completed = false
	run_is_lost = false
	seed_value = 0
	current_room_index = 0
	room_states.clear()
	participants.clear()
	participant_progress.clear()
	dirty_money = 0
	stage_index = 0
	current_stage_id = &""
	stage_history.clear()
	_clear_biome_state()
	state_changed.emit()


func prepare_new_run(new_seed: int = 0) -> void:
	seed_value = new_seed if new_seed != 0 else randi()
	run_state = RunState.PREPARING
	run_active = false
	run_is_completed = false
	run_is_lost = false
	current_room_index = 0
	room_states.clear()
	participants.clear()
	participant_progress.clear()
	dirty_money = 0
	stage_index = 0
	current_stage_id = &"lower_city"
	stage_history.clear()
	_clear_biome_state()
	_reset_run_quality_state()
	for room_data in RUN_SEQUENCE:
		room_states[room_data.id] = _new_room_state()
	state_changed.emit()


func activate_run() -> void:
	if run_state != RunState.PREPARING:
		return
	run_state = RunState.ACTIVE
	run_active = true
	state_changed.emit()


func start_new_run(new_seed: int = 0) -> void:
	prepare_new_run(new_seed)
	activate_run()


func clear_run() -> void:
	run_state = RunState.MENU
	run_active = false
	run_is_completed = false
	run_is_lost = false
	seed_value = 0
	current_room_index = 0
	room_states.clear()
	participants.clear()
	participant_progress.clear()
	dirty_money = 0
	stage_index = 0
	current_stage_id = &""
	stage_history.clear()
	_clear_biome_state()
	_reset_run_quality_state()
	game_mode = &"none"
	player_count = 0
	difficulty = &"normal"
	extra_enemy_count = 0
	_apply_difficulty_stats()
	p2_joypad_device_id = -1
	p2_joypad_name = ""
	state_changed.emit()


func restart_run() -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.restart_current_run()


func enter_room_by_path(room_path: String) -> StringName:
	current_biome_id = &""
	current_biome_name = ""
	generated_module_count = 0
	for index in RUN_SEQUENCE.size():
		if RUN_SEQUENCE[index].path == room_path:
			current_room_index = index
			var room_id: StringName = RUN_SEQUENCE[index].id
			room_states[room_id].visited = true
			if room_id == &"completed":
				finish_run()
			else:
				state_changed.emit()
			return room_id
	push_error("Room is not registered in the run sequence: %s" % room_path)
	return &""


func prepare_room(room_id: StringName, room: Node) -> void:
	if room_id.is_empty() or not room_states.has(room_id):
		return
	_spawn_difficulty_enemies(room_id, room)
	_spawn_challenge_enemies(room_id, room)
	_apply_ranged_composition(room_id, room)
	var state: Dictionary = room_states[room_id]
	var seen_ids: Dictionary = {}
	for enemy in _find_nodes_in_group(room, &"enemy"):
		var enemy_id: StringName = enemy.persistent_id
		if enemy_id.is_empty():
			push_error("Enemy without persistent_id in room '%s': %s" % [room_id, enemy.name])
			continue
		if seen_ids.has(enemy_id):
			push_error("Duplicate enemy persistent_id '%s' in room '%s'" % [enemy_id, room_id])
			continue
		seen_ids[enemy_id] = true
		enemy.run_room_id = room_id
		_configure_enemy_stats(enemy)
		if enemy.required_for_completion:
			state.required_enemies[enemy_id] = true
			if enemy.is_boss():
				state.required_bosses[enemy_id] = true
		if state.dead_enemies.has(enemy_id):
			enemy.queue_free()
	_update_room_completion(room_id)
	_spawn_pending_money(room_id, room)
	state_changed.emit()


func enter_generated_biome(report: Dictionary) -> void:
	var definition_id := StringName(report.get("biome_id", &"lower_city"))
	current_biome_id = current_stage_id if not current_stage_id.is_empty() else definition_id
	current_biome_name = String(report.get("display_name", "CIDADE BAIXA")) if stage_index == 0 else "PRÓXIMO BIOMA // %s" % String(current_stage_id).to_upper()
	generated_module_count = int(report.get("module_count", 0))
	generation_fallback = bool(report.get("fallback", false))
	generation_failure_reason = String(report.get("failure_reason", ""))
	selected_exit_id = &""
	selected_exit_destination = &""
	if not room_states.has(current_biome_id):
		room_states[current_biome_id] = _new_room_state()
	room_states[current_biome_id].visited = true
	get_current_map_state()
	state_changed.emit()


func prepare_generated_biome(biome_root: Node) -> void:
	if current_biome_id.is_empty() or not room_states.has(current_biome_id):
		return
	var state: Dictionary = room_states[current_biome_id]
	var seen_ids: Dictionary = {}
	for enemy in _find_nodes_in_group(biome_root, &"enemy"):
		var enemy_id: StringName = enemy.persistent_id
		if enemy_id.is_empty() or seen_ids.has(enemy_id):
			push_error("Generated biome enemy ID is empty or duplicated: %s" % enemy_id)
			continue
		seen_ids[enemy_id] = true
		enemy.run_room_id = current_biome_id
		_configure_enemy_stats(enemy)
		if enemy.required_for_completion:
			state.required_enemies[enemy_id] = true
		if state.dead_enemies.has(enemy_id):
			enemy.queue_free()
	_update_room_completion(current_biome_id)
	_spawn_pending_money(current_biome_id, biome_root)
	state_changed.emit()


func select_biome_exit(exit_id: StringName, destination_id: StringName) -> void:
	if not run_active or current_biome_id.is_empty():
		return
	selected_exit_id = exit_id
	selected_exit_destination = destination_id
	room_states[current_biome_id].custom_state.selected_exit_id = exit_id
	room_states[current_biome_id].custom_state.selected_exit_destination = destination_id
	state_changed.emit()


func advance_stage(exit_id: StringName, destination_id: StringName) -> bool:
	if not run_active or run_state != RunState.ACTIVE or destination_id.is_empty() or stage_index >= 5:
		return false
	select_biome_exit(exit_id, destination_id)
	stage_history.append({
		"stage_index": stage_index,
		"biome_id": current_biome_id,
		"exit_id": exit_id,
		"destination_id": destination_id,
	})
	stage_index += 1
	current_stage_id = StringName("%s_stage_%02d" % [destination_id, stage_index])
	current_biome_id = &""
	current_biome_name = ""
	generated_module_count = 0
	state_changed.emit()
	return true


func enter_boss_stage() -> void:
	current_stage_id = &"boss_stage_06"
	current_biome_id = current_stage_id
	current_biome_name = "ARENA DO BOSS"
	generated_module_count = 1
	generation_fallback = false
	generation_failure_reason = ""
	selected_exit_id = &""
	selected_exit_destination = &""
	if not room_states.has(current_biome_id):
		room_states[current_biome_id] = _new_room_state()
	room_states[current_biome_id].visited = true
	state_changed.emit()


func prepare_boss_stage(boss_root: Node) -> void:
	if current_biome_id != &"boss_stage_06":
		return
	var state: Dictionary = room_states[current_biome_id]
	for enemy in _find_nodes_in_group(boss_root, &"enemy"):
		enemy.run_room_id = current_biome_id
		_configure_enemy_stats(enemy)
		state.required_enemies[enemy.persistent_id] = true
		state.required_bosses[enemy.persistent_id] = true
	state_changed.emit()


func get_stage_seed() -> int:
	if stage_index <= 0:
		return seed_value
	return seed_value + stage_index * 104729 + _stable_hash(String(current_stage_id))


func collect_biome_loot(loot_id: StringName, amount: int) -> bool:
	if not run_active or loot_id.is_empty() or collected_biome_loot.has(loot_id):
		return false
	collected_biome_loot[loot_id] = amount
	get_current_map_state().collect_content(&"loot", loot_id)
	dirty_money += maxi(amount, 0)
	total_money_earned += maxi(amount, 0)
	state_changed.emit()
	return true


func get_current_map_state() -> BiomeMapState:
	var state_id := current_stage_id if not current_stage_id.is_empty() else current_biome_id
	if state_id.is_empty():
		state_id = &"stage_00"
	if not map_states.has(state_id):
		var new_state := BIOME_MAP_STATE.new(state_id) as BiomeMapState
		new_state.changed.connect(_on_map_state_changed)
		map_states[state_id] = new_state
	return map_states[state_id] as BiomeMapState


func discover_map_module(module_id: StringName, neighbors: Array[StringName]) -> bool:
	return get_current_map_state().discover_module(module_id, neighbors)


func discover_map_content(kind: StringName, content_id: StringName) -> bool:
	return get_current_map_state().discover_content(kind, content_id)


func activate_map_teleporter(teleporter_id: StringName) -> bool:
	return get_current_map_state().activate_teleporter(teleporter_id)


func serialize_current_map_state() -> Dictionary:
	return get_current_map_state().to_dictionary()


func apply_network_map_state(value: Dictionary) -> void:
	if value.is_empty():
		return
	var state_id := StringName(value.get("stage_id", current_stage_id))
	if not map_states.has(state_id):
		var new_state := BIOME_MAP_STATE.new(state_id) as BiomeMapState
		new_state.changed.connect(_on_map_state_changed)
		map_states[state_id] = new_state
	(map_states[state_id] as BiomeMapState).apply_dictionary(value)


func _on_map_state_changed() -> void:
	state_changed.emit()


func register_enemy_death(room_id: StringName, enemy_id: StringName) -> void:
	if not run_active or not room_states.has(room_id) or enemy_id.is_empty():
		return
	var state: Dictionary = room_states[room_id]
	state.dead_enemies[enemy_id] = true
	_update_room_completion(room_id)
	state_changed.emit()


func set_objective_completed(room_id: StringName, objective_id: StringName) -> void:
	if room_states.has(room_id) and not objective_id.is_empty():
		room_states[room_id].objectives[objective_id] = true
		state_changed.emit()


func collect_reward(room_id: StringName, reward_id: StringName) -> void:
	if room_states.has(room_id) and not reward_id.is_empty():
		room_states[room_id].collected_rewards[reward_id] = true
		room_states[room_id].completed = true
		state_changed.emit()


func is_reward_collected(room_id: StringName, reward_id: StringName) -> bool:
	return room_states.has(room_id) and room_states[room_id].collected_rewards.has(reward_id)


func finish_run() -> void:
	_capture_run_results(true)
	run_state = RunState.COMPLETED
	run_active = false
	run_is_completed = true
	map_states.clear()
	_lock_all_players()
	state_changed.emit()
	run_completed.emit()


func register_participant(participant_id: StringName, active := true) -> void:
	if participant_id.is_empty():
		push_error("Player participant_id cannot be empty")
		return
	participants[participant_id] = active
	if not participant_progress.has(participant_id):
		participant_progress[participant_id] = _new_participant_progress()
	state_changed.emit()


func update_participant_progress(participant_id: StringName, progress: Dictionary) -> void:
	if participant_id.is_empty():
		return
	var stored: Dictionary = participant_progress.get(participant_id, _new_participant_progress())
	for key in progress:
		stored[key] = progress[key]
	participant_progress[participant_id] = stored
	state_changed.emit()


func set_participant_active(participant_id: StringName, active: bool) -> void:
	participants[participant_id] = active
	state_changed.emit()
	if not active and run_active and not _has_active_participant():
		lose_run()


func lose_run() -> void:
	if not run_active:
		return
	run_state = RunState.LOST
	run_active = false
	run_is_lost = true
	_capture_run_results(false)
	map_states.clear()
	_lock_all_players()
	state_changed.emit()
	run_lost.emit()


func apply_network_loss() -> void:
	if run_is_lost:
		return
	run_state = RunState.LOST
	run_active = false
	run_is_lost = true
	_capture_run_results(false)
	map_states.clear()
	_lock_all_players()
	state_changed.emit()
	run_lost.emit()


func apply_network_completion() -> void:
	if run_is_completed:
		return
	run_state = RunState.COMPLETED
	run_active = false
	run_is_completed = true
	_capture_run_results(true)
	map_states.clear()
	_lock_all_players()
	state_changed.emit()
	run_completed.emit()


func get_current_room_id() -> StringName:
	if not current_biome_id.is_empty():
		return current_biome_id
	return RUN_SEQUENCE[current_room_index].id


func is_in_hub() -> bool:
	return run_state == RunState.HUB


func is_gameplay_context_active() -> bool:
	return run_state == RunState.HUB or run_state == RunState.ACTIVE


func get_current_room_type() -> StringName:
	if not current_biome_id.is_empty():
		return StringName(current_biome_name)
	return RUN_SEQUENCE[current_room_index].type


func get_completed_room_count() -> int:
	var total := 0
	for state in room_states.values():
		if state.completed:
			total += 1
	return total


func get_alive_enemy_count() -> int:
	if room_states.is_empty():
		return 0
	var state: Dictionary = room_states[get_current_room_id()]
	var alive := 0
	for enemy_id in state.required_enemies:
		if not state.dead_enemies.has(enemy_id):
			alive += 1
	return alive


func get_alive_boss_count() -> int:
	if room_states.is_empty():
		return 0
	var state: Dictionary = room_states[get_current_room_id()]
	var alive := 0
	for enemy_id in state.required_bosses:
		if not state.dead_enemies.has(enemy_id):
			alive += 1
	return alive


func get_difficulty_config(value: StringName = difficulty) -> Dictionary:
	return DIFFICULTY_CONFIGS.get(value, DIFFICULTY_CONFIGS[&"normal"])


func _apply_difficulty_stats() -> void:
	enemy_health = CombatStats.scaled_health(CombatStats.COMMON_ENEMY_BASE_HP, difficulty)
	ranged_enemy_health = CombatStats.scaled_health(CombatStats.RANGED_ENEMY_BASE_HP, difficulty)
	boss_health = CombatStats.scaled_health(CombatStats.BOSS_BASE_HP, difficulty)
	enemy_melee_damage = CombatStats.scaled_damage(CombatStats.COMMON_ENEMY_BASE_DAMAGE, difficulty)
	ranged_melee_damage = CombatStats.scaled_damage(CombatStats.RANGED_MELEE_BASE_DAMAGE, difficulty)
	ranged_projectile_damage = CombatStats.scaled_damage(CombatStats.RANGED_PROJECTILE_BASE_DAMAGE, difficulty)


func _configure_enemy_stats(enemy: Node) -> void:
	var boss := enemy.has_method("is_boss") and bool(enemy.is_boss())
	var elite := enemy.has_method("is_elite") and bool(enemy.is_elite())
	var configured_health := boss_health
	if not boss:
		var base_health := ranged_enemy_health if enemy.is_in_group("ranged_enemy") else enemy_health
		configured_health = base_health * 2 if elite else base_health
	enemy.configure_health(configured_health)
	if enemy.is_in_group("ranged_enemy") and enemy.has_method("configure_damage"):
		enemy.configure_damage(ranged_melee_damage, ranged_projectile_damage)
	elif enemy.has_method("configure_damage"):
		enemy.configure_damage(enemy_melee_damage)


func get_difficulty_label() -> String:
	return get_difficulty_config().label


func activate_challenge(room_id: StringName, room: Node) -> bool:
	if not room_states.has(room_id):
		return false
	var state: Dictionary = room_states[room_id]
	if state.custom_state.get("challenge_completed", false):
		return false
	state.custom_state.challenge_activated = true
	state.custom_state.exits_locked = true
	_spawn_challenge_enemies(room_id, room)
	for enemy in _find_nodes_in_group(room, &"enemy"):
		if not String(enemy.persistent_id).begins_with("reward_challenge_"):
			continue
		enemy.run_room_id = room_id
		_configure_enemy_stats(enemy)
		state.required_enemies[enemy.persistent_id] = true
	state_changed.emit()
	return true


func is_room_exit_locked(room_id: StringName) -> bool:
	return room_states.has(room_id) and room_states[room_id].custom_state.get("exits_locked", false)


func is_challenge_completed(room_id: StringName) -> bool:
	return room_states.has(room_id) and room_states[room_id].custom_state.get("challenge_completed", false)


func is_chest_paid(room_id: StringName, chest_id: StringName) -> bool:
	return room_states.has(room_id) and room_states[room_id].chest_payments.has(chest_id)


func try_pay_chest(room_id: StringName, chest_id: StringName, cost: int) -> bool:
	if is_chest_paid(room_id, chest_id):
		return true
	if dirty_money < cost or not room_states.has(room_id):
		return false
	dirty_money -= cost
	room_states[room_id].chest_payments[chest_id] = true
	state_changed.emit()
	return true


func get_chest_options(chest_id: StringName, all_options := false) -> Array[StringName]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + _stable_hash(String(chest_id))
	var categories: Array[StringName] = [&"health", &"strength", &"intellect"]
	var option_count := 3 if all_options or rng.randf() < ATTRIBUTE_TRIPLE_CHOICE_CHANCE else 2
	var rotation := posmod(_stable_hash(String(chest_id)), categories.size())
	var result: Array[StringName] = []
	for offset in option_count:
		var category := categories[(rotation + offset) % categories.size()]
		var upgrades := AttributeUpgradeCatalog.get_ids_for_category(category)
		result.append(upgrades[rng.randi_range(0, upgrades.size() - 1)])
	return result


func record_chest_choice(room_id: StringName, chest_id: StringName, participant_id: StringName, attribute: StringName) -> bool:
	if not room_states.has(room_id):
		return false
	var choices: Dictionary = room_states[room_id].chest_choices.get(chest_id, {})
	if choices.has(participant_id):
		return false
	choices[participant_id] = attribute
	room_states[room_id].chest_choices[chest_id] = choices
	state_changed.emit()
	return true


func has_chest_choice(room_id: StringName, chest_id: StringName, participant_id: StringName) -> bool:
	if not room_states.has(room_id):
		return false
	return room_states[room_id].chest_choices.get(chest_id, {}).has(participant_id)


func handle_enemy_drop(room_id: StringName, enemy_id: StringName, enemy_role: int, death_position: Vector2) -> void:
	if not run_active or not room_states.has(room_id):
		return
	var state: Dictionary = room_states[room_id]
	if state.drops_rolled.has(enemy_id):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + _stable_hash("%s:%s" % [room_id, enemy_id])
	var chance := 0.75
	var minimum := 5
	var maximum := 10
	if enemy_role == 1:
		chance = 1.0
		minimum = 50
		maximum = 75
	elif enemy_role == 2:
		chance = 1.0
		minimum = 20
		maximum = 30
	var amount := rng.randi_range(minimum, maximum) if rng.randf() <= chance else 0
	var bandage := rng.randf() <= BANDAGE_DROP_CHANCE
	state.drops_rolled[enemy_id] = {"amount": amount, "collected": amount == 0, "position": death_position, "bandage": bandage, "bandage_collected": not bandage}
	if amount > 0:
		_spawn_money_pickup(room_id, enemy_id, amount, death_position)
	if bandage:
		_spawn_bandage_pickup(room_id, enemy_id, death_position)
	state_changed.emit()


func collect_money_drop(room_id: StringName, drop_id: StringName) -> bool:
	if not room_states.has(room_id):
		return false
	var drops: Dictionary = room_states[room_id].drops_rolled
	if not drops.has(drop_id) or drops[drop_id].collected:
		return false
	drops[drop_id].collected = true
	var collected_amount := int(drops[drop_id].amount)
	dirty_money += collected_amount
	total_money_earned += collected_amount
	state_changed.emit()
	return true


func collect_bandage_drop(room_id: StringName, drop_id: StringName, player: Node) -> bool:
	if not room_states.has(room_id):
		return false
	var drop: Dictionary = room_states[room_id].drops_rolled.get(drop_id, {})
	if drop.is_empty() or drop.get("bandage_collected", true) or not player.apply_bandage(0.10):
		return false
	drop.bandage_collected = true
	var map_state := get_current_map_state()
	if map_state != null:
		map_state.collect_content(&"bandage", drop_id)
	state_changed.emit()
	return true


func collect_all_room_money(room_id: StringName) -> void:
	if not room_states.has(room_id):
		return
	for drop_id in room_states[room_id].drops_rolled:
		collect_money_drop(room_id, drop_id)
	for pickup in get_tree().get_nodes_in_group("dirty_money_pickup"):
		if pickup.room_id == room_id:
			pickup.queue_free()


func _spawn_difficulty_enemies(room_id: StringName, room: Node) -> void:
	if extra_enemy_count <= 0 or not _room_is_combat(room_id):
		return
	if room.has_meta("difficulty_enemies_prepared"):
		return
	room.set_meta("difficulty_enemies_prepared", true)
	var gameplay := room.get_node_or_null("Gameplay") as Node2D
	if gameplay == null:
		push_error("Combat room '%s' has no Gameplay node" % room_id)
		return
	if difficulty == &"inferno_pro":
		_spawn_inferno_enemies(room_id, room, gameplay)
		return
	var markers := _sorted_group_nodes(room, &"enemy_extra_spawn")
	if markers.size() < extra_enemy_count:
		push_error("Room '%s' needs %d difficulty spawn markers, but has %d" % [room_id, extra_enemy_count, markers.size()])
		return
	for index in extra_enemy_count:
		var marker := markers[index] as Marker2D
		_spawn_enemy(gameplay, marker, StringName("%s_extra_%02d" % [room_id, index + 1]))


func _spawn_inferno_enemies(room_id: StringName, room: Node, gameplay: Node2D) -> void:
	var ground_markers := _sorted_group_nodes(room, &"enemy_extra_spawn")
	var ground_count := 2 if room_id == &"boss_01" else 3
	if ground_markers.size() < ground_count:
		push_error("Room '%s' needs %d Inferno ground markers, but has %d" % [room_id, ground_count, ground_markers.size()])
		return
	for index in ground_count:
		var ground_id := StringName("%s_inferno_ground_%02d" % [room_id, index + 1])
		if room_id == &"boss_01":
			ground_id = StringName("boss_01_inferno_normal_%02d" % (index + 1))
		_spawn_enemy(gameplay, ground_markers[index], ground_id)
	for marker in _sorted_group_nodes(room, &"inferno_platform_spawn"):
		var suffix := String(marker.get_meta("persistent_suffix", marker.name)).to_lower()
		_spawn_enemy(gameplay, marker, StringName("%s_%s" % [room_id, suffix]))
	if room_id == &"boss_01":
		_spawn_second_inferno_boss(room, gameplay)


func _spawn_challenge_enemies(room_id: StringName, room: Node) -> void:
	if room_id != &"reward_01" or not room_states.has(room_id):
		return
	var state: Dictionary = room_states[room_id]
	if not state.custom_state.get("challenge_activated", false) or room.has_meta("challenge_enemies_prepared"):
		return
	room.set_meta("challenge_enemies_prepared", true)
	var gameplay := room.get_node_or_null("Gameplay") as Node2D
	if gameplay == null:
		return
	var elite_markers := _sorted_group_nodes(room, &"challenge_elite_spawn")
	var basic_markers := _sorted_group_nodes(room, &"challenge_basic_spawn")
	if elite_markers.is_empty() or basic_markers.size() < CHALLENGE_BASIC_COUNTS[difficulty]:
		push_error("Reward challenge spawn markers are incomplete")
		return
	if not state.dead_enemies.has(&"reward_challenge_elite"):
		var elite := ENEMY_SCENE.instantiate()
		elite.name = "RewardChallengeElite"
		elite.persistent_id = &"reward_challenge_elite"
		elite.configure_elite()
		gameplay.add_child(elite)
		elite.position = gameplay.to_local((elite_markers[0] as Marker2D).global_position)
	for index in CHALLENGE_BASIC_COUNTS[difficulty]:
		var enemy_id := StringName("reward_challenge_basic_%02d" % (index + 1))
		if not state.dead_enemies.has(enemy_id):
			_spawn_enemy(gameplay, basic_markers[index], enemy_id)


func _apply_ranged_composition(room_id: StringName, room: Node) -> void:
	if not RANGED_COUNTS.has(room_id):
		return
	var desired_count: int = RANGED_COUNTS[room_id].get(difficulty, 0)
	if desired_count <= 0:
		return
	var candidates: Array[Node] = []
	for enemy in _find_nodes_in_group(room, &"enemy"):
		if enemy.is_boss() or enemy.is_elite() or String(enemy.persistent_id).begins_with("reward_challenge_"):
			continue
		candidates.append(enemy)
	candidates.sort_custom(func(a: Node, b: Node) -> bool:
		if not is_equal_approx(a.global_position.y, b.global_position.y):
			return a.global_position.y < b.global_position.y
		return String(a.persistent_id) < String(b.persistent_id)
	)
	for index in mini(desired_count, candidates.size()):
		_replace_with_ranged(candidates[index])


func _replace_with_ranged(enemy: Node) -> void:
	var parent := enemy.get_parent()
	if parent == null:
		return
	var replacement := RANGED_ENEMY_SCENE.instantiate()
	replacement.name = "%sRanged" % enemy.name
	replacement.persistent_id = enemy.persistent_id
	replacement.required_for_completion = enemy.required_for_completion
	var local_position: Vector2 = enemy.position
	parent.remove_child(enemy)
	enemy.queue_free()
	parent.add_child(replacement)
	replacement.position = local_position


func _spawn_pending_money(room_id: StringName, room: Node) -> void:
	var state: Dictionary = room_states[room_id]
	for drop_id in state.drops_rolled:
		var drop: Dictionary = state.drops_rolled[drop_id]
		if drop.amount > 0 and not drop.collected:
			_spawn_money_pickup(room_id, drop_id, drop.amount, drop.position, room)
		if drop.get("bandage", false) and not drop.get("bandage_collected", false):
			_spawn_bandage_pickup(room_id, drop_id, drop.position, room)


func _spawn_bandage_pickup(room_id: StringName, drop_id: StringName, position: Vector2, room_override: Node = null) -> void:
	var room := room_override
	if room == null:
		var room_manager := get_tree().get_first_node_in_group("room_manager")
		room = room_manager.current_room if room_manager else null
	if room == null:
		return
	for existing in _find_nodes_in_group(room, &"bandage_pickup"):
		if existing.pickup_id == drop_id:
			return
	var pickup := BANDAGE_PICKUP_SCRIPT.new() as BandagePickup
	pickup.pickup_id = drop_id
	pickup.room_id = room_id
	room.add_child(pickup)
	pickup.global_position = position


func _spawn_money_pickup(room_id: StringName, drop_id: StringName, amount: int, position: Vector2, room_override: Node = null) -> void:
	var room := room_override
	if room == null:
		var room_manager := get_tree().get_first_node_in_group("room_manager")
		room = room_manager.current_room if room_manager else null
	if room == null:
		return
	for existing in _find_nodes_in_group(room, &"dirty_money_pickup"):
		if existing.drop_id == drop_id:
			return
	var pickup := MONEY_PICKUP_SCENE.instantiate()
	pickup.add_to_group("dirty_money_pickup")
	pickup.drop_id = drop_id
	pickup.room_id = room_id
	pickup.amount = amount
	room.add_child(pickup)
	pickup.global_position = position
	pickup.get_node("Label").text = "$%d" % amount


func _stable_hash(value: String) -> int:
	var result := 2166136261
	for byte in value.to_utf8_buffer():
		result = int((result ^ byte) * 16777619) & 0x7fffffff
	return result


func _spawn_second_inferno_boss(room: Node, gameplay: Node2D) -> void:
	var bosses: Array = _find_nodes_in_group(room, &"enemy").filter(func(enemy: Node) -> bool: return enemy.is_boss())
	var boss_markers := _sorted_group_nodes(room, &"inferno_boss_spawn")
	if bosses.size() != 1 or boss_markers.size() < 2:
		push_error("Inferno boss room requires one original boss and two boss markers")
		return
	var original = bosses[0]
	original.persistent_id = &"boss_01_inferno_a"
	original.position = gameplay.to_local((boss_markers[0] as Marker2D).global_position)
	var second := ENEMY_SCENE.instantiate()
	second.name = "InfernoBossB"
	second.persistent_id = &"boss_01_inferno_b"
	second.enemy_role = 1
	second.visual_scale = original.visual_scale
	gameplay.add_child(second)
	second.position = gameplay.to_local((boss_markers[1] as Marker2D).global_position)


func _spawn_enemy(parent: Node2D, marker: Marker2D, enemy_id: StringName) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	enemy.name = String(enemy_id).to_pascal_case()
	enemy.persistent_id = enemy_id
	parent.add_child(enemy)
	enemy.position = parent.to_local(marker.global_position)


func _sorted_group_nodes(room: Node, group_name: StringName) -> Array[Node]:
	var result := _find_nodes_in_group(room, group_name)
	result.sort_custom(func(a: Node, b: Node) -> bool: return _marker_sort_key(a) < _marker_sort_key(b))
	return result


func _marker_sort_key(marker: Node) -> String:
	return String(marker.get_meta("persistent_suffix", marker.name))


func _room_is_combat(room_id: StringName) -> bool:
	for room_data in RUN_SEQUENCE:
		if room_data.id == room_id:
			return room_data.combat
	return false


func _update_room_completion(room_id: StringName) -> void:
	var state: Dictionary = room_states[room_id]
	var required: Dictionary = state.required_enemies
	if required.is_empty():
		return
	for enemy_id in required:
		if not state.dead_enemies.has(enemy_id):
			return
	state.completed = true
	if state.custom_state.get("challenge_activated", false):
		state.custom_state.challenge_completed = true
		state.custom_state.exits_locked = false


func _find_nodes_in_group(root_node: Node, group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	if root_node.is_in_group(group_name):
		result.append(root_node)
	for child in root_node.get_children():
		result.append_array(_find_nodes_in_group(child, group_name))
	return result


func _new_room_state() -> Dictionary:
	return {"visited": false, "completed": false, "dead_enemies": {}, "required_enemies": {}, "required_bosses": {}, "drops_rolled": {}, "chest_payments": {}, "chest_choices": {}, "objectives": {}, "collected_rewards": {}, "custom_state": {}}


func _new_participant_progress() -> Dictionary:
	return {"heal_doses": 4, "intellect": 0, "health": 0, "strength": 0, "current_hp": CombatStats.PLAYER_BASE_MAX_HP, "max_hp": CombatStats.PLAYER_BASE_MAX_HP, "melee_damage": CombatStats.PLAYER_BASE_MELEE_DAMAGE}


func _has_active_participant() -> bool:
	for active in participants.values():
		if active:
			return true
	return false


func _lock_all_players() -> void:
	if not is_inside_tree():
		return
	for player in get_tree().get_nodes_in_group("player"):
		player.set_input_enabled(false)


func _clear_biome_state() -> void:
	current_biome_id = &""
	current_biome_name = ""
	generated_module_count = 0
	generation_fallback = false
	generation_failure_reason = ""
	selected_exit_id = &""
	selected_exit_destination = &""
	collected_biome_loot.clear()
	map_states.clear()


func record_weapon_found(participant_id: StringName, weapon_id: StringName) -> void:
	var player_weapons: Array = weapons_found.get(participant_id, []) as Array
	if not player_weapons.has(weapon_id):
		player_weapons.append(weapon_id)
	weapons_found[participant_id] = player_weapons
	state_changed.emit()


func format_run_time(value: float = run_elapsed_time) -> String:
	var total_seconds := maxi(0, floori(value))
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	var seconds := total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds] if hours > 0 else "%02d:%02d" % [minutes, seconds]


func _capture_run_results(completed: bool) -> void:
	last_run_results = {
		"completed": completed,
		"elapsed_time": run_elapsed_time,
		"money_earned": total_money_earned,
		"money_remaining": dirty_money,
		"difficulty": difficulty,
		"stage_index": stage_index,
		"player_count": player_count,
		"stage_history": stage_history.duplicate(true),
		"participants": participant_progress.duplicate(true),
		"weapons_found": weapons_found.duplicate(true),
	}


func _reset_run_quality_state() -> void:
	run_elapsed_time = 0.0
	total_money_earned = 0
	weapons_found.clear()
	last_run_results.clear()
