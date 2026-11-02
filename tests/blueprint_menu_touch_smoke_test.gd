extends SceneTree
## P0-A (02/11/2026) — terminal de blueprints no JOGO REAL, por toque (como no Android:
## `emulate_mouse_from_touch=false`), mouse e teclado. main.tscn → Casa → jogador no
## terminal → botão INTERAGIR → abas, rolagem por arrasto, toque ao soltar, recorte.
##   godot --headless --path . --script res://tests/blueprint_menu_touch_smoke_test.gd
##   xvfb-run godot --path . --script res://tests/blueprint_menu_touch_smoke_test.gd -- <out_dir>

var game: Node
var meta: MetaProgression
var lab: MetaLabUI
var player: CharacterBody2D
var out_dir := ""
var failures: PackedStringArray = []
var _touch_index := 3


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("BLUEPRINT_MENU_FAIL " + message)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	_check(not Input.emulate_mouse_from_touch, "projeto roda sem emulação de mouse por toque (como no Android)")
	var temp := "user://blueprint_menu_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(temp)
	game = load("res://scene/main.tscn").instantiate()
	game.get_node("LocalSettings").settings_path = temp.path_join("settings.cfg")
	meta = game.get_node("MetaProgression") as MetaProgression
	meta.save_path = temp.path_join("meta.json")
	root.add_child(game)
	await process_frame
	meta.load_profile()
	await game.start_configured_run(&"solo", &"normal", -1)
	player = game.get_players()[0]
	lab = game.get_node("MetaLabUI") as MetaLabUI
	# Perfil de quem voltou de várias runs: todos os projetos recuperados, dois já estudados.
	meta.scrap = 5000
	meta.credits = 400
	for weapon_id: StringName in WeaponCatalog.WEAPONS:
		if not meta.recovered_models.has(weapon_id):
			meta.recovered_models.append(weapon_id)
	await _open_with_interact_button()
	_check(lab.is_open(), "terminal abre pelo botão INTERAGIR na Casa")
	_check(lab.current_tab == MetaLabUI.TAB_PROJECTS, "abre na aba de blueprints")
	_check(lab.scroll.scroll_vertical == 0, "abre no topo (antes: foco no botão do fim rolava até os acessórios)")
	_check(bool(game.get_node("TouchControls").menu_blocked), "controles de toque bloqueados com o terminal aberto")
	_check(not bool(player.input_enabled), "jogador parado com o terminal aberto")
	for size: Vector2i in [Vector2i(1600, 720), Vector2i(1280, 720), Vector2i(960, 540)]:
		await _test_layout(size)
	root.size = Vector2i(1600, 720)
	await process_frame
	await _test_touch_flow()
	await _test_scroll_and_clip()
	await _test_tabs_and_close()
	await _test_mouse_and_keyboard()
	print("BLUEPRINT_MENU_REPORT failures=%d %s" % [failures.size(), JSON.stringify(failures)])
	if failures.is_empty():
		print("BLUEPRINT_MENU_TOUCH_SMOKE_TEST_OK")
	quit(0 if failures.is_empty() else 1)


func _open_with_interact_button() -> void:
	var terminal := game.current_room.find_child("MetaTerminal", true, false) as Area2D
	_check(terminal != null, "terminal existe na Casa")
	if terminal == null:
		return
	player.global_position = terminal.global_position
	player.velocity = Vector2.ZERO
	for i in 6:
		await physics_frame
		if terminal.overlaps_body(player):
			break
	_check(terminal.overlaps_body(player), "jogador alcança o terminal")
	# Botão INTERAGIR do HUD de toque usa a mesma ação.
	Input.action_press(&"interact")
	await physics_frame
	await physics_frame
	Input.action_release(&"interact")
	await process_frame
	if not lab.is_open():
		_check(false, "INTERAGIR abriu o terminal")
		lab.open_terminal(player)
		await process_frame


