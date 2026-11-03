extends SceneTree
## Integração REAL (03/11) em main.tscn: menu reorganizado, toque, campanhas pela UI,
## SOCIAL, sessão privada (inclusive servidor indisponível de verdade), LAN e hub.
## Namespaces descartáveis: nenhum save/perfil real é lido ou escrito.
var failures := 0
var game: Node
var mode: Node
var campaigns: Node


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _frames(count := 3) -> void:
	for i in count:
		await process_frame


func _wait_game() -> bool:
	for i in 900:
		await process_frame
		if game.mode_selected and not game.is_transitioning:
			return true
	return false


func _tap(control: Control) -> void:
	# Coordenadas da janela: aplica a transformação de stretch (como os testes de toque existentes).
	var center := root.get_final_transform() * control.get_global_rect().get_center()
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = center
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame
	await process_frame


func _cancel() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"ui_cancel"
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)


func _find(panel: Node, node_name: String) -> Control:
	return panel.body.find_child(node_name, true, false) as Control


func _run() -> void:
	var ns := "user://test_social_menu_" + Crypto.new().generate_random_bytes(10).hex_encode()
	DirAccess.make_dir_recursive_absolute(ns)
	game = load("res://scene/main.tscn").instantiate()
	game.get_node("LocalSettings").settings_path = ns.path_join("settings.cfg")
	game.get_node("MetaProgression").save_path = ns.path_join("legacy.json")
	root.add_child(game)
	await _frames(2)
	campaigns = game.campaigns
	campaigns.store.root_path = ns.path_join("campaigns")
	check(campaigns.profile.initialize(ns.path_join("profile")), "profile in test namespace")
	campaigns.private_panel.settings_path = ns.path_join("coop.cfg")
	mode = game.mode_select
	await _menu_structure()
	await _campaign_flow()
	await _social_flow()
	await _private_flow(ns)
	await _lan_path()
	await _hub_services()
	game.queue_free()
	await _frames(3)
	print("SOCIAL_MENU_REPORT failures=", failures)
	quit(0 if failures == 0 else 1)


func _menu_structure() -> void:
	var labels: Array = []
	for child in mode.main_page.get_children():
		if child is Button:
			labels.append(child.text)
	check(labels == ["JOGAR", "SOCIAL", "OPÇÕES", "SAIR"], "main menu is JOGAR/SOCIAL/OPÇÕES/SAIR, got %s" % [labels])
	await _tap(mode.play_button)
	check(mode.players_page.visible and mode.solo_button.text == "CAMPANHA SOLO" and mode.coop_button.text == "COOPERATIVO", "JOGAR page by touch")
	await _tap(mode.solo_button)
	check(mode.solo_page.visible and mode.continue_button.disabled and mode.create_button.has_focus(), "solo page without campaigns focuses CRIAR")
	await _cancel()
	check(mode.players_page.visible and mode.solo_button.has_focus(), "back from solo page")
	await _tap(mode.coop_button)
	var coop_labels: Array = []
	for child in mode.coop_page.get_children():
		if child is Button:
			coop_labels.append(child.text)
	check(coop_labels == ["MESMO DISPOSITIVO", "REDE LOCAL (LAN)", "CRIAR SESSÃO PRIVADA", "ENTRAR EM SESSÃO", "CONVITES", "VOLTAR"], "single COOPERATIVO section, got %s" % [coop_labels])
	await _cancel()
	check(mode.players_page.visible and mode.coop_button.has_focus(), "back from coop page")
	mode.show_main_page()
	await _frames(3)  # o contêiner reposiciona a página no quadro seguinte
	await _tap(mode.social_button)
	check(mode.social_page.visible, "SOCIAL page")
	await _cancel()
	check(mode.main_page.visible and mode.social_button.has_focus(), "back from SOCIAL")


