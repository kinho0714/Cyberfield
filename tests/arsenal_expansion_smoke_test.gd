extends SceneTree
## Expansão do arsenal (01/11/2026) — teste no JOGO REAL: main.tscn → Casa do Jhon (terminal)
## → run no bioma gerado → combate com armas/cyberwares/acessórios → morte → laboratório.
## Headless: só asserções. Com display (xvfb) e argumento <out_dir>, salva capturas.
##   godot --headless --path . --script res://tests/arsenal_expansion_smoke_test.gd
##   xvfb-run godot --path . --script res://tests/arsenal_expansion_smoke_test.gd -- <out_dir>

var game: Node
var out_dir := ""
var player: CharacterBody2D
var meta: MetaProgression
var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ARSENAL_CHECK_FAIL " + message)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
		root.size = Vector2i(1560, 720)
	var temp := "user://arsenal_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(temp)
	game = load("res://scene/main.tscn").instantiate()
	game.get_node("LocalSettings").settings_path = temp.path_join("settings.cfg")
	meta = game.get_node("MetaProgression") as MetaProgression
	meta.save_path = temp.path_join("meta.json")
	root.add_child(game)
	await process_frame
	meta.load_profile()
	_test_catalogs()
	await game.start_configured_run(&"solo", &"normal", -1)
	player = game.get_players()[0]
	_check(game.current_is_hub, "hub carregado")
	_check(InputMap.has_action(&"gadget_1") and InputMap.has_action(&"gadget_2"), "ações gadget_1/2 registradas")
	await _test_laboratory_flow()
	await _test_run_flow()
	await _test_death_and_return()
	print("ARSENAL_REPORT failures=%d %s" % [failures.size(), JSON.stringify(failures)])
	if failures.is_empty():
		print("ARSENAL_EXPANSION_SMOKE_TEST_OK")
	quit(0 if failures.is_empty() else 1)


func _test_catalogs() -> void:
	_check(WeaponCatalog.WEAPONS.size() >= 10, "pelo menos 10 armas")
	var categories := {}
	for id: StringName in WeaponCatalog.WEAPONS:
		categories[WeaponCatalog.category(id)] = true
		_check(WeaponCatalog.get_visual_texture(id, "world") != null, "sprite de %s" % id)
	for category: StringName in [&"blade", &"blunt", &"pistol", &"semi_auto", &"shotgun", &"rifle", &"bow"]:
		_check(categories.has(category), "categoria %s presente" % category)
	var common := WeaponCatalog.stats_for(&"corp_pistol", &"common")
	var rare := WeaponCatalog.stats_for(&"corp_pistol", &"rare")
	_check(int(rare.damage) > int(common.damage) and float(rare.cooldown) < float(common.cooldown) and int(rare.magazine) > int(common.magazine), "raridade altera atributos reais")
	_check(RarityTable.TIERS.has(&"epic") and not RarityTable.enabled_tiers().has(&"epic"), "tiers superiores preparados e desligados")
	for line: StringName in CyberwareCatalog.LINE_ORDER:
		_check(CyberwareCatalog.icon(line) != null, "ícone cyberware %s" % line)
	var mk1 := CyberwareCatalog.make_instance(&"speed", &"common", 1)
	var mk3 := CyberwareCatalog.make_instance(&"speed", &"common", 3)
	var rare1 := CyberwareCatalog.make_instance(&"speed", &"rare", 1)
	_check(float(CyberwareCatalog.effects(mk3).move_speed) > float(CyberwareCatalog.effects(rare1).move_speed) and float(CyberwareCatalog.effects(rare1).move_speed) > float(CyberwareCatalog.effects(mk1).move_speed), "nível e raridade separados e efetivos")
	for id: StringName in AccessoryCatalog.ORDER:
		_check(AccessoryCatalog.icon(id) != null, "ícone acessório %s" % id)


