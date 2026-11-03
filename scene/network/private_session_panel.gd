extends "res://ui/cyber_modal.gd"
## Sessão privada (03/11): criar, entrar por código de convite, convites e sala.
## Usa transporte real e a ponte PrivateGameplayBridge do Codex (protótipo jogável).
## Quatro APKs pela internet ainda não homologados. Segredos (chave do
## anfitrião, convites, retomada) ficam só em memória; só o endereço wss:// é lembrado.
const INVITE_CODE := preload("res://scene/network/private_invite_code.gd")
var controller: Node
var return_page: StringName = &""
var return_focus: StringName = &""
var settings_path := "user://private_coop_v1.cfg"
var endpoint_field: LineEdit
var key_field: LineEdit
var code_field: LineEdit
var room_field: LineEdit
var token_field: LineEdit
var show_advanced := false
var confirm_revoke := false
## índice do convite -> public_id do amigo a quem o anfitrião pretende enviá-lo (memória).
var invite_targets: Dictionary = {}
var _last_status := ""
var _countdown: Label

const STATUS := {
	"offline": ["OFFLINE", "Sem conexão com o servidor de jogo."],
	"connecting": ["CONECTANDO", "Abrindo conexão segura (WSS/TLS)…"],
	"lobby": ["NA SALA", "Conectado. Aguardando os quatro assentos."],
	"active": ["EM PARTIDA", "Gameplay privado em validação. Host simula; convidados recebem o estado."],
	"paused": ["PAUSADA", "Alguém caiu. Assentos reservados por até 10 minutos."],
	"reconnecting": ["RECONECTANDO", "Conexão perdida. Nova tentativa automática a cada 3 s, por até 10 min."],
	"suspended": ["SUSPENSA", "Tempo de reconexão esgotado. O estado recebido foi preservado."],
	"error": ["ERRO", "Conexão encerrada."],
}
const ERRORS := {
	"secure_endpoint_required": "Use um endereço wss:// válido (sem usuário, senha ou parâmetros).",
	"server_unavailable": "Servidor indisponível: confira o endereço, se o serviço está ligado e se o certificado é válido.",
	"not_authorized": "Acesso recusado: chave do anfitrião inválida ou sessão inexistente.",
	"invite_invalid_or_expired": "Convite inválido, já usado ou expirado. Peça um novo ao anfitrião.",
	"session_suspended": "Sessão suspensa: o prazo de reconexão terminou.",
	"resume_rejected": "Não foi possível retomar seu assento.",
	"authorization_required": "Convite ou chave ausente ou em formato inválido.",
	"rate_limited": "Muitas mensagens em pouco tempo. Aguarde e tente de novo.",
	"social_rate_limited": "Limite de solicitações desta sessão atingido.",
	"exactly_four_authorized_connections_required": "São necessários os quatro assentos conectados.",
	"participant_backup_failed": "Falha ao salvar o estado recebido neste aparelho.",
	"storage_unavailable": "O servidor não conseguiu gravar o estado da sessão.",
	"unsupported_protocol": "Versão do jogo incompatível com o servidor.",
}


func _build() -> void:
	layer = 96
	title_label.text = "COOPERATIVO PRIVADO"
	subtitle_label.text = "Anfitrião + até 3 convidados • conexão criptografada (TLS) • só com convite"
	add_tab("room", "SALA")
	add_tab("create", "CRIAR SESSÃO")
	add_tab("join", "ENTRAR")
	add_tab("invites", "CONVITES")


func open(tab := "room", from_page: StringName = &"", focus_name: StringName = &"") -> void:
	return_page = from_page
	return_focus = focus_name
	confirm_revoke = false
	if not from_page.is_empty():
		controller.game.mode_select.visible = false
	if not session().status_changed.is_connected(_on_status_changed):
		session().status_changed.connect(_on_status_changed)
	_last_status = session().status
	show_modal(tab, not controller.game.mode_selected)


func close() -> void:
	if busy:
		return
	hide_modal()
	closed.emit()
	if not return_page.is_empty() and not controller.game.mode_selected:
		controller.game.mode_select.return_to(return_page, return_focus)


