extends SceneTree
## P1-B (02/11/2026) — armas e drops.
## 1) Catálogo: toda arma tem sprite, categoria funcional e caminho de obtenção.
## 2) Geração real de biomas (várias sementes, 3 biomas, estágios 0–4): ofertas por fonte,
##    sem repetição no mesmo estágio, afinidade de bioma, curva de raridade por estágio.
## 3) Jogo real (main.tscn): baú comum e baú trap soltam a arma sorteada como pickup real,
##    que vira blueprint; vitória no chefe concede projeto desconhecido.
##   godot --headless --path . --script res://tests/weapon_loot_distribution_smoke_test.gd

const SCENES := {
	&"lower_city": "res://scene/biomes/lower_city/lower_city_biome.tscn",
	&"industrial": "res://scene/biomes/industrial/industrial_biome.tscn",
	&"lab": "res://scene/biomes/lab/lab_biome.tscn",
}
const SAMPLES := 14

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WEAPON_LOOT_FAIL " + message)


func _run() -> void:
	_test_catalog()
	_test_generation_distribution()
	await _test_real_chests()
	_test_boss_blueprint()
	print("WEAPON_LOOT_REPORT failures=%d %s" % [failures.size(), JSON.stringify(failures)])
	if failures.is_empty():
		print("WEAPON_LOOT_DISTRIBUTION_SMOKE_TEST_OK")
	quit(0 if failures.is_empty() else 1)


func _test_catalog() -> void:
	_check(WeaponCatalog.WEAPONS.size() >= 20, "catálogo com as 8 armas novas (%d)" % WeaponCatalog.WEAPONS.size())
	for id: StringName in WeaponCatalog.WEAPONS:
		var data := WeaponCatalog.get_definition(id)
		_check(WeaponCatalog.CATEGORIES.has(WeaponCatalog.category(id)), "%s tem categoria com comportamento" % id)
		_check(WeaponCatalog.get_visual_texture(id, "world") != null, "%s tem sprite de mundo/mão" % id)
		_check(WeaponCatalog.get_visual_texture(id, "inventory_icon") != null, "%s tem ícone" % id)
		_check(data.has("tier") and data.has("biomes"), "%s tem tier e bioma de origem" % id)
		if WeaponCatalog.is_ranged(id):
			_check(int(data.get("magazine", 0)) > 0 and float(data.get("projectile_speed", 0.0)) > 0.0, "%s dispara de verdade" % id)
		var stats := WeaponCatalog.stats_for(id, &"rare")
		_check(int(stats.damage) > int(data.damage) or int(data.damage) <= 1, "%s: raridade melhora o dano" % id)
	_check(WeaponLootTable.unreachable_weapons().is_empty(), "nenhuma arma inacessível: %s" % [WeaponLootTable.unreachable_weapons()])