func _press(name: String) -> bool:
	var lab := game.get_node("MetaLabUI")
	var button := lab.equipment_root.find_child(name.validate_node_name(), true, false) as Button
	if button == null or button.disabled:
		_check(false, "botão do terminal %s disponível" % name)
		return false
	button.pressed.emit()
	return true


func _test_laboratory_flow() -> void:
	# Run anterior (derrota): blueprint da escopeta chega ao terminal; cyberware vira sucata.
	meta.scrap = 600
	var lost := CyberwareCatalog.make_instance(&"strength", &"uncommon", 1, "cw_test_lost")
	var scrap_before := meta.scrap
	meta.record_run({"run_id": "arsenal-test-loss", "completed": false, "blueprints_found": [&"scrap_shotgun", &"pulse_rifle"], "cyberwares_found": [lost]})
	_check(meta.recovered_models.has(&"scrap_shotgun") and meta.recovered_models.has(&"pulse_rifle"), "blueprint recuperado mesmo em derrota")
	_check(meta.scrap == scrap_before + CyberwareCatalog.salvage_value(lost) and meta.find_cyberware("cw_test_lost").is_empty(), "cyberware perdido vira sucata")
	var lab := game.get_node("MetaLabUI")
	lab.open_terminal(player)
	await process_frame
	_check(lab.overlay.visible, "terminal abre na Casa")
	lab._study_blueprint(&"scrap_shotgun")
	lab._study_blueprint(&"pulse_rifle")
	await process_frame
	_check(meta.blueprints.has(&"scrap_shotgun"), "blueprint estudado no terminal")
	_press("CycleRarity") # incomum
	await process_frame
	_press("CycleRarity") # raro
	await process_frame
	_check(lab.craft_rarity == &"rare", "seletor de raridade")
	_press("Fab_scrap_shotgun")
	await process_frame
	_check(meta.armory_rarity(&"scrap_shotgun") == &"rare", "escopeta rara fabricada")
	_press("Fab_pulse_rifle")
	await process_frame
	_press("Slot0_scrap_shotgun")
	await process_frame
	_press("Slot1_pulse_rifle")
	await process_frame
	_check(meta.loadout_weapons == [&"scrap_shotgun", &"pulse_rifle"], "loadout definido pelo terminal")
	_press("CycleRarity") # comum
	await process_frame
	for line in ["physical", "dash", "health", "intellect"]:
		_press("CyFab_%s" % line)
		await process_frame
	_check(meta.installed_cyberwares.size() == 4, "quatro implantes instalados nos slots")
	var health_uid := String(meta.installed_cyberwares[&"torso"])
	_press("CyUp_%s" % health_uid)
	await process_frame
	_check(int(meta.find_cyberware(health_uid).level) == 2, "implante melhorado para MK2")
	for id in ["ice_grenade", "fire_grenade", "portable_turret"]:
		_press("AcFab_%s" % id)
		await process_frame
	_press("AcSlot1_portable_turret")
	await process_frame
	_check(meta.equipped_accessories == [&"ice_grenade", &"portable_turret"], "dois acessórios diferentes equipados")
	await _capture("lab_bench")
	lab.close_terminal()
	await process_frame
	# Persistência: um perfil novo lendo o mesmo arquivo vê tudo.
	var reloaded := MetaProgression.new()
	reloaded.save_path = meta.save_path
	root.add_child(reloaded)
	_check(reloaded.armory_rarity(&"scrap_shotgun") == &"rare" and reloaded.loadout_weapons == meta.loadout_weapons, "arsenal salvo")
	_check(reloaded.cyberwares.size() == meta.cyberwares.size() and reloaded.installed_cyberwares.size() == 4, "cyberwares salvos")
	_check(reloaded.equipped_accessories == meta.equipped_accessories, "acessórios salvos")
	reloaded.queue_free()
	# O jogador no hub já carrega o equipamento.
	_check(player.equipped_weapons == [&"scrap_shotgun", &"pulse_rifle"] and player.get_weapon_rarity(&"scrap_shotgun") == &"rare", "loadout aplicado no hub")
	_check(player.max_health > CombatStats.PLAYER_BASE_MAX_HP, "biomonitor aumenta vida máxima")
	_check(player.gadgets.slots == [&"ice_grenade", &"portable_turret"], "slots ativos configurados")