func session() -> Node:
	return controller.private_session


func status_text(status: String) -> String:
	return String(STATUS.get(status, [status.to_upper(), ""])[0])


func status_color(status: String) -> Color:
	match status:
		"lobby", "active":
			return UI.CYAN
		"connecting", "reconnecting", "paused":
			return UI.AMBER
		"suspended":
			return UI.MAGENTA
		"error":
			return UI.RED
	return UI.DIM


func error_text(code: String) -> String:
	if code.is_empty():
		return ""
	if code.begins_with("invalid_") or code == "snapshot_identity_mismatch":
		return "Resposta inválida do servidor: conexão encerrada por segurança."
	return String(ERRORS.get(code, "Conexão recusada pelo servidor."))


func _render(tab: String) -> void:
	match tab:
		"room":
			_render_room()
		"create":
			_render_create()
		"join":
			_render_join()
		"invites":
			_render_invites()
	_update_status()


func _update_status() -> void:
	set_status(status_text(session().status), status_color(session().status))


func _render_room() -> void:
	var client := session()
	var columns := split_body(420.0)
	var list: VBoxContainer = columns[0]
	var side: VBoxContainer = columns[1]
	var state := UI.card(list, true)
	state.add_child(UI.label(status_text(client.status), UI.TITLE_SIZE, status_color(client.status), false))
	state.add_child(UI.label(String(STATUS.get(client.status, ["", ""])[1]), UI.BODY_SIZE, UI.TEXT))
	var problem := error_text(String(client.last_error))
	if not problem.is_empty():
		state.add_child(UI.label(problem, UI.BODY_SIZE, UI.RED))
	if not String(client.room_id).is_empty() and client.status != "offline":
		state.add_child(UI.label("Sessão ••••%s • você é o assento %d%s" % [String(client.room_id).right(4).to_upper(), int(client.peer_id), " (anfitrião)" if int(client.peer_id) == 1 else ""], UI.META_SIZE, UI.DIM))
	list.add_child(UI.heading("PARTICIPANTES"))
	for seat in range(1, 5):
		var entry: Dictionary = client.roster_entry(seat)
		var card := UI.card(list)
		var line := UI.row(card, 14)
		line.add_child(UI.avatar(String(entry.get("avatar", "jhon")), 56.0) if not entry.is_empty() else _empty_avatar())
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(texts)
		var role := "ANFITRIÃO" if seat == 1 else "CONVIDADO"
		var shown := String(entry.get("name", ""))
		texts.add_child(UI.label("ASSENTO %d • %s%s" % [seat, role, " • VOCÊ" if seat == int(client.peer_id) and client.status != "offline" else ""], UI.META_SIZE, UI.MAGENTA if seat == 1 else UI.DIM, false))
		if entry.is_empty():
			texts.add_child(UI.label("Livre — aguardando convite" if seat > 1 else "Você, ao criar uma sessão", UI.BODY_SIZE, UI.DIM))
		else:
			texts.add_child(UI.label(shown if not shown.is_empty() else "Participante sem nome", UI.BODY_SIZE, UI.WHITE))
			var online := bool(entry.get("connected", false))
			texts.add_child(UI.label("CONECTADO" if online else "DESCONECTADO • assento reservado", UI.META_SIZE, UI.GREEN if online else UI.AMBER, false))
	var actions := UI.detail_panel(side)
	actions.add_child(UI.heading("AÇÕES", UI.MAGENTA))
	var connected: int = client.lobby.get("connected", []).size()
	if client.is_connected_session() and int(client.peer_id) == 1:
		var start := UI.button("INICIAR COOPERATIVO (%d/%d)" % [connected, int(client.lobby.get("required_players", 4))], _start, "primary")
		start.name = "Start"
		start.disabled = connected < int(client.lobby.get("required_players", 4)) or client.status == "active"
		actions.add_child(start)
		actions.add_child(UI.label("Inicia o protótipo de gameplay com todos os assentos autorizados. Quatro APKs pela internet ainda não homologados.", UI.META_SIZE, UI.DIM))
	if client.status != "offline":
		var leave := UI.button("SAIR DA SESSÃO", _leave, "danger")
		leave.name = "Leave"
		actions.add_child(leave)
		actions.add_child(UI.label("Ao sair, o último estado recebido fica salvo só neste aparelho, separado das campanhas solo.", UI.META_SIZE, UI.DIM))
	else:
		var create := UI.button("CRIAR SESSÃO PRIVADA", select_tab.bind("create"), "primary")
		create.name = "GoCreate"
		actions.add_child(create)
		var join := UI.button("ENTRAR COM CONVITE", select_tab.bind("join"))
		join.name = "GoJoin"
		actions.add_child(join)
	UI.divider(actions, UI.MAGENTA)
	actions.add_child(UI.label("SEGURANÇA", UI.META_SIZE, UI.MAGENTA, false))
	actions.add_child(UI.label("Transporte criptografado com certificado verificado. Isto NÃO é criptografia ponta a ponta: o servidor da sessão processa os dados. Chat desativado.", UI.META_SIZE, UI.DIM))