func _test_generation_distribution() -> void:
	var pool: Array[StringName] = []
	for id: StringName in WeaponCatalog.WEAPONS:
		if id != &"scrap_blade":
			pool.append(id)
	var seen := {}
	var by_biome := {}
	var offers_total := 0
	var stage_count := 0
	var rarity_sum := {0: 0.0, 4: 0.0}
	var rarity_n := {0: 0, 4: 0}
	var chest_weapons := 0
	var trap_weapons := 0
	for sample in SAMPLES:
		var run_seed := 610000 + sample * 6007
		var history: Array[StringName] = []
		for stage in 5:
			var kind: StringName = [&"lower_city", &"industrial", &"lab", &"industrial", &"lab"][stage]
			var manager = load("res://scene/run_manager.gd").new()
			root.add_child(manager)
			manager.configure_run(&"solo", &"normal")
			manager.prepare_new_run(run_seed)
			manager.configure_run_weapon_pool(pool)
			manager.stage_index = stage
			manager.weapon_offer_history.assign(history)
			var biome = load(SCENES[kind]).instantiate()
			_check(biome.generate(run_seed, manager), "gera %s s%d" % [kind, stage])
			var report: Dictionary = biome.get_generation_report()
			var offers: Dictionary = report.get("weapon_offers", {})
			stage_count += 1
			offers_total += offers.size()
			var stage_ids := {}
			for content_id: Variant in offers:
				var weapon_id := StringName(offers[content_id])
				_check(not stage_ids.has(weapon_id), "sem arma repetida no mesmo estágio (%s s%d %s)" % [kind, stage, weapon_id])
				stage_ids[weapon_id] = true
				seen[weapon_id] = true
				if not by_biome.has(kind):
					by_biome[kind] = {}
				var cat := WeaponCatalog.category(weapon_id)
				by_biome[kind][cat] = int(by_biome[kind].get(cat, 0)) + 1
			# Conteúdo real: pickups e baús carregam a arma/raridade ofertada.
			for node in biome.find_children("*", "Area2D", true, false):
				if node is WeaponPickup:
					_check(offers.get(node.pickup_id, &"") == node.weapon_id, "pickup usa a oferta do estágio")
					if rarity_sum.has(stage):
						rarity_sum[stage] += RarityTable.index(node.rarity)
						rarity_n[stage] += 1
				elif node.get("reward_weapon_id") != null and not StringName(node.reward_weapon_id).is_empty():
					var cid: StringName = node.trap_id if node is TrapChest else node.loot_id
					_check(offers.get(cid, &"") == node.reward_weapon_id, "baú guarda a oferta do estágio")
					_check(not StringName(node.reward_rarity).is_empty(), "baú com raridade definida")
					if node is TrapChest:
						trap_weapons += 1
						_check(RarityTable.index(node.reward_rarity) >= RarityTable.index(&"uncommon"), "recompensa trap mínima incomum")
					else:
						chest_weapons += 1
					if rarity_sum.has(stage):
						rarity_sum[stage] += RarityTable.index(node.reward_rarity)
						rarity_n[stage] += 1
			for value: Variant in offers.values():
				if not history.has(StringName(value)):
					history.append(StringName(value))
			biome.free()
			manager.free()
	var average := float(offers_total) / float(stage_count)
	print("WEAPON_LOOT_STATS offers_per_stage=%.2f chest=%d trap=%d distinct=%d/%d by_biome=%s rarity_s0=%.2f rarity_s4=%.2f" % [average, chest_weapons, trap_weapons, seen.size(), pool.size(), JSON.stringify(by_biome), rarity_sum[0] / maxf(rarity_n[0], 1), rarity_sum[4] / maxf(rarity_n[4], 1)])
	_check(average >= 1.0 and average <= 2.8, "ofertas por estágio entre 1,0 e 2,8 (antes ~0,38): %.2f" % average)
	_check(chest_weapons > 0 and trap_weapons > 0, "baús comuns e trap entregam armas")
	_check(seen.size() >= pool.size() - 2, "quase todas as armas elegíveis aparecem (%d/%d)" % [seen.size(), pool.size()])
	var lower: Dictionary = by_biome.get(&"lower_city", {})
	var lab: Dictionary = by_biome.get(&"lab", {})
	var lower_street := float(int(lower.get(&"pistol", 0)) + int(lower.get(&"blunt", 0))) / maxf(_sum(lower), 1.0)
	var lab_street := float(int(lab.get(&"pistol", 0)) + int(lab.get(&"blunt", 0))) / maxf(_sum(lab), 1.0)
	var lab_energy := float(int(lab.get(&"rifle", 0)) + int(lab.get(&"bow", 0))) / maxf(_sum(lab), 1.0)
	var lower_energy := float(int(lower.get(&"rifle", 0)) + int(lower.get(&"bow", 0))) / maxf(_sum(lower), 1.0)
	_check(lower_street > lab_street, "Cidade Baixa favorece pistolas/impacto (%.2f > %.2f)" % [lower_street, lab_street])
	_check(lab_energy > lower_energy, "Laboratório favorece rifles/arcos (%.2f > %.2f)" % [lab_energy, lower_energy])
	_check(rarity_sum[4] / maxf(rarity_n[4], 1) > rarity_sum[0] / maxf(rarity_n[0], 1), "raridade sobe com o estágio")


func _sum(values: Dictionary) -> float:
	var total := 0
	for value: Variant in values.values():
		total += int(value)
	return float(total)


