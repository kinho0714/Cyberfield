extends SceneTree
## P0-B (02/11/2026) — Modo Dev no JOGO REAL (main.tscn → Casa → run).
## Ativação pelas Configurações (toque), botão DEV no HUD (toque), painel por abas,
## ferramentas reais de jogador/arsenal/inimigos/mundo e ISOLAMENTO do save legítimo.
##   godot --headless --path . --script res://tests/dev_mode_smoke_test.gd
##   xvfb-run godot --path . --script res://tests/dev_mode_smoke_test.gd -- <out_dir>

var game: Node
var meta: MetaProgression
var settings: LocalSettings
var dev: DevMode
var panel: CanvasLayer
var player: CharacterBody2D
var out_dir := ""
var failures: PackedStringArray = []
var _touch := 20


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("DEV_MODE_FAIL " + message)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1600, 720)
	var temp := "user://dev_mode_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(temp)
	game = load("res://scene/main.tscn").instantiate()
	settings = game.get_node("LocalSettings") as LocalSettings
	settings.settings_path = temp.path_join("settings.cfg")
	meta = game.get_node("MetaProgression") as MetaProgression
	meta.save_path = temp.path_join("meta.json")
	root.add_child(game)
	await process_frame
	settings.load_settings()
	meta.load_profile()
	meta.credits = 321
	meta.scrap = 45
	meta.save_profile()
	var legit_before := FileAccess.get_file_as_string(meta.save_path)
	await game.start_configured_run(&"solo", &"normal", -1)
	player = game.get_players()[0]
	dev = game.get_node("DevMode") as DevMode
	panel = dev.panel
	await _test_activation()
	await _test_player_tools(legit_before)
	await _test_arsenal_tools(legit_before)
	await _test_world_and_enemies()
	await _test_isolation_end(legit_before)
	print("DEV_MODE_REPORT failures=%d %s" % [failures.size(), JSON.stringify(failures)])
	if failures.is_empty():
		print("DEV_MODE_SMOKE_TEST_OK")
	quit(0 if failures.is_empty() else 1)


func _test_activation() -> void:
	_check(not settings.dev_mode_enabled, "Modo Dev desligado por padrão")
	await process_frame
	_check(not panel.hud_button.visible, "sem botão DEV com o modo desligado")
	_key(KEY_F9)
	await process_frame
	_check(not panel.is_open(), "F9 não abre com o modo desligado")
	# Configurações reais: pausa → OPÇÕES → aba JOGO → toque no "MODO DEV".
	var pause := game.get_node("PauseMenu")
	pause.open_menu()
	await process_frame
	pause._show_settings()
	await process_frame
	await process_frame
	var toggle: CheckButton = pause.dev_mode_toggle
	_check(toggle != null and toggle.is_visible_in_tree(), "opção MODO DEV visível na aba JOGO")
	if toggle != null:
		pause.settings_scroll.ensure_control_visible(toggle)
		await process_frame
		await _tap(toggle.get_global_rect().get_center())
	_check(settings.dev_mode_enabled, "toque na opção liga o Modo Dev")
	var saved := ConfigFile.new()
	saved.load(settings.settings_path)
	_check(bool(saved.get_value("debug", "dev_mode", false)), "opção salva nas configurações locais")
	await _capture("dev_settings_toggle")
	pause.close_menu()
	await process_frame
	await process_frame
	_check(panel.hud_button.visible, "botão DEV aparece no HUD da Casa")
	_check(not meta.dev_sandbox_active, "ligar o modo não troca o perfil sozinho")
	await _capture("dev_hud_button")
	await _tap(panel.hud_button.get_global_rect().get_center())
	_check(panel.is_open(), "toque no botão DEV abre o painel")
	_check(paused, "jogo pausado com o painel aberto")
	_check(not bool(player.input_enabled), "jogador parado com o painel aberto")
	_check(bool(game.get_node("TouchControls").menu_blocked), "controles de toque bloqueados")
	await _capture("dev_panel_player")
	await _tap(panel.close_button.get_global_rect().get_center())
	_check(not panel.is_open() and not paused and bool(player.input_enabled), "FECHAR devolve o jogo")
	_key(KEY_F9)
	await process_frame
	_check(panel.is_open(), "F9 abre o painel no PC")
	_key(KEY_F9)
	await process_frame
	_check(not panel.is_open(), "F9 fecha o painel")