func _empty_avatar() -> Control:
	var box := ColorRect.new()
	box.color = Color(UI.DIM, 0.12)
	box.custom_minimum_size = Vector2(56, 56)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


func _render_create() -> void:
	var list := scroll_body()
	if session().status != "offline" and session().status != "error":
		_already_connected(list)
		return
	var card := UI.card(list, true)
	card.add_child(UI.heading("CRIAR SESSÃO PRIVADA"))
	card.add_child(UI.label("Você é o anfitrião (assento 1). O servidor gera três convites de uso único, válidos por 10 minutos.", UI.META_SIZE, UI.DIM))
	endpoint_field = UI.field("Endereço do servidor (wss://…)", _saved_endpoint(), false, 512)
	endpoint_field.name = "Endpoint"
	card.add_child(UI.label("ENDEREÇO PÚBLICO DO SERVIDOR", UI.META_SIZE, UI.TEXT, false))
	card.add_child(endpoint_field)
	card.add_child(UI.label("Use o mesmo endereço que os convidados vão usar: ele vai dentro de cada código de convite.", UI.META_SIZE, UI.DIM))
	key_field = UI.field("Chave do anfitrião (não é salva)", "", true, 256)
	key_field.name = "OwnerKey"
	card.add_child(UI.label("CHAVE DO ANFITRIÃO", UI.META_SIZE, UI.TEXT, false))
	card.add_child(key_field)
	var actions := UI.actions(card)
	var create := UI.button("CRIAR SESSÃO", _create, "primary", 260.0)
	create.name = "Create"
	actions.add_child(create)
	var info := UI.card(list)
	info.add_child(UI.heading("ANTES DE CRIAR", UI.TEXT))
	info.add_child(UI.label("O servidor de jogo (relay) precisa estar rodando e publicado com SUA autorização. O jogo não abre portas nem publica serviços sozinho. Veja docs/social_coop/HOSPEDAGEM_PRIVADA_G14.md.", UI.META_SIZE, UI.DIM))