func _campaign_flow() -> void:
	await _tap(mode.play_button)
	await _tap(mode.solo_button)
	await _tap(mode.create_button)
	var panel: Node = campaigns.panel
	check(panel.is_open() and panel.current_tab == "create" and not mode.visible, "CRIAR opens the creation tab")
	check(game.get_node("MenuEnvironment").visible, "animated city stays behind title panels")
	await _tap(panel.back_button)
	check(not panel.is_open() and mode.solo_page.visible and mode.create_button.has_focus(), "VOLTAR by touch returns to the solo page")
	await _tap(mode.create_button)
	panel.name_field.text = "  Alfa\u202e  "
	await _tap(_find(panel, "Create"))
	check(await _wait_game(), "creating from the UI enters the hub")
	var first_id: String = String(campaigns.active.get("campaign_id", ""))
	check(String(campaigns.active.get("display_name", "")) == "Alfa", "campaign name sanitized")
	game.get_players()[0].health = 58
	check(campaigns.save_now(), "save hub")
	await game.return_to_main_menu()
	await _frames(3)
	check(await campaigns.start_new("Beta"), "second campaign")
	await game.return_to_main_menu()
	await _frames(3)
	mode.play_button.pressed.emit()
	mode.solo_button.pressed.emit()
	await _frames(2)
	check(not mode.continue_button.disabled and "Beta" in mode.solo_status.text, "CONTINUAR shows the most recent campaign")
	mode.get_node("Overlay/Center/SoloPage/Manage").pressed.emit()
	await _frames(3)
	check(panel.is_open() and panel.current_tab == "slots" and panel._summaries.size() == 2, "two slots listed")
	await _tap(_find(panel, "Slot_01"))
	check(panel.selected_id == first_id, "slot selected by touch")
	(_find(panel, "RenameField") as LineEdit).text = "Alfa Renomeada"
	await _tap(_find(panel, "Rename"))
	check(String(campaigns.store.load_campaign(first_id).display_name) == "Alfa Renomeada", "rename persisted")
	var second_id := ""
	for summary: Dictionary in panel._summaries:
		if String(summary.campaign_id) != first_id:
			second_id = String(summary.campaign_id)
	await _tap(_find(panel, "Delete"))
	check(_find(panel, "ConfirmDelete") != null and panel._summaries.size() == 2, "deletion asks for confirmation")
	await _tap(_find(panel, "CancelDelete"))
	check(panel.pending_delete.is_empty() and campaigns.store.list_campaigns().size() == 2, "cancel keeps the slot")
	panel._select(second_id)
	await _frames(2)
	await _tap(_find(panel, "Delete"))
	await _tap(_find(panel, "ConfirmDelete"))
	check(campaigns.store.list_campaigns().size() == 1 and campaigns.store.load_campaign(second_id).is_empty(), "confirmed deletion archives only that slot")
	check(not campaigns.store.load_campaign(first_id).is_empty(), "other slot independent")
	await _tap(_find(panel, "Continue"))
	check(await _wait_game() and String(campaigns.active.campaign_id) == first_id, "continue from the slot card")
	check(game.get_players()[0].health == 58, "restored state")
	await game.return_to_main_menu()
	await _frames(3)
	mode.show_main_page()


func _social_flow() -> void:
	mode.social_button.pressed.emit()
	await _frames(2)
	mode.get_node("Overlay/Center/SocialPage/Friends").pressed.emit()
	await _frames(3)
	var panel: Node = campaigns.social_panel
	check(panel.is_open() and panel.current_tab == "friends", "AMIGOS opens its tab")
	check((_find(panel, "OnlineRequest") as Button).disabled, "online request is disabled without accounts")
	(_find(panel, "ContactId") as LineEdit).text = "xyz"
	await _tap(_find(panel, "AddContact"))
	check(panel.profile().data.friends.is_empty() and panel.feedback.text.begins_with("ID inválido"), "invalid ID explained")
	(_find(panel, "ContactId") as LineEdit).text = "A1B2-C3D4-E5F6-0718"
	(_find(panel, "ContactName") as LineEdit).text = "Dani"
	await _tap(_find(panel, "AddContact"))
	check(panel.profile().data.friends.has("a1b2c3d4e5f60718"), "contact added from formatted ID")
	(_find(panel, "ContactId") as LineEdit).text = "1234567890abcdef"
	await _tap(_find(panel, "DraftRequest"))
	check(panel.profile().data.requests.has("1234567890abcdef"), "draft stored, labelled not sent")
	await _tap(panel.tabs["requests"])
	check(panel.current_tab == "requests" and _find(panel, "CancelDraft_1234567890abcdef") != null, "draft listed under SOLICITAÇÕES")
	await _tap(_find(panel, "CancelDraft_1234567890abcdef"))
	check(panel.profile().data.requests.is_empty(), "draft cancelled")
	await _tap(panel.tabs["friends"])
	await _tap(_find(panel, "Remove_a1b2c3d4e5f60718"))
	await _tap(_find(panel, "CancelRemove"))
	check(panel.profile().data.friends.has("a1b2c3d4e5f60718"), "remove needs confirmation")
	await _tap(_find(panel, "Block_a1b2c3d4e5f60718"))
	check(panel.profile().is_blocked("a1b2c3d4e5f60718") and panel.profile().data.friends.is_empty(), "block from friend card")
	await _tap(panel.tabs["blocked"])
	await _tap(_find(panel, "Unblock_a1b2c3d4e5f60718"))
	check(not panel.profile().is_blocked("a1b2c3d4e5f60718"), "unblock")
	await _tap(panel.tabs["profile"])
	(_find(panel, "NameField") as LineEdit).text = "Kinho"
	await _tap(_find(panel, "SaveName"))
	await _tap(_find(panel, "Avatar_spark"))
	check(panel.profile().data.display_name == "Kinho" and panel.profile().data.avatar == "spark", "name and portrait saved")
	await _cancel()
	check(not panel.is_open() and mode.social_page.visible and mode.get_node("Overlay/Center/SocialPage/Friends").has_focus(), "back returns to the SOCIAL page and origin button")
	mode.show_main_page()