func _test_player_tools(legit_before: String) -> void:
	panel.open_panel()
	await process_frame
	panel.select_section(&"player")
	await process_frame
	var minus := panel.content.find_child("Dev_health_minus", true, false) as Button
	_check(minus != null, "botão VIDA -50 existe")
	var health_before := int(player.health)
	if minus != null:
		await _tap(minus.get_global_rect().get_center())
	_check(int(player.health) == maxi(health_before - 50, 1), "toque em -50 tira vida (%d → %d)" % [health_before, int(player.health)])
	_check(meta.dev_sandbox_active, "primeira ferramenta liga o perfil de teste")
	_check(meta.save_path.ends_with("_dev_sandbox.json"), "gravações vão para o arquivo de teste")
	dev.run_action(&"player", "heal_full")
	_check(int(player.health) == int(player.max_health), "curar tudo")
	dev.run_action(&"player", "toggle_invincible")
	panel.close_panel()
	var before := int(player.health)
	player.take_damage(40, 1.0)
	player.enter_downed()
	_check(int(player.health) == before and not bool(player.is_downed), "invencível ignora dano e queda")
	panel.open_panel()
	dev.run_action(&"player", "toggle_invincible")
	_check(not bool(player.dev_invincible), "invencibilidade desliga")
	dev.run_action(&"player", "credits_plus")
	dev.run_action(&"player", "scrap_plus")
	_check(meta.credits == 421 and meta.scrap == 95, "créditos/sucata no perfil de teste (%d/%d)" % [meta.credits, meta.scrap])
	_check(FileAccess.get_file_as_string(meta.legit_save_path()) == legit_before, "perfil legítimo intacto no disco")
	panel.close_panel()


func _test_arsenal_tools(legit_before: String) -> void:
	panel.open_panel()
	panel.select_section(&"arsenal")
	await process_frame
	dev.run_action(&"arsenal", "cycle_rarity")
	dev.run_action(&"arsenal", "cycle_rarity")
	_check(dev.weapon_rarity == &"rare", "seletor de raridade")
	var equip := panel.content.find_child("Dev_equip0_gauss_rifle", true, false) as Button
	_check(equip != null, "lista de armas inclui as armas novas")
	if equip != null:
		panel.scroll.ensure_control_visible(equip)
		await process_frame
		await _tap(equip.get_global_rect().get_center())
	_check(player.equipped_weapons[0] == &"gauss_rifle" and player.get_weapon_rarity(&"gauss_rifle") == &"rare", "toque equipa RIFLE GAUSS raro no S1")
	dev.run_action(&"arsenal", "equip1_hydraulic_hammer")
	_check(player.equipped_weapons[1] == &"hydraulic_hammer", "S2 com marreta")
	dev.run_action(&"arsenal", "cyber_physical_3")
	_check(not player.get_cyberware_in_slot(&"arms").is_empty() and int(player.get_cyberware_in_slot(&"arms").level) == 3, "implante MK3 instalado na run")
	dev.run_action(&"arsenal", "gadget1_fire_grenade")
	_check(player.gadgets.slots[1] == &"fire_grenade", "acessório no A2")
	dev.run_action(&"arsenal", "grant_all_blueprints")
	_check(meta.blueprints.size() == WeaponCatalog.WEAPONS.size(), "todos os blueprints no perfil de teste")
	_check(FileAccess.get_file_as_string(meta.legit_save_path()) == legit_before, "perfil legítimo continua intacto")
	await _capture("dev_panel_arsenal")
	panel.close_panel()


