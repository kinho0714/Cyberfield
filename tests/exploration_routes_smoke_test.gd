extends SceneTree
## P1-C (02/11/2026) — exploração no JOGO REAL.
## 1) Geração (3 biomas × várias sementes): poços do caminho crítico têm escada de serviço;
##    poços de ramos laterais seguem só com escalada; layout/inimigos idênticos; toda run
##    tem passagem de dash com baú secreto em área livre.
## 2) Física real: com a escalada de parede DESLIGADA, um "robô" de entrada (pular + andar)
##    sobe um poço do caminho crítico pela escada; sem a escada, não sobe (controle).
## 3) Passagem de dash: andar e pular não abrem; dash abre, fica registrado no mapa, o baú
##    secreto solta a arma real. Saídas continuam funcionando.
##   godot --headless --path . --script res://tests/exploration_routes_smoke_test.gd

const SCENES := {
	&"lower_city": "res://scene/biomes/lower_city/lower_city_biome.tscn",
	&"industrial": "res://scene/biomes/industrial/industrial_biome.tscn",
	&"lab": "res://scene/biomes/lab/lab_biome.tscn",
}
const SAMPLES := 10

var failures: PackedStringArray = []
var game: Node
var player: CharacterBody2D


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("EXPLORATION_FAIL " + message)


func _run() -> void:
	_test_generation()
	await _setup_game()
	await _test_service_stairs()
	await _test_dash_passage()
	await _test_progression()
	print("EXPLORATION_REPORT failures=%d %s" % [failures.size(), JSON.stringify(failures)])
	if failures.is_empty():
		print("EXPLORATION_ROUTES_SMOKE_TEST_OK")
	quit(0 if failures.is_empty() else 1)


func _test_generation() -> void:
	var with_passage := 0
	var total := 0
	var critical_up_total := 0
	var served_up_total := 0
	var secondary_shafts := 0
	for kind: StringName in SCENES:
		for sample in SAMPLES:
			var run_seed := 830000 + sample * 7919
			var manager = load("res://scene/run_manager.gd").new()
			root.add_child(manager)
			manager.configure_run(&"solo", &"normal")
			manager.prepare_new_run(run_seed)
			manager.configure_run_weapon_pool(WeaponCatalog.discoverable_ids())
			var biome = load(SCENES[kind]).instantiate()
			root.add_child(biome)
			_check(biome.generate(run_seed, manager), "gera %s %d" % [kind, run_seed])
			var report: Dictionary = biome.get_generation_report()
			total += 1
			var nodes: Array = biome._nodes
			var critical: Dictionary = biome._critical_path_edges()
			var vertical_edges := 0
			for i in nodes.size():
				for n_value: Variant in nodes[i].neighbors:
					var n := int(n_value)
					if n > i and (nodes[i].grid as Vector2i).x == (nodes[n].grid as Vector2i).x:
						vertical_edges += 1
						if not critical.has("%d:%d" % [i, n]):
							secondary_shafts += 1
			var critical_vertical := 0
			for key: Variant in critical:
				var parts := String(key).split(":")
				if (nodes[int(parts[0])].grid as Vector2i).x == (nodes[int(parts[1])].grid as Vector2i).x:
					critical_vertical += 1
			_check(int(report.service_shaft_count) == critical_vertical, "%s %d: todo poço do caminho crítico tem escada (%d/%d)" % [kind, run_seed, int(report.service_shaft_count), critical_vertical])
			_check(int(report.service_step_count) >= int(report.service_shaft_count) * 5, "%s: ≥5 degraus por poço" % kind)
			critical_up_total += critical_vertical
			served_up_total += int(report.service_shaft_count)
			# Paredes dos poços intactas (contrato do hotfix de escalada): mesmos pares.
			var walls := (biome.get_node("VerticalConnections") as Node2D).get_child_count()
			_check(walls == vertical_edges * 2, "%s: paredes dos poços inalteradas" % kind)
			for step in biome.get_node("ShaftServiceSteps").get_children():
				var shape := step.get_child(0) as CollisionShape2D
				_check(shape.one_way_collision, "degrau é plataforma de passagem (não prende a escalada)")
				break
			if int(report.dash_passage_count) > 0:
				with_passage += 1
				var entry: Dictionary = (report.dash_passages as Array)[0]
				_check(not StringName(String(report.weapon_offers.get(entry.secret_id, ""))).is_empty(), "%s: baú secreto com arma" % kind)
				var passage: Array = biome.find_children("DashPassage", "", true, false)
				_check(passage.size() == 1 and passage[0] is DashPassage, "%s: DashPassage real na alcova" % kind)
			biome.free()
			manager.free()
	print("EXPLORATION_STATS biomes=%d with_dash_passage=%d critical_shafts=%d served=%d secondary_parkour_shafts=%d" % [total, with_passage, critical_up_total, served_up_total, secondary_shafts])
	_check(float(with_passage) / float(total) >= 0.85, "passagem de dash em ≥85%% dos biomas (%d/%d)" % [with_passage, total])
	_check(secondary_shafts > 0, "ramos laterais continuam com poços de parkour")