func _test_layout(size: Vector2i) -> void:
	root.size = size
	await process_frame
	await process_frame
	var view := root.get_visible_rect().size
	var frame_rect := lab.frame.get_global_rect()
	_check(Rect2(Vector2.ZERO, view).grow(1.0).encloses(frame_rect), "painel cabe na tela %s (painel %s, visível %s)" % [size, frame_rect, view])
	_check(lab.close_button.get_global_rect().size.y >= 50.0, "VOLTAR com alvo de toque ≥ 50 px em %s" % size)
	_check(lab.close_button.is_visible_in_tree() and not lab.scroll.is_ancestor_of(lab.close_button), "VOLTAR fixo fora da rolagem")
	var study := lab.blueprint_buttons.get(&"scrap_shotgun") as Button
	_check(study != null and study.get_global_rect().size.y >= 50.0, "ESTUDAR com alvo ≥ 50 px em %s" % size)
	_check(lab.scroll.get_global_rect().size.y >= 200.0, "área de rolagem útil em %s" % size)
	await _capture("lab_%dx%d" % [size.x, size.y])


func _test_touch_flow() -> void:
	# Soltar um dedo que começou antes do painel abrir não dispara nada.
	_raw_touch(Vector2(20, 20), false, 7)
	await process_frame
	var study := lab.blueprint_buttons.get(&"scrap_shotgun") as Button
	_check(study != null, "botão ESTUDAR da escopeta visível")
	if study == null:
		return
	var presses := [0]
	study.pressed.connect(func() -> void: presses[0] += 1)
	lab.scroll.ensure_control_visible(study)
	await process_frame
	await _tap(_center(study))
	_check(meta.blueprints.has(&"scrap_shotgun"), "toque em ESTUDAR estuda o blueprint")
	_check(presses[0] == 1, "um toque = uma ativação (sem disparo duplo) — %d" % presses[0])
	_check(FileAccess.file_exists(meta.save_path), "estudo salvo no perfil")
	await process_frame
	var fab := lab.equipment_root.find_child("Fab_scrap_shotgun", true, false) as Button
	_check(fab != null and not fab.disabled, "após estudar aparece FABRICAR")
	if fab != null:
		lab.scroll.ensure_control_visible(fab)
		await process_frame
		await _tap(_center(fab))
		_check(meta.armory.has(&"scrap_shotgun"), "toque em FABRICAR fabrica a arma")
	await process_frame
	var slot := lab.equipment_root.find_child("Slot1_scrap_shotgun", true, false) as Button
	_check(slot != null, "após fabricar aparecem S1/S2")
	if slot != null:
		lab.scroll.ensure_control_visible(slot)
		await process_frame
		await _tap(_center(slot))
		_check(meta.loadout_weapons[1] == &"scrap_shotgun", "toque em S2 equipa (alternância não se desfaz) — %s" % [meta.loadout_weapons])
	await process_frame
	var rarity := lab.equipment_root.find_child("CycleRarity", true, false) as Button
	if rarity != null:
		lab.scroll.ensure_control_visible(rarity)
		await process_frame
		await _tap(_center(rarity))
		_check(lab.craft_rarity == &"uncommon", "um toque avança uma raridade (antes o duplo disparo pulava)")
	await _capture("lab_after_touch")


func _test_scroll_and_clip() -> void:
	lab.scroll.scroll_vertical = 0
	await process_frame
	await process_frame
	var bar := lab.scroll.get_v_scroll_bar()
	_check(bar.max_value > lab.scroll.size.y + 40.0, "lista de blueprints maior que a tela (precisa rolar)")
	var studied_before := meta.blueprints.size()
	var crafted_before := meta.armory.size()
	var area := lab.scroll.get_global_rect()
	var start := Vector2(area.get_center().x, area.end.y - 30.0)
	await _drag(start, start - Vector2(0, 260))
	_check(lab.scroll.scroll_vertical > 150, "arrastar para cima rola a lista (%d)" % lab.scroll.scroll_vertical)
	_check(meta.blueprints.size() == studied_before and meta.armory.size() == crafted_before, "arrasto não aciona botões")
	var scrolled := lab.scroll.scroll_vertical
	await _drag(area.get_center(), area.get_center() + Vector2(0, 120))
	_check(lab.scroll.scroll_vertical < scrolled, "arrastar para baixo volta a lista")
	# Botão rolado para fora da área visível não pode ser acionado por toque fora do recorte.
	lab.scroll.scroll_vertical = 0
	await process_frame
	await process_frame
	var hidden: Button = null
	for weapon_id: StringName in lab.blueprint_buttons:
		var candidate := lab.blueprint_buttons[weapon_id] as Button
		if candidate.get_global_rect().position.y > area.end.y + 4.0 and candidate.get_global_rect().position.y < root.get_visible_rect().size.y:
			hidden = candidate
			break
	if hidden != null:
		var before := meta.blueprints.size()
		await _tap(_center(hidden))
		_check(meta.blueprints.size() == before, "toque fora do recorte não aciona botão escondido")
	else:
		_check(lab.touch_router.button_at(Vector2(area.get_center().x, area.end.y + 6.0)) == null, "nada acionável logo abaixo da área de rolagem")


