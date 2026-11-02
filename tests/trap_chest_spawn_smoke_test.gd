extends SceneTree
## P1-A (02/11/2026) — baús trap no JOGO REAL: main.tscn → Casa → run → baú trap aberto
## pelo jogador em Cidade Baixa, Industrial e Laboratório (saídas reais entre biomas).
## Regressão: a emboscada nascia na origem do pai, era movida depois do `_ready()` e o
## primeiro pouso aplicava dano de queda da origem até o ponto (vida baixa ou morte).
##   godot --headless --path . --script res://tests/trap_chest_spawn_smoke_test.gd

const SETTLE_FRAMES := 150

var game: Node
var player: CharacterBody2D
var failures: PackedStringArray = []
var traps_tested := 0
var enemies_tested := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TRAP_CHEST_FAIL " + message)


func _run() -> void:
	for difficulty: StringName in [&"normal", &"inferno_pro"]:
		await _run_difficulty(difficulty, 51031 if difficulty == &"normal" else 77219)
	_check(traps_tested >= 4, "baús trap testados nos três biomas (%d)" % traps_tested)
	print("TRAP_CHEST_REPORT traps=%d enemies=%d failures=%d %s" % [traps_tested, enemies_tested, failures.size(), JSON.stringify(failures)])
	if failures.is_empty():
		print("TRAP_CHEST_SPAWN_SMOKE_TEST_OK")
	quit(0 if failures.is_empty() else 1)


func _run_difficulty(difficulty: StringName, run_seed: int) -> void:
	var temp := "user://trap_chest_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(temp)
	game = load("res://scene/main.tscn").instantiate()
	game.get_node("LocalSettings").settings_path = temp.path_join("settings.cfg")
	game.get_node("MetaProgression").save_path = temp.path_join("meta.json")
	root.add_child(game)
	await process_frame
	await game.start_configured_run(&"solo", difficulty, -1)
	player = game.get_players()[0]
	await game._begin_run_from_hub(run_seed)
	await process_frame
	for stage in 3:
		var biome := String(game.run_manager.current_biome_name)
		await _test_traps_in_current_biome("%s/%s" % [difficulty, biome])
		if stage < 2:
			await _take_real_exit()
	game.queue_free()
	await process_frame
	await process_frame


func _test_traps_in_current_biome(context: String) -> void:
	var traps: Array[TrapChest] = []
	for node in game.current_room.find_children("*", "Area2D", true, false):
		if node is TrapChest:
			traps.append(node)
	_check(not traps.is_empty(), "%s tem baú trap" % context)
	for trap in traps:
		await _open_trap(trap, context)


func _open_trap(trap: TrapChest, context: String) -> void:
	var manager: Node = game.run_manager
	var state: BiomeMapState = manager.get_current_map_state()
	var trap_id := trap.trap_id
	player.is_invulnerable = true
	player.invulnerability_timer = 9999.0
	player.global_position = trap.global_position + Vector2(0, -8)
	player.velocity = Vector2.ZERO
	await physics_frame
	var health_before: int = int(player.health)
	trap.interact(player)
	_check(state.get_trap_event_state(trap_id) == BiomeMapState.TRAP_ACTIVE, "%s %s: abrir ativa a emboscada" % [context, trap_id])
	var ids: Array[StringName] = state.get_trap_event_enemy_ids(trap_id)
	var expected_roles: Array[StringName] = manager.get_trap_event_composition(trap_id, trap.event_spawn_positions.size())
	_check(ids.size() >= 2, "%s %s: emboscada com ≥2 inimigos (%d)" % [context, trap_id, ids.size()])
	await physics_frame
	var enemies: Array[Node] = []
	for enemy_id in ids:
		var enemy := _find_enemy(enemy_id)
		_check(enemy != null, "%s %s: %s nasceu" % [context, trap_id, enemy_id])
		if enemy != null:
			enemies.append(enemy)
			var index := ids.find(enemy_id)
			var spawn: Vector2 = trap.event_spawn_positions[index]
			_check(enemy.global_position.distance_to(spawn) < 40.0, "%s %s: nasce no ponto da emboscada" % [context, enemy_id])
			_check(Vector2(enemy.get("patrol_origin")).distance_to(spawn) < 40.0, "%s %s: patrulha ancorada no ponto (não na origem do bioma)" % [context, enemy_id])
			var expected := _expected_health(manager, expected_roles[index])
			_check(int(enemy.max_health) == expected and int(enemy.health) == expected, "%s %s: vida inicial cheia %d/%d (esperado %d)" % [context, enemy_id, int(enemy.health), int(enemy.max_health), expected])
	# Deixa a física correr (pouso, IA, colisões) sem ninguém atacar os inimigos.
	player.set_input_enabled(false)
	for i in SETTLE_FRAMES:
		player.global_position = trap.global_position + Vector2(0, -8)
		await physics_frame
	for enemy in enemies:
		enemies_tested += 1
		var alive: bool = is_instance_valid(enemy) and enemy.get("is_dead") != true and int(enemy.health) > 0
		_check(alive, "%s %s: vivo após %d quadros de física" % [context, enemy.name if is_instance_valid(enemy) else "?", SETTLE_FRAMES])
		if alive:
			_check(int(enemy.health) == int(enemy.max_health), "%s %s: sem dano no spawn (vida %d/%d)" % [context, enemy.name, int(enemy.health), int(enemy.max_health)])
	_check(state.get_trap_event_state(trap_id) == BiomeMapState.TRAP_ACTIVE, "%s %s: emboscada continua ativa até ser derrotada" % [context, trap_id])
	# Fecha o evento pelo caminho de combate real (dano do jogador) e coleta a recompensa.
	for enemy in enemies:
		if is_instance_valid(enemy) and int(enemy.health) > 0:
			enemy.take_damage(int(enemy.health) + 5, 0.0, 0.0)
	for i in 30:
		await physics_frame
	_check(state.get_trap_event_state(trap_id) == BiomeMapState.TRAP_CLEARED, "%s %s: derrotar a emboscada libera a recompensa" % [context, trap_id])
	var money_before: int = int(manager.dirty_money)
	if is_instance_valid(trap):
		trap.interact(player)
	_check(int(manager.dirty_money) > money_before, "%s %s: recompensa coletada" % [context, trap_id])
	_check(int(player.health) == health_before, "jogador invulnerável no teste")
	player.set_input_enabled(true)
	traps_tested += 1


func _expected_health(manager: Node, role: StringName) -> int:
	match role:
		&"heavy": return int(manager.heavy_enemy_health)
		&"ranged": return int(manager.ranged_enemy_health)
		_: return int(manager.enemy_health)


func _find_enemy(enemy_id: StringName) -> Node:
	for node in game.current_room.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group("enemy") and StringName(node.get("persistent_id")) == enemy_id:
			return node
	return null


func _take_real_exit() -> void:
	var exit: Area2D = null
	for node in game.current_room.find_children("*", "Area2D", true, false):
		if node.get_script() == preload("res://scene/biomes/biome_exit.gd"):
			exit = node
			break
	_check(exit != null, "bioma tem saída real")
	if exit == null:
		return
	var stage_before: int = int(game.run_manager.stage_index)
	player.global_position = exit.global_position
	player.velocity = Vector2.ZERO
	for i in 4:
		await physics_frame
	await game.request_biome_advance(exit.exit_id, exit.destination_id)
	await process_frame
	_check(int(game.run_manager.stage_index) == stage_before + 1, "saída real avança o estágio")