func _private_flow(ns: String) -> void:
	mode.play_button.pressed.emit()
	mode.coop_button.pressed.emit()
	await _frames(2)
	mode.get_node("Overlay/Center/CoopPage/PrivateJoin").pressed.emit()
	await _frames(3)
	var panel: Node = campaigns.private_panel
	check(panel.is_open() and panel.current_tab == "join", "ENTRAR EM SESSÃO opens join")
	panel.code_field.text = "CF1-nao-e-um-convite"
	await _tap(_find(panel, "Join"))
	check(panel.feedback.text.begins_with("Código de convite inválido") and panel.code_field.text.is_empty(), "invalid code refused and cleared")
	await _tap(panel.tabs["create"])
	panel.endpoint_field.text = "ws://inseguro.example"
	panel.key_field.text = "k".repeat(40)
	await _tap(_find(panel, "Create"))
	check(panel.feedback.text.begins_with("Use um endereço wss://") and panel.key_field.text.is_empty(), "insecure endpoint refused, key cleared")
	# Servidor indisponível DE VERDADE: porta local fechada.
	panel.endpoint_field.text = "wss://127.0.0.1:9"
	panel.key_field.text = "k".repeat(40)
	await _tap(_find(panel, "Create"))
	for i in 600:
		await process_frame
		if campaigns.private_session.status == "offline" and not String(campaigns.private_session.last_error).is_empty():
			break
	check(campaigns.private_session.last_error == "server_unavailable", "closed server reported as unavailable, got %s" % campaigns.private_session.last_error)
	await _frames(2)
	check(panel.current_tab == "room" and panel.feedback.text.begins_with("Servidor indisponível"), "unavailable server explained")
	var saved := FileAccess.get_file_as_string(ns.path_join("coop.cfg"))
	check("wss://127.0.0.1:9" in saved and not ("k".repeat(40) in saved), "only the endpoint is remembered, never the key")
	await _tap(panel.tabs["invites"])
	check(_find(panel, "GoJoin") != null, "CONVITES without a session explains how invites arrive")
	await _tap(panel.back_button)
	check(mode.coop_page.visible and mode.get_node("Overlay/Center/CoopPage/PrivateJoin").has_focus(), "back to COOPERATIVO")


func _lan_path() -> void:
	await _tap(mode.lan_button)
	check(mode.difficulty_page.visible, "LAN asks for difficulty first")
	await _tap(mode.normal_button)
	var lobby: Node = game.get_node("LanLobby")
	check(lobby.visible and not mode.visible, "LAN lobby opens after difficulty")
	lobby._close()
	await _frames(3)
	check(mode.coop_page.visible and mode.lan_button.has_focus(), "LAN lobby returns to COOPERATIVO")
	mode.show_main_page()


func _hub_services() -> void:
	check(await campaigns.continue_latest(), "CONTINUAR from the solo page")
	await _wait_game()
	var services: Node = campaigns.services
	services.open()
	await _frames(2)
	check(paused and services.is_open() and services.current_tab == "world", "hub panel pauses")
	services.select_tab("social")
	await _frames(2)
	await _tap(_find(services, "Social_friends"))
	check(campaigns.social_panel.is_open(), "social panel opens over the hub panel")
	await _cancel()
	check(not campaigns.social_panel.is_open() and services.is_open() and paused, "closing it returns to the hub panel")
	services.close()
	await _frames(2)
	check(not paused and not services.is_open(), "hub panel restores pause state")
	await game.return_to_main_menu()
	await _frames(3)