func _render_join() -> void:
	var list := scroll_body()
	if session().status != "offline" and session().status != "error":
		_already_connected(list)
		return
	var card := UI.card(list, true)
	card.add_child(UI.heading("ENTRAR EM SESSÃO"))
	card.add_child(UI.label("Cole o código de convite que o anfitrião enviou a você por mensagem privada. Cada código vale para uma pessoa e expira em 10 minutos.", UI.META_SIZE, UI.DIM))
	code_field = UI.field("Código de convite (CF1-…)", "", true, 1024)
	code_field.name = "InviteCode"
	code_field.text_submitted.connect(func(_text: String) -> void: _join_code())
	card.add_child(code_field)
	var actions := UI.actions(card)
	var paste := UI.button("COLAR", _paste, "normal", 160.0)
	paste.name = "Paste"
	actions.add_child(paste)
	var join := UI.button("ENTRAR", _join_code, "primary", 200.0)
	join.name = "Join"
	actions.add_child(join)
	var advanced := UI.button("AVANÇADO: DADOS SEPARADOS" if not show_advanced else "OCULTAR AVANÇADO", _toggle_advanced, "quiet", 320.0)
	advanced.name = "Advanced"
	list.add_child(advanced)
	if show_advanced:
		var manual := UI.card(list)
		endpoint_field = UI.field("Endereço do servidor (wss://…)", _saved_endpoint(), false, 512)
		endpoint_field.name = "Endpoint"
		manual.add_child(endpoint_field)
		room_field = UI.field("ID da sessão (32 caracteres)", "", false, 32)
		room_field.name = "RoomId"
		manual.add_child(room_field)
		token_field = UI.field("Convite (não é salvo)", "", true, 256)
		token_field.name = "Token"
		manual.add_child(token_field)
		var manual_join := UI.button("ENTRAR COM DADOS SEPARADOS", _join_manual, "normal", 340.0)
		manual_join.name = "JoinManual"
		manual.add_child(manual_join)


func _render_invites() -> void:
	var client := session()
	var list := scroll_body()
	if int(client.peer_id) != 1 or client.status == "offline" or client.invitations.is_empty():
		var card := UI.card(list, true)
		card.add_child(UI.heading("CONVITES"))
		if int(client.peer_id) == 1 and client.status != "offline":
			card.add_child(UI.label("Nenhum convite disponível: todos foram usados, revogados ou esta conexão foi retomada.", UI.BODY_SIZE, UI.TEXT))
		else:
			card.add_child(UI.label("Recebeu um convite? Ele chega como um código que um amigo envia a você. Cole-o em ENTRAR.", UI.BODY_SIZE, UI.TEXT))
			card.add_child(UI.label("Para convidar amigos, crie uma sessão privada: os códigos aparecem aqui.", UI.META_SIZE, UI.DIM))
		var actions := UI.actions(card)
		var join := UI.button("ENTRAR COM CÓDIGO", select_tab.bind("join"), "primary", 260.0)
		join.name = "GoJoin"
		actions.add_child(join)
		var create := UI.button("CRIAR SESSÃO", select_tab.bind("create"), "normal", 220.0)
		create.name = "GoCreate"
		actions.add_child(create)
		return
	var head := UI.card(list, true)
	head.add_child(UI.heading("CONVIDAR AMIGOS (%d DISPONÍVEIS)" % client.invitations.size()))
	_countdown = UI.label("", UI.BODY_SIZE, UI.AMBER, false)
	head.add_child(_countdown)
	_update_countdown()
	head.add_child(UI.label("Envie cada código a UMA pessoa por um canal privado. Quem tiver o código entra — trate-o como senha. Limpe a área de transferência depois.", UI.META_SIZE, UI.DIM))
	var friends: Dictionary = controller.profile.data.get("friends", {}) if controller.profile.initialize() else {}
	for index in client.invitations.size():
		var card := UI.card(list)
		var target := String(invite_targets.get(index, ""))
		var target_name := String(friends.get(target, {}).get("display_name", "")) if not target.is_empty() else ""
		card.add_child(UI.label("CONVITE %d" % (index + 1), UI.HEADING_SIZE, UI.WHITE))
		card.add_child(UI.label("Para: " + (target_name if not target_name.is_empty() else "(escolha um amigo ou envie a quem quiser)"), UI.META_SIZE, UI.CYAN if not target_name.is_empty() else UI.DIM))
		var actions := UI.actions(card)
		var copy := UI.button("COPIAR CÓDIGO", _copy_invite.bind(index), "primary", 220.0)
		copy.name = "Copy_%d" % index
		actions.add_child(copy)
		if not friends.is_empty():
			var choose := UI.button("TROCAR AMIGO", _cycle_target.bind(index), "normal", 220.0)
			choose.name = "Target_%d" % index
			actions.add_child(choose)
	var danger := UI.card(list)
	danger.add_child(UI.heading("REVOGAR", UI.RED))
	danger.add_child(UI.label("Se um código foi enviado para a pessoa errada, revogue: o servidor invalida todos os convites ainda não usados. Quem já entrou continua.", UI.META_SIZE, UI.DIM))
	var revoke_actions := UI.actions(danger)
	if confirm_revoke:
		var confirm := UI.button("CONFIRMAR REVOGAÇÃO", _revoke, "danger", 280.0)
		confirm.name = "ConfirmRevoke"
		revoke_actions.add_child(confirm)
		var cancel := UI.button("CANCELAR", _cancel_revoke, "normal", 180.0)
		cancel.name = "CancelRevoke"
		revoke_actions.add_child(cancel)
	else:
		var revoke := UI.button("REVOGAR CONVITES NÃO USADOS", _ask_revoke, "danger", 340.0)
		revoke.name = "Revoke"
		revoke_actions.add_child(revoke)