func _enemies() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node in game.current_room.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group("enemy") and EnemyStatus.is_alive(node):
			result.append(node)
	return result


## Lado com chão firme a dx px (evita jogar inimigos em poços do bioma).
func _ground_side(dx: float) -> float:
	var space := player.get_world_2d().direct_space_state
	for side in [1.0, -1.0]:
		var ok := true
		for step in range(20, int(dx) + 40, 20):
			var from := player.global_position + Vector2(side * step, -30)
			var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 70), 1, [player.get_rid()])
			var hit := space.intersect_ray(query)
			if hit.is_empty() or (hit.collider as Node).is_in_group("enemy"):
				ok = false
				break
		if ok:
			return side
	return 1.0


## Alvo parado: sem física (não anda, não cai, não ataca); dano e estados funcionam.
func _park(enemy: Node2D, offset: Vector2) -> void:
	enemy.set_physics_process(false)
	enemy.global_position = player.global_position + offset
	enemy.set("network_target_position", enemy.global_position)
	enemy.set("is_hurt", false) # RangedEnemy só limpa isso na própria física.
	enemy.velocity = Vector2.ZERO
	enemy.set("health", 5000)
	enemy.set("max_health", 5000)


func _test_run_flow() -> void:
	await game._begin_run_from_hub(77123)
	await process_frame
	_check(game.run_manager.run_active and not game.current_is_hub, "run iniciada")
	_check(player.equipped_weapons == [&"scrap_shotgun", &"pulse_rifle"], "loadout aplicado na run nova")
	_check(player.cyberware_instances.size() == 4 and player.get_move_speed() == player.SPEED, "cyberwares da run (sem velocidade)")
	_check(player.gadgets.charges[0] == 2 and player.gadgets.charges[1] == 1, "cargas cheias no início")
	player.is_invulnerable = true
	player.invulnerability_timer = 999.0
	var enemies := _enemies()
	_check(enemies.size() >= 3, "bioma tem inimigos para o teste (%d)" % enemies.size())
	if enemies.size() < 3:
		return
	for enemy in enemies:
		_park(enemy, Vector2(0, -900) + Vector2(enemies.find(enemy) * 60, 0))
	game.gameplay_camera.global_position = player.global_position
	# --- escopeta: chumbos somados num alvo ---
	var target := enemies[0]
	_park(target, Vector2(70, 0))
	player.anim.flip_h = false
	await create_timer(0.05).timeout
	player.attack(0)
	await create_timer(0.05).timeout
	var pellet: int = player.get_ranged_damage(&"scrap_shotgun")
	var dealt := 5000 - int(target.get("health"))
	_check(dealt > pellet, "escopeta soma chumbos (%d > %d)" % [dealt, pellet])
	await _capture("run_shotgun")
	enemies = _enemies()
	if enemies.size() < 3:
		_check(false, "inimigos suficientes")
		return
	# --- rifle de pulso: perfura dois alvos ---
	await create_timer(0.3).timeout
	_park(enemies[0], Vector2(90, 0))
	_park(enemies[1], Vector2(150, 0))
	player.switch_weapon()
	player.weapon_cooldowns.fill(0.0)
	player.attack(1)
	await create_timer(0.4).timeout
	_check(int(enemies[0].get("health")) < 5000 and int(enemies[1].get("health")) < 5000, "rifle de pulso atravessa alvos")
	# --- arco: projétil com parábola (arma achada na run com raridade) ---
	_check(player.equip_weapon(&"neon_longbow", 1, &"uncommon"), "pickup equipa arco")
	player.weapon_cooldowns.fill(0.0)
	player.attack(1)
	await process_frame
	var arrow: Node2D = null
	for node in player.get_parent().get_children():
		if node.get("player_visual_id") == &"neon_arrow":
			arrow = node
	_check(arrow != null and float(arrow.get("gravity_accel")) > 0.0, "flecha usa gravidade")
	if arrow != null:
		var y0 := arrow.global_position.y
		await create_timer(0.25).timeout
		if is_instance_valid(arrow):
			_check(arrow.global_position.y > y0, "flecha cai em arco")
	await _capture("run_bow")
	enemies = _enemies()
	if enemies.size() < 3:
		_check(false, "inimigos suficientes")
		return
	# --- corpo a corpo de impacto: bastão varre dois alvos ---
	_check(player.equip_weapon(&"baseball_bat", 0, &"common"), "bastão equipado")
	player.active_weapon_slot = 0
	player.weapon_cooldowns.fill(0.0)
	await create_timer(0.15).timeout
	_park(enemies[0], Vector2(18, 0))
	_park(enemies[1], Vector2(20, 0))
	player.combo_end_recovery_timer = 0.0
	player.attack(0)
	await create_timer(0.2).timeout
	_check(int(enemies[0].get("health")) < 5000 and int(enemies[1].get("health")) < 5000, "bastão acerta mais de um alvo")
	_check(player.get_melee_damage(0) > roundi(48 * 1.0), "servo-impacto aumenta dano físico")
	await _capture("run_bat")
	# --- dash com propulsor ---
	await create_timer(0.3).timeout
	player._start_dash()
	_check(player.dash_timer > player.DASH_DURATION, "propulsor alonga o dash")
	await create_timer(0.3).timeout
	enemies = _enemies()
	if enemies.size() < 3:
		_check(false, "inimigos suficientes")
		return
	# --- granada de gelo pelo INPUT real (F) ---
	var frozen_enemy := enemies[2]
	var side := 1.0
	player.anim.flip_h = false
	_park(frozen_enemy, Vector2(200 * side, 0))
	var base_speed := float(frozen_enemy.get("move_speed"))
	Input.action_press(&"gadget_1")
	await physics_frame
	await physics_frame
	await physics_frame
	Input.action_release(&"gadget_1")
	_check(player.gadgets.charges[0] == 1, "tecla do slot 1 usa a granada")
	_guide_grenade(frozen_enemy)
	var frozen := false
	for i in 90:
		await process_frame
		var status := frozen_enemy.get_node_or_null("EnemyStatus") as EnemyStatus
		if status != null and status.is_frozen():
			frozen = true
			await physics_frame
			await physics_frame
			break
	_check(frozen, "granada de gelo congela")
	if frozen:
		_check(float(frozen_enemy.get("move_speed")) < base_speed * 0.1, "congelado quase para")
		await _capture("run_ice")
	enemies = _enemies()
	if enemies.size() < 3:
		_check(false, "inimigos suficientes")
		return
	# --- granada de fogo (troca o slot 1 em tempo de teste) ---
	player.gadgets.configure([&"fire_grenade", &"portable_turret"])
	var burn_target := enemies[1]
	_park(burn_target, Vector2(210 * side, 0))
	await create_timer(0.1).timeout
	player.gadgets.use(0)
	await process_frame
	_guide_grenade(burn_target)
	var burning := false
	for i in 90:
		await process_frame
		var status := burn_target.get_node_or_null("EnemyStatus") as EnemyStatus
		if status != null and status.burn_timer > 0.0:
			burning = true
			break
	_check(burning, "granada de fogo incendeia")
	await _capture("run_fire")
	if is_instance_valid(burn_target):
		var after_blast := int(burn_target.get("health"))
		await create_timer(1.1).timeout
		_check(is_instance_valid(burn_target) and int(burn_target.get("health")) < after_blast, "queimadura causa dano contínuo")
	enemies = _enemies()
	if enemies.size() < 3:
		_check(false, "inimigos suficientes")
		return
	# --- torreta portátil ---
	var turret_target := enemies[0]
	_park(turret_target, Vector2(150 * side, -4))
	player.gadgets.use(1)
	await process_frame
	_check(not root.get_tree().get_nodes_in_group("portable_turret").is_empty(), "torreta colocada")
	var before_turret := int(turret_target.get("health"))
	await create_timer(1.6).timeout
	await _capture("run_turret")
	_check(is_instance_valid(turret_target) and int(turret_target.get("health")) < before_turret, "torreta ataca sozinha")
	# --- estado restaurado após o gelo ---
	await create_timer(3.0).timeout
	_check(not is_instance_valid(frozen_enemy) or is_equal_approx(float(frozen_enemy.get("move_speed")), base_speed) or not EnemyStatus.is_alive(frozen_enemy), "velocidade do inimigo restaurada após o gelo")
	# --- cyberware dropado pelo chefe e instalado na run ---
	var run_manager: Node = game.run_manager
	run_manager.handle_enemy_drop(run_manager.get_current_room_id(), &"arsenal_test_boss", 1, player.global_position + Vector2(40, 0), null)
	await process_frame
	var pickups := root.get_tree().get_nodes_in_group("cyberware_pickup")
	_check(not pickups.is_empty(), "chefe derruba cyberware")
	if not pickups.is_empty():
		(pickups[0] as Node2D).global_position = player.global_position
		await process_frame
		await _capture("run_cyber_pickup")
		pickups[0].interact(player)
		_check((run_manager.cyberwares_found as Array).size() == 1, "cyberware achado registrado na run")
	# --- pickup de arma com raridade sorteada ---
	var pickup := WeaponPickup.new()
	pickup.pickup_id = &"stage_03_weapon_01"
	pickup.weapon_id = &"corp_pistol"
	game.current_room.add_child(pickup)
	pickup.global_position = player.global_position
	await process_frame
	_check(not pickup.rarity.is_empty(), "pickup tem raridade")
	_check(pickup.claim_authoritative(player), "pickup coletado")
	_check((run_manager.blueprints_found as Array).has(&"corp_pistol"), "blueprint da arma achada registrado")
	# --- cura mais eficiente ---
	player.is_invulnerable = false
	player.invulnerability_timer = 0.0
	player.dash_invulnerability_timer = 0.0
	player.health = 200
	player.is_healing = false
	player._start_heal()
	await create_timer(player.heal_duration + 0.1).timeout
	_check(player.health - 200 > CombatStats.heal_amount(player.max_health), "biomonitor melhora poção (%d)" % (player.health - 200))
	await _capture("run_hud")
	var hud := game.get_node("RunDebugHUD").loadout_hud as Control
	_check(hud != null and hud.visible, "HUD de equipamento visível na run")
	var touch := game.get_node("TouchControls")
	_check(touch.gadget_buttons.size() == 2, "botões touch dos slots ativos")


## Leva a granada recém-lançada até o alvo (o arremesso real tem alcance ~250 px).
func _guide_grenade(target: Node2D) -> void:
	for node in root.get_tree().get_nodes_in_group("player_gadget"):
		if node is ThrownGrenade and not node.get("_exploded"):
			(node as Node2D).global_position = target.global_position + Vector2(0, -30)


func _test_death_and_return() -> void:
	game.run_manager.lose_run()
	await process_frame
	await game.return_to_laboratory()
	await create_timer(0.3).timeout
	_check(game.current_is_hub, "volta ao laboratório após a morte")
	_check(meta.recovered_models.has(&"corp_pistol") or meta.blueprints.has(&"corp_pistol"), "blueprint da run chega ao terminal")
	_check(player.equipped_weapons == [&"scrap_shotgun", &"pulse_rifle"] and not player.owned_weapons.has(&"neon_longbow"), "run nova começa só com o loadout")
	_check(player.cyberware_instances.size() == 4, "implantes temporários da run descartados")
	var result_ui := game.get_node("RunResultUI")
	if result_ui.has_method("close") and result_ui.get("overlay") != null:
		await _capture("hub_result")


func _capture(label: String) -> void:
	if out_dir.is_empty():
		return
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