func _setup_game() -> void:
	var temp := "user://exploration_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(temp)
	game = load("res://scene/main.tscn").instantiate()
	game.get_node("LocalSettings").settings_path = temp.path_join("settings.cfg")
	game.get_node("MetaProgression").save_path = temp.path_join("meta.json")
	root.add_child(game)
	await process_frame
	await game.start_configured_run(&"solo", &"normal", -1)
	player = game.get_players()[0]


## Run cuja Cidade Baixa tem poço de serviço e passagem de dash.
func _enter_run_with(feature: String) -> bool:
	for attempt in 12:
		if not bool(game.current_is_hub):
			await game.return_to_laboratory()
			await process_frame
		await game._begin_run_from_hub(840101 + attempt * 977)
		await process_frame
		var report: Dictionary = game.current_room.get_generation_report()
		if feature == "stairs" and int(report.service_shaft_count) > 0:
			return true
		if feature == "dash" and int(report.dash_passage_count) > 0:
			return true
	return false


func _test_service_stairs() -> void:
	_check(await _enter_run_with("stairs"), "run com poço de serviço")
	var steps: Array = game.current_room.get_node("ShaftServiceSteps").get_children()
	if steps.is_empty():
		return
	# Agrupa os degraus pelo poço (centro x da célula).
	var shafts := {}
	for step: Node2D in steps:
		var cell := floori(step.global_position.x / BiomeGenerator.CELL_SIZE.x)
		var key := "%d:%d" % [cell, floori((step.global_position.y + 30.0) / BiomeGenerator.CELL_SIZE.y)]
		if not shafts.has(key):
			shafts[key] = []
		(shafts[key] as Array).append(step)
	var shaft: Array = shafts.values()[0]
	shaft.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.y > b.global_position.y)
	var center_x := (floorf(shaft[0].global_position.x / BiomeGenerator.CELL_SIZE.x) + 0.5) * BiomeGenerator.CELL_SIZE.x
	var lower_floor: float = shaft[0].global_position.y - BiomeGenerator.SHAFT_STEP_THICKNESS * 0.5 + BiomeGenerator.SHAFT_STEP_SPACING
	var upper_floor := lower_floor - BiomeGenerator.CELL_SIZE.y
	player.is_invulnerable = true
	player.invulnerability_timer = 9999.0
	var climbed := await _bot_climb(shaft, center_x, lower_floor, upper_floor)
	_check(climbed, "robô sobe o poço só pulando (escalada desligada) pela escada de serviço")
	# Controle: sem a escada o mesmo robô não sobe — prova que a escada é o que libera a rota.
	for step: Node2D in shaft:
		(step.get_child(0) as CollisionShape2D).disabled = true
	await physics_frame
	var climbed_without := await _bot_climb([], center_x, lower_floor, upper_floor)
	_check(not climbed_without, "sem a escada (e sem escalar) o poço não é vencido")
	for step: Node2D in shaft:
		(step.get_child(0) as CollisionShape2D).disabled = false
	# Descer continua livre: baixo + pulo atravessa os degraus até o chão de baixo.
	player.global_position = Vector2(center_x, upper_floor - 140.0)
	player.velocity = Vector2.ZERO
	var reached_bottom := false
	for frame in 420:
		await physics_frame
		if player.is_on_floor() and player.global_position.y < lower_floor - 60.0:
			Input.action_press(&"down")
			Input.action_press(&"jump")
			await physics_frame
			Input.action_release(&"jump")
			Input.action_release(&"down")
		if player.is_on_floor() and player.global_position.y > lower_floor - 60.0:
			reached_bottom = true
			break
	_check(reached_bottom, "descer pelo poço continua possível (atravessa os degraus)")
	_release()