func _already_connected(list: VBoxContainer) -> void:
	var card := UI.card(list, true)
	card.add_child(UI.heading("VOCÊ JÁ ESTÁ NUMA SESSÃO"))
	card.add_child(UI.label("Estado: " + status_text(session().status) + ". Saia da sessão atual antes de criar ou entrar em outra.", UI.BODY_SIZE, UI.TEXT))
	var room := UI.button("VER SALA", select_tab.bind("room"), "primary", 220.0)
	room.name = "GoRoom"
	card.add_child(room)


func _update_countdown() -> void:
	if not is_instance_valid(_countdown):
		return
	var left: int = session().invite_seconds_left()
	_countdown.text = ("Expiram em %d:%02d (estimativa deste aparelho)" % [left / 60, left % 60]) if left > 0 else "Convites provavelmente expirados. Crie uma nova sessão para gerar outros."


func _saved_endpoint() -> String:
	if not String(session().endpoint).is_empty():
		return String(session().endpoint)
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return ""
	var value := String(config.get_value("private_coop", "endpoint", ""))
	return value if INVITE_CODE.valid_endpoint(value) else ""


func _remember_endpoint(endpoint: String) -> void:
	if not INVITE_CODE.valid_endpoint(endpoint):
		return
	var config := ConfigFile.new()
	config.set_value("private_coop", "endpoint", endpoint)
	config.save(settings_path)


func _card() -> Dictionary:
	return controller.profile.session_card() if controller.profile.initialize() else {}


func _create() -> void:
	if controller.game.mode_selected:
		notify("Saia da campanha atual para criar, entrar ou iniciar uma sessão privada.", "warn")
		return
	var endpoint := endpoint_field.text.strip_edges()
	var key := key_field.text.strip_edges()
	key_field.clear()
	if not INVITE_CODE.valid_endpoint(endpoint):
		notify(ERRORS.secure_endpoint_required, "error")
		return
	if key.length() < 32:
		notify("A chave do anfitrião tem pelo menos 32 caracteres.", "error")
		return
	var shared_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var result: Error = session().connect_session(endpoint, "create", key, "", shared_id, null, _card())
	key = ""
	if result != OK:
		notify(error_text(String(session().last_error)) if not String(session().last_error).is_empty() else "Não foi possível iniciar a conexão.", "error")
		return
	_remember_endpoint(endpoint)
	invite_targets.clear()
	select_tab("room")
	notify("Conectando ao servidor…", "busy")


func _join_code() -> void:
	var parsed: Dictionary = INVITE_CODE.decode(code_field.text)
	code_field.clear()
	if parsed.is_empty():
		notify("Código de convite inválido. Copie o código inteiro, começando por CF1-.", "error")
		return
	_join(String(parsed.endpoint), String(parsed.room_id), String(parsed.token))


func _join_manual() -> void:
	var endpoint := endpoint_field.text.strip_edges()
	var room := room_field.text.strip_edges().to_lower()
	var token := token_field.text.strip_edges()
	token_field.clear()
	if not INVITE_CODE.valid_endpoint(endpoint) or not INVITE_CODE.valid_room(room) or not INVITE_CODE.valid_token(token):
		notify("Dados inválidos: endereço wss://, ID de 32 caracteres e convite completo.", "error")
		return
	_join(endpoint, room, token)