func _test_tabs_and_close() -> void:
	for index in [MetaLabUI.TAB_CYBERWARE, MetaLabUI.TAB_ACCESSORIES, MetaLabUI.TAB_RESEARCH, MetaLabUI.TAB_PROJECTS]:
		await _tap(_center(lab.tab_buttons[index]))
		_check(lab.current_tab == index, "toque na aba %d troca a página" % index)
		await process_frame
		if index == MetaLabUI.TAB_CYBERWARE:
			var cy := lab.equipment_root.find_child("CyFab_physical", true, false) as Button
			_check(cy != null and cy.is_visible_in_tree(), "aba de implantes mostra a fabricação")
			if cy != null:
				await _tap(_center(cy))
				_check(meta.installed_cyberwares.size() >= 1, "toque fabrica e instala implante")
			await _capture("lab_tab_cyberware")
		elif index == MetaLabUI.TAB_ACCESSORIES:
			var ac := lab.equipment_root.find_child("AcFab_ice_grenade", true, false) as Button
			if ac != null:
				await _tap(_center(ac))
			_check(meta.owned_accessories.has(&"ice_grenade"), "toque fabrica acessório")
			await _capture("lab_tab_accessories")
		elif index == MetaLabUI.TAB_RESEARCH:
			var buy := lab.purchase_buttons[&"breaker_maul"] as Button
			_check(buy.is_visible_in_tree(), "aba de pesquisa mostra licenças")
			await _capture("lab_tab_research")
	await _tap(_center(lab.close_button))
	_check(not lab.is_open(), "toque em VOLTAR fecha")
	_check(bool(player.input_enabled), "jogador volta a se mover")
	_check(not bool(game.get_node("TouchControls").menu_blocked), "controles de toque liberados")


func _test_mouse_and_keyboard() -> void:
	lab.open_terminal(player)
	await process_frame
	await process_frame
	var tab := lab.tab_buttons[MetaLabUI.TAB_RESEARCH]
	var point := root.get_final_transform() * _center(tab)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = point
		click.global_position = point
		Input.parse_input_event(click)
		await process_frame
	_check(lab.current_tab == MetaLabUI.TAB_RESEARCH, "clique do mouse troca a aba (caminho nativo do PC)")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	_check(lab.current_tab == MetaLabUI.TAB_PROJECTS, "tecla E avança a aba")
	Input.action_press(&"ui_cancel")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await process_frame
	Input.action_release(&"ui_cancel")
	_check(not lab.is_open(), "Esc/ui_cancel fecha o terminal")
	lab.open_terminal(player)
	await process_frame
	lab.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not lab.is_open(), "voltar do Android fecha o terminal")


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _raw_touch(position: Vector2, pressed: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(position: Vector2) -> void:
	_touch_index += 1
	_raw_touch(position, true, _touch_index)
	await process_frame
	_raw_touch(position, false, _touch_index)
	await process_frame


func _drag(from: Vector2, to: Vector2) -> void:
	_touch_index += 1
	_raw_touch(from, true, _touch_index)
	await process_frame
	for step in range(1, 9):
		var drag := InputEventScreenDrag.new()
		drag.index = _touch_index
		drag.position = root.get_final_transform() * from.lerp(to, step / 8.0)
		drag.relative = (to - from) / 8.0
		Input.parse_input_event(drag)
		await process_frame
	_raw_touch(to, false, _touch_index)
	await process_frame


func _capture(name: String) -> void:
	if out_dir.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(out_dir.path_join(name + ".png"))