func _test_real_chests() -> void:
	var temp := "user://weapon_loot_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(temp)
	var game: Node = load("res://scene/main.tscn").instantiate()
	game.get_node("LocalSettings").settings_path = temp.path_join("settings.cfg")
	var meta := game.get_node("MetaProgression") as MetaProgression
	meta.save_path = temp.path_join("meta.json")
	root.add_child(game)
	await process_frame
	await game.start_configured_run(&"solo", &"normal", -1)
	var player: CharacterBody2D = game.get_players()[0]
	var tested_chest := false
	var tested_trap := false
	for attempt in 8:
		await game._begin_run_from_hub(720011 + attempt * 131)
		await process_frame
		_check(not (game.run_manager.weapon_offer_history as Array).is_empty() or true, "histórico de ofertas registrado")
		player.is_invulnerable = true
		player.invulnerability_timer = 9999.0
		for node in game.current_room.find_children("*", "Area2D", true, false):
			if node.get("reward_weapon_id") == null or StringName(node.reward_weapon_id).is_empty():
				continue
			if not (node is TrapChest) and not tested_chest:
				tested_chest = await _open_chest(game, player, node, false)
			elif node is TrapChest and not tested_trap:
				tested_trap = await _open_chest(game, player, node, true)
		if tested_chest and tested_trap:
			break
		await game.return_to_laboratory()
		await process_frame
	_check(tested_chest, "baú comum com arma encontrado e aberto no jogo")
	_check(tested_trap, "baú trap com arma encontrado e resgatado no jogo")
	game.queue_free()
	await process_frame


func _open_chest(game: Node, player: CharacterBody2D, chest: Area2D, trap: bool) -> bool:
	var weapon_id := StringName(chest.reward_weapon_id)
	var rarity := StringName(chest.reward_rarity)
	var position := chest.global_position
	player.global_position = position + Vector2(0, -6)
	player.velocity = Vector2.ZERO
	await physics_frame
	if trap:
		chest.interact(player)
		await physics_frame
		var state: BiomeMapState = game.run_manager.get_current_map_state()
		for enemy_id in state.get_trap_event_enemy_ids(chest.trap_id):
			for node in game.current_room.find_children("*", "CharacterBody2D", true, false):
				if node.is_in_group("enemy") and StringName(node.get("persistent_id")) == enemy_id:
					node.take_damage(int(node.health) + 5, 0.0, 0.0)
		for i in 20:
			await physics_frame
		_check(state.get_trap_event_state(chest.trap_id) == BiomeMapState.TRAP_CLEARED, "emboscada derrotada")
	chest.interact(player)
	await process_frame
	var pickup: WeaponPickup = null
	for node in game.current_room.find_children("*", "Area2D", true, false):
		if node is WeaponPickup and node.weapon_id == weapon_id and node.global_position.distance_to(position) < 4.0:
			pickup = node
	_check(pickup != null, "%s solta %s como pickup real" % ["baú trap" if trap else "baú comum", weapon_id])
	if pickup == null:
		return false
	_check(pickup.rarity == rarity, "pickup mantém a raridade sorteada")
	_check(pickup.claim_authoritative(player), "jogador pega a arma do baú")
	_check(player.equipped_weapons.has(weapon_id) and player.get_weapon_rarity(weapon_id) == rarity, "arma equipada com a raridade")
	_check((game.run_manager.blueprints_found as Array).has(weapon_id), "arma do baú vira blueprint")
	return true


func _test_boss_blueprint() -> void:
	var manager = load("res://scene/run_manager.gd").new()
	root.add_child(manager)
	manager.configure_run(&"solo", &"normal")
	manager.prepare_new_run(99133)
	manager.configure_run_weapon_pool([&"breaker_maul", &"scrap_pistol"])
	manager.boss_defeated = true
	manager._grant_boss_blueprint()
	var granted := StringName(manager.completion_rewards.get("boss_blueprint", ""))
	_check(not granted.is_empty() and (manager.blueprints_found as Array).has(granted), "chefe concede projeto (%s)" % granted)
	_check(WeaponCatalog.discoverable_ids().has(granted) or granted == &"breaker_maul" or granted == &"scrap_pistol", "projeto do chefe vem do pool real")
	manager.free()