func _test_world_and_enemies() -> void:
	# Bioma escolhido direto da Casa (inicia a run, salta para o Industrial).
	await dev.load_stage(1)
	await process_frame
	_check(bool(game.run_manager.run_active) and game.run_manager.current_biome_kind == &"industrial", "MUNDO → INDUSTRIAL carrega o bioma real (%s)" % game.run_manager.current_biome_kind)
	_check(bool(game.run_manager.dev_session), "run marcada como sessão de teste")
	player.dev_invincible = true
	for i in 40:
		await physics_frame
	var points := dev.teleport_points()
	_check(points.size() >= 4, "pontos de teleporte válidos (%d)" % points.size())
	for point: Dictionary in points:
		if String(point.label).begins_with("SAÍDA"):
			dev.teleport_to(point.position)
			await physics_frame
			_check(player.global_position.distance_to(point.position) < 40.0, "teleporte até a saída")
			break
	if not points.is_empty():
		dev.teleport_to(points[0].position)
	for i in 30:
		await physics_frame
	# Inimigos reais em pontos seguros, sem dano de spawn.
	var spawned := dev.spawn_enemies(&"common", 3)
	_check(spawned.size() == 3, "gera 3 inimigos corpo a corpo (%d)" % spawned.size())
	dev.enemy_role = &"elite"
	dev.enemy_biome = &"lab"
	spawned.append_array(dev.spawn_enemies(&"common", 1))
	dev.enemy_role = &"boss"
	spawned.append_array(dev.spawn_enemies(&"common", 1))
	dev.enemy_role = &"normal"
	spawned.append_array(dev.spawn_enemies(&"ranged", 1))
	spawned.append_array(dev.spawn_enemies(&"heavy", 1))
	for i in 90:
		await physics_frame
	var healthy := 0
	for enemy in spawned:
		if is_instance_valid(enemy) and int(enemy.health) == int(enemy.max_health) and int(enemy.health) > 0:
			healthy += 1
	_check(healthy == spawned.size(), "inimigos do Modo Dev vivos e sem dano de spawn (%d/%d)" % [healthy, spawned.size()])
	_check(spawned.size() >= 7 and spawned[3].is_elite() and spawned[4].is_boss() and spawned[6].is_heavy(), "variações elite/chefe/pesado aplicadas")
	_check(int(spawned[3].max_health) > int(spawned[0].max_health), "elite com vida escalada pela regra real")
	await _capture("dev_enemies")
	_check(dev.remove_spawned_enemies() == spawned.size(), "remover gerados remove só os do Modo Dev")
	await process_frame
	_check(get_nodes_in_group(DevMode.DEV_GROUP).filter(func(n: Node) -> bool: return n.is_in_group("enemy")).is_empty(), "nenhum inimigo do Modo Dev restante")
	# Baús e drops reais.
	var trap := dev.spawn_chest(true, true)
	_check(trap is TrapChest and (trap as TrapChest).event_spawn_positions.size() >= 2, "baú trap com emboscada em pontos seguros")
	if trap != null:
		_check(game.run_manager.get_current_map_state().get_trap_event_state(trap.trap_id) == BiomeMapState.TRAP_UNOPENED, "baú trap registrado no mapa")
	var chest := dev.spawn_chest(false, true)
	_check(chest != null and not StringName(chest.reward_weapon_id).is_empty(), "baú comum com arma da tabela")
	var distribution := dev.simulate_drops()
	var total := 0.0
	for value: Variant in distribution.values():
		total += float(value)
	_check(not distribution.is_empty() and absf(total - 1.0) < 0.01, "simulação da tabela de drops do bioma")
	_check(dev.defeat_nearest_enemy(), "derrotar inimigo pelo caminho de dano real")
	# Reiniciar sala: mesmo layout, inimigos de volta.
	var signature := String(game.current_room.get_generation_report().signature)
	await dev.restart_stage()
	await process_frame
	_check(String(game.current_room.get_generation_report().signature) == signature, "reiniciar sala mantém o layout")
	_check(int(game.run_manager.get_alive_enemy_count()) > 0, "reiniciar sala traz os inimigos de volta")
	panel.open_panel()
	panel.select_section(&"world")
	await process_frame
	await _capture("dev_panel_world")
	panel.close_panel()


func _test_isolation_end(legit_before: String) -> void:
	# Fim de run pelo caminho real (derrota) para gerar resultado e registrá-lo.
	player.dev_invincible = false
	game.run_manager.lose_run()
	await process_frame
	await game.return_to_laboratory()
	await process_frame
	var results: Dictionary = game.run_manager.last_run_results
	_check(bool(results.get("dev_session", false)), "resultado da run marcado como teste")
	_check(FileAccess.get_file_as_string(meta.legit_save_path()) == legit_before, "voltar da run de teste não grava o perfil legítimo")
	# Desligar o Modo Dev pelas configurações volta ao perfil real, intacto.
	settings.set_dev_mode_enabled(false)
	await process_frame
	_check(not meta.dev_sandbox_active and not meta.save_path.ends_with("_dev_sandbox.json"), "desligar volta ao perfil real")
	_check(meta.credits == 321 and meta.scrap == 45 and meta.blueprints.size() < WeaponCatalog.WEAPONS.size(), "perfil real sem nada do teste (◈%d ⚙%d)" % [meta.credits, meta.scrap])
	_check(FileAccess.get_file_as_string(meta.save_path) == legit_before, "arquivo legítimo idêntico ao de antes")
	_check(meta.record_run({"run_id": "x-dev", "dev_session": true, "money_earned": 500}) == 0 and meta.credits == 321, "perfil real recusa resultado de teste")
	await process_frame
	_check(not panel.hud_button.visible, "botão DEV some ao desligar")


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


func _tap(position: Vector2) -> void:
	_touch += 1
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = _touch
		event.position = root.get_final_transform() * position
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _capture(name: String) -> void:
	if out_dir.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(out_dir.path_join(name + ".png"))