func _bot_climb(shaft: Array, center_x: float, lower_floor: float, upper_floor: float) -> bool:
	_release()
	player.max_wall_climb_duration = 0.0
	player.wall_climb_time = 0.0
	player.global_position = Vector2(center_x - 30.0, lower_floor - 40.0)
	player.velocity = Vector2.ZERO
	for i in 20:
		await physics_frame
	var foot_offset := lower_floor - player.global_position.y
	var target_x := center_x
	var success := false
	for frame in 1100:
		var feet := player.global_position.y + foot_offset
		player.wall_climb_time = 0.0
		if player.is_on_floor() and feet <= upper_floor + 6.0:
			success = true
			break
		if player.is_on_floor():
			var next: Node2D = null
			for step: Node2D in shaft:
				var top: float = step.global_position.y - BiomeGenerator.SHAFT_STEP_THICKNESS * 0.5
				if top < feet - 20.0 and (next == null or top > next.global_position.y - BiomeGenerator.SHAFT_STEP_THICKNESS * 0.5):
					next = step
			if next != null:
				target_x = next.global_position.x
			else:
				var side := 1.0 if (shaft.is_empty() or shaft[shaft.size() - 1].global_position.x > center_x) else -1.0
				target_x = center_x + side * 110.0
			Input.action_press(&"jump")
			await physics_frame
			Input.action_release(&"jump")
		var dx := target_x - player.global_position.x
		Input.action_release(&"left")
		Input.action_release(&"right")
		if absf(dx) > 8.0:
			Input.action_press(&"right" if dx > 0.0 else &"left")
		await physics_frame
	_release()
	player.max_wall_climb_duration = player.WALL_CLIMB_DURATION
	player.wall_climb_time = player.WALL_CLIMB_DURATION
	return success


func _test_dash_passage() -> void:
	_check(await _enter_run_with("dash"), "run com passagem de dash")
	var report: Dictionary = game.current_room.get_generation_report()
	if int(report.dash_passage_count) == 0:
		return
	var entry: Dictionary = (report.dash_passages as Array)[0]
	var passage := game.current_room.find_children("DashPassage", "", true, false)[0] as DashPassage
	var chest: Node2D = game.current_room.find_children("SecretLoot01", "", true, false)[0]
	var direction := 1.0 if String(entry.side) == "right" else -1.0
	var floor_y: float = float(chest.global_position.y) + 26.0
	player.is_invulnerable = true
	player.invulnerability_timer = 9999.0
	player.dev_invincible = true
	player.global_position = Vector2(passage.global_position.x - direction * 150.0, floor_y - 40.0)
	player.velocity = Vector2.ZERO
	for i in 20:
		await physics_frame
	var action := &"right" if direction > 0.0 else &"left"
	Input.action_press(action)
	for i in 70:
		await physics_frame
	var blocked_x := player.global_position.x
	_check(not passage.is_open and absf(blocked_x - passage.global_position.x) > 18.0, "andar contra a parede não abre")
	Input.action_press(&"jump")
	await physics_frame
	Input.action_release(&"jump")
	for i in 50:
		await physics_frame
	_check(not passage.is_open, "pular contra a parede não abre")
	player.global_position = Vector2(passage.global_position.x - direction * 120.0, floor_y - 40.0)
	for i in 10:
		await physics_frame
	Input.action_press(&"dash")
	await physics_frame
	Input.action_release(&"dash")
	for i in 30:
		await physics_frame
		if passage.is_open:
			break
	_check(passage.is_open, "dash abre a passagem secreta")
	_check(game.run_manager.get_current_map_state().is_content_collected(&"passage", passage.passage_id), "abertura registrada no mapa (sincroniza na LAN)")
	for i in 80:
		await physics_frame
	Input.action_release(action)
	_check(direction * (player.global_position.x - passage.global_position.x) > 20.0, "jogador atravessa para a alcova")
	var weapon_id := StringName(chest.reward_weapon_id)
	player.global_position = chest.global_position + Vector2(0, -6)
	await physics_frame
	chest.interact(player)
	await process_frame
	var pickup: WeaponPickup = null
	for node in game.current_room.find_children("*", "Area2D", true, false):
		if node is WeaponPickup and node.weapon_id == weapon_id:
			pickup = node
	_check(pickup != null and RarityTable.index(pickup.rarity) >= RarityTable.index(&"uncommon"), "baú secreto solta arma real (mín. incomum)")
	_release()