func _join(endpoint: String, room: String, token: String) -> void:
	if controller.game.mode_selected:
		notify("Saia da campanha atual para criar, entrar ou iniciar uma sessão privada.", "warn")
		return
	var result: Error = session().connect_session(endpoint, "join", token, room, "", null, _card())
	if result != OK:
		notify(error_text(String(session().last_error)) if not String(session().last_error).is_empty() else "Não foi possível iniciar a conexão.", "error")
		return
	select_tab("room")
	notify("Conectando ao servidor…", "busy")


func _paste() -> void:
	var text := DisplayServer.clipboard_get().strip_edges()
	if text.length() > 1024:
		notify("O conteúdo copiado é longo demais para ser um convite.", "error")
		return
	code_field.text = text
	notify("Código colado. Toque em ENTRAR." if text.begins_with("CF1-") else "A área de transferência não contém um código CF1-.", "info" if text.begins_with("CF1-") else "warn")


func _toggle_advanced() -> void:
	show_advanced = not show_advanced
	refresh()


func _copy_invite(index: int) -> void:
	var client := session()
	if index < 0 or index >= client.invitations.size():
		return
	var code: String = INVITE_CODE.encode(String(client.endpoint), String(client.room_id), String(client.invitations[index]))
	if code.is_empty():
		notify("Não foi possível montar o código (endereço inválido).", "error")
		return
	DisplayServer.clipboard_set(code)
	notify("Convite %d copiado. Envie a uma única pessoa por mensagem privada." % (index + 1), "ok")


func _cycle_target(index: int) -> void:
	var friends: Dictionary = controller.profile.data.get("friends", {})
	var ids := friends.keys()
	ids.sort()
	if ids.is_empty():
		return
	var current := String(invite_targets.get(index, ""))
	var position := ids.find(current)
	var next := position + 1
	if next >= ids.size():
		invite_targets.erase(index)
	else:
		invite_targets[index] = String(ids[next])
	refresh()


func _ask_revoke() -> void:
	confirm_revoke = true
	refresh()
	call_deferred("_focus_named", "CancelRevoke")


func _cancel_revoke() -> void:
	confirm_revoke = false
	refresh()


func _revoke() -> void:
	confirm_revoke = false
	if session().revoke_invites() == OK:
		notify("Revogação enviada ao servidor.", "warn")
	else:
		notify("Sem conexão com o servidor: não foi possível revogar agora.", "error")
	refresh()


func _start() -> void:
	if controller.game.mode_selected:
		notify("Saia da campanha atual para criar, entrar ou iniciar uma sessão privada.", "warn")
		return
	if session().start_session() != OK:
		notify(ERRORS.exactly_four_authorized_connections_required, "error")
	else:
		notify("Início solicitado ao servidor.", "busy")


func _leave() -> void:
	await controller.end_private_gameplay()
	invite_targets.clear()
	refresh()
	notify("Você saiu da sessão. Estado recebido preservado neste aparelho.", "info")


func _focus_named(node_name: String) -> void:
	var target := body.find_child(node_name, true, false) as Control
	if target != null and target.is_visible_in_tree():
		target.grab_focus()


func _on_status_changed() -> void:
	if not is_open():
		return
	var status := String(session().status)
	if status != _last_status:
		_last_status = status
		if status == "error" or (status == "offline" and not String(session().last_error).is_empty()):
			notify(error_text(String(session().last_error)), "error")
		elif status == "lobby":
			notify("Conectado à sala.", "ok")
		elif status == "reconnecting":
			notify("Conexão perdida. Tentando reconectar…", "warn")
	if current_tab in ["room", "invites", "create", "join"]:
		refresh()
	_update_status()


func _tick(_delta: float) -> void:
	if current_tab == "invites" and Engine.get_process_frames() % 30 == 0:
		_update_countdown()
