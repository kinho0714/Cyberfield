extends "res://ui/cyber_modal.gd"
## Hub: MUNDO / SESSÃO (03/11 no kit visual comum). Abas: mundo da campanha, atalho
## para o SOCIAL e para o COOPERATIVO PRIVADO. Pausa o jogo enquanto aberto e restaura
## o estado anterior ao fechar (mesmo contrato do painel original do Codex).
const PRESENTATION := preload("res://ui/menu_panel_presentation.gd")
var controller: Node
var hub_button: Button
var was_paused := false


func _build() -> void:
	layer = 94
	title_label.text = "MUNDO / SESSÃO"
	subtitle_label.text = "Mundo e sessão • fechar restaura o estado anterior da pausa"
	add_tab("world", "MUNDO")
	add_tab("social", "SOCIAL")
	add_tab("coop", "COOP PRIVADO")
	hub_button = Button.new()
	hub_button.name = "HubButton"
	hub_button.text = "MUNDO / SESSÃO"
	hub_button.position = Vector2(20, 52)
	hub_button.custom_minimum_size = Vector2(190, 44)
	PRESENTATION.style_button(hub_button)
	hub_button.add_theme_font_size_override("font_size", 17)
	add_child(hub_button)
	move_child(hub_button, 0)
	hub_button.pressed.connect(open)


func _process(delta: float) -> void:
	hub_button.visible = controller.game.mode_selected and controller.game.current_is_hub and (not controller.active.is_empty() or controller.private_gameplay.running) and not is_open() and not get_tree().paused
	super._process(delta)


func _input(event: InputEvent) -> void:
	if not is_open():
		if hub_button.visible and event is InputEventScreenTouch and event.pressed and hub_button.get_global_rect().has_point(event.position):
			open()
			get_viewport().set_input_as_handled()
		return
	if _child_panel_open():
		return
	super._input(event)


func open() -> void:
	controller.save_now()
	was_paused = get_tree().paused
	get_tree().paused = true
	controller.game._set_all_player_input(false)
	controller.game.mode_select.visible = false
	add_to_group("meta_lab_ui")
	show_modal("world" if not controller.active.is_empty() else "social")


func close() -> void:
	for panel in [controller.social_panel, controller.private_panel]:
		if panel != null and panel.is_open():
			panel.hide_modal()
	hide_modal()
	remove_from_group("meta_lab_ui")
	get_tree().paused = was_paused
	controller.game.mode_select.visible = not controller.game.mode_selected
	if controller.game.mode_selected and not was_paused:
		controller.game._set_all_player_input(true)
	closed.emit()


func _child_panel_open() -> bool:
	for panel in [controller.social_panel, controller.private_panel]:
		if panel != null and panel.is_open():
			return true
	return false


## Compatibilidade com o contrato anterior (testes e chamadas existentes).
func show_world() -> void:
	select_tab("world")


func show_profile() -> void:
	select_tab("social")


func show_private() -> void:
	select_tab("coop")


func _render(tab: String) -> void:
	match tab:
		"world":
			_render_world()
		"social":
			_render_social()
		"coop":
			_render_coop()
	set_status("SOLO OFFLINE" if not controller.active.is_empty() else "SEM CAMPANHA", UI.DIM)


func _render_world() -> void:
	var columns := split_body(400.0)
	var list: VBoxContainer = columns[0]
	var side: VBoxContainer = columns[1]
	if controller.active.is_empty():
		empty_state(list, "NENHUMA CAMPANHA ATIVA", "Selecione ou crie uma campanha para registrar e explorar regiões.")
		return
	list.add_child(UI.heading("REGIÕES CONHECIDAS"))
	for location: Dictionary in controller.geography.known_regions():
		var card := UI.card(list)
		card.add_child(UI.label(String(location.display_name), UI.BODY_SIZE, UI.WHITE))
		card.add_child(UI.label("%s • %s" % [UI.location_kind(String(location.kind)), UI.narrative_status(String(location.narrative_status))], UI.META_SIZE, UI.DIM))
		if location.kind == "neighborhood" and location.implementation == "implemented":
			var actions := UI.actions(card)
			var choose := UI.button("EXPLORAR NA PRÓXIMA RUN", _choose.bind(String(location.id)), "primary", 300.0)
			choose.name = "Explore_" + String(location.id)
			actions.add_child(choose)
	var save := UI.detail_panel(side)
	save.add_child(UI.heading("AUTOSAVE", UI.MAGENTA))
	save.add_child(UI.label("Intervalo atual: %d s" % int(controller.autosave_seconds), UI.BODY_SIZE, UI.WHITE))
	var options := UI.row(save, 8)
	for seconds in [15, 30, 60]:
		var choice := UI.button("%d s" % seconds, _interval.bind(float(seconds)), "primary" if int(controller.autosave_seconds) == seconds else "quiet")
		choice.name = "Autosave_%d" % seconds
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options.add_child(choice)
	save.add_child(UI.label("Também salva ao pausar o app, ao sair para o menu e após mudanças de progresso permanente.", UI.META_SIZE, UI.DIM))


func _render_social() -> void:
	var list := scroll_body()
	var card := UI.card(list, true)
	card.add_child(UI.heading("SOCIAL"))
	if controller.profile.initialize():
		var data: Dictionary = controller.profile.data
		card.add_child(UI.label("%s • %d amigos • %d solicitações recebidas" % [String(data.display_name), data.friends.size(), data.incoming.size()], UI.BODY_SIZE, UI.TEXT))
	else:
		card.add_child(UI.label("Perfil indisponível. Os arquivos existentes foram preservados.", UI.BODY_SIZE, UI.RED))
	var actions := UI.actions(card)
	for pair in [["profile", "MEU PERFIL"], ["friends", "AMIGOS"], ["requests", "SOLICITAÇÕES"], ["blocked", "BLOQUEADOS"]]:
		var item := UI.button(pair[1], _open_social.bind(pair[0]), "normal", 220.0)
		item.name = "Social_" + pair[0]
		actions.add_child(item)


func _render_coop() -> void:
	var list := scroll_body()
	var client: Node = controller.private_session
	var card := UI.card(list, true)
	card.add_child(UI.heading("COOPERATIVO PRIVADO"))
	card.add_child(UI.label("Conexão: %s • %d/4 conectados" % [controller.private_panel.status_text(String(client.status)), client.lobby.get("connected", []).size()], UI.BODY_SIZE, controller.private_panel.status_color(String(client.status))))
	card.add_child(UI.label("Protótipo de gameplay privado integrado ao host Godot. Saia da campanha solo antes de entrar; quatro APKs pela internet ainda não homologados.", UI.META_SIZE, UI.DIM))
	var actions := UI.actions(card)
	for pair in [["room", "SALA"], ["create", "CRIAR SESSÃO"], ["join", "ENTRAR"], ["invites", "CONVITES"]]:
		var item := UI.button(pair[1], _open_private.bind(pair[0]), "normal", 200.0)
		item.name = "Coop_" + pair[0]
		actions.add_child(item)


func _open_social(tab: String) -> void:
	controller.social_panel.open(tab)


func _open_private(tab: String) -> void:
	controller.private_panel.open(tab)


func _choose(id: String) -> void:
	if controller.geography.choose_region(id):
		notify("Região selecionada para a próxima run.", "ok")
	else:
		notify("Não foi possível selecionar esta região.", "error")


func _interval(seconds: float) -> void:
	if controller.set_autosave_interval(seconds):
		refresh()
		notify("Autosave a cada %d s." % int(seconds), "ok")
	else:
		notify(controller.error_message(controller.last_error), "error")