## Progressão: só saídas A reproduzem a sequência antiga; B aprofunda/atalha; rótulos reais.
func _test_progression() -> void:
	var manager: Node = game.run_manager
	var saved: Dictionary = manager.stage_biome_kinds.duplicate()
	var saved_stage: int = int(manager.stage_index)
	var sequence: Array[StringName] = [manager.get_stage_biome_kind(0)]
	manager.stage_biome_kinds.clear()
	for stage in 5:
		var next: StringName = manager.preview_exit_biome(&"next_biome_a", stage)
		manager.stage_biome_kinds[stage + 1] = next
		sequence.append(next)
	_check(sequence == [&"lower_city", &"industrial", &"lab", &"industrial", &"lab", &"boss"], "só saídas A = sequência antiga (%s)" % [sequence])
	manager.stage_biome_kinds.clear()
	_check(manager.preview_exit_biome(&"next_biome_b", 0) == &"lab", "B na Cidade Baixa: atalho ao Laboratório")
	manager.stage_biome_kinds[1] = &"industrial"
	_check(manager.preview_exit_biome(&"next_biome_b", 1) == &"industrial", "B no Industrial: aprofundar")
	_check(manager.preview_exit_biome(&"next_biome_b", 4) == &"boss" and manager.preview_exit_biome(&"next_biome_a", 4) == &"boss", "estágio 4 → chefe pelas duas saídas")
	manager.stage_biome_kinds = saved
	manager.stage_index = saved_stage
	# Jogo real: saída B da Cidade Baixa leva ao Laboratório; depois A leva ao Industrial.
	if not bool(manager.run_active):
		return
	for expected: Array in [[&"exit_b", &"lab", "LABORATÓRIO"], [&"exit_a", &"industrial", "INDUSTRIAL"]]:
		var exit: Area2D = null
		for node in game.current_room.find_children("*", "Area2D", true, false):
			if node.get_script() == preload("res://scene/biomes/biome_exit.gd") and StringName(node.exit_id) == expected[0]:
				exit = node
		_check(exit != null, "saída %s existe" % expected[0])
		if exit == null:
			return
		var label := String((exit.get_node("Label") as Label).text)
		_check(label.contains(String(expected[2])), "rótulo da saída mostra o destino real: %s" % label)
		var stage_before := int(manager.stage_index)
		player.global_position = exit.global_position
		player.velocity = Vector2.ZERO
		for i in 4:
			await physics_frame
		await game.request_biome_advance(exit.exit_id, exit.destination_id)
		await process_frame
		_check(int(manager.stage_index) == stage_before + 1 and manager.current_biome_kind == expected[1], "%s leva a %s (%s)" % [expected[0], expected[1], manager.current_biome_kind])


func _release() -> void:
	for action: StringName in [&"left", &"right", &"jump", &"down", &"dash"]:
		Input.action_release(action)
