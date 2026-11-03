extends "res://ui/cyber_modal.gd"
## SOCIAL (03/11): perfil, amigos, solicitações e bloqueios sobre o LocalPlayerProfile.
## Honestidade da interface: sem servidor de contas não há amizade online. Os únicos
## pedidos que saem do aparelho viajam pela sessão privada já autorizada (SocialBridge).
var controller: Node
var return_page: StringName = &""
var return_focus: StringName = &""
var pending_remove := ""
var name_field: LineEdit
var id_field: LineEdit
var contact_name_field: LineEdit
var block_field: LineEdit


func _build() -> void:
	layer = 96
	title_label.text = "SOCIAL"
	subtitle_label.text = "Perfil local • sem conta online • dados ficam neste aparelho"
	add_tab("profile", "MEU PERFIL")
	add_tab("friends", "AMIGOS")
	add_tab("requests", "SOLICITAÇÕES")
	add_tab("blocked", "BLOQUEADOS")


func open(tab := "profile", from_page: StringName = &"", focus_name: StringName = &"") -> void:
	return_page = from_page
	return_focus = focus_name
	pending_remove = ""
	if not from_page.is_empty():
		controller.game.mode_select.visible = false
	if not controller.social.changed.is_connected(_on_social_changed):
		controller.social.changed.connect(_on_social_changed)
	show_modal(tab, not controller.game.mode_selected)
	if not profile().initialize():
		notify("Perfil indisponível. Os arquivos existentes foram preservados para recuperação.", "error")


func close() -> void:
	if busy:
		return
	hide_modal()
	closed.emit()
	if not return_page.is_empty() and not controller.game.mode_selected:
		controller.game.mode_select.return_to(return_page, return_focus)


func profile() -> Node:
	return controller.profile


func session() -> Node:
	return controller.private_session


func _update_counts() -> void:
	var data: Dictionary = profile().data
	if data.is_empty():
		return
	(tabs["friends"] as Button).text = "AMIGOS (%d)" % data.friends.size()
	var waiting: int = data.incoming.size()
	(tabs["requests"] as Button).text = "SOLICITAÇÕES (%d)" % waiting if waiting > 0 else "SOLICITAÇÕES"
	(tabs["requests"] as Button).add_theme_color_override("font_color", UI.MAGENTA if waiting > 0 and current_tab != "requests" else (UI.WHITE if current_tab == "requests" else UI.DIM))
	(tabs["blocked"] as Button).text = "BLOQUEADOS (%d)" % data.blocked.size()
	if session().is_connected_session():
		set_status("SESSÃO PRIVADA %d/4" % session().lobby.get("connected", []).size(), UI.CYAN)
	else:
		set_status("OFFLINE", UI.DIM)


func _render(tab: String) -> void:
	if not profile().initialize():
		empty_state(scroll_body(), "PERFIL INDISPONÍVEL", "Nenhuma revisão íntegra do perfil foi encontrada. Os arquivos foram preservados; nada foi sobrescrito.")
		return
	match tab:
		"profile":
			_render_profile()
		"friends":
			_render_friends()
		"requests":
			_render_requests()
		"blocked":
			_render_blocked()
	_update_counts()


func _render_profile() -> void:
	var data: Dictionary = profile().data
	var columns := split_body(440.0)
	var list: VBoxContainer = columns[0]
	var side: VBoxContainer = columns[1]
	var card := UI.card(list, true)
	var top := UI.row(card, 18)
	top.add_child(UI.avatar(String(data.avatar), 112.0))
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(names)
	names.add_child(UI.label(String(data.display_name), UI.TITLE_SIZE, UI.WHITE))
	names.add_child(UI.label("ID PÚBLICO  " + format_id(String(data.public_id)), UI.BODY_SIZE, UI.CYAN, false))
	names.add_child(UI.label("Compartilhe o ID só com quem você conhece. Seu ID interno nunca é exibido nem enviado.", UI.META_SIZE, UI.DIM))
	var copy := UI.button("COPIAR ID PÚBLICO", _copy_id, "normal", 260.0)
	copy.name = "CopyId"
	copy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	names.add_child(copy)
	var edit := UI.card(list)
	edit.add_child(UI.heading("NOME PÚBLICO"))
	edit.add_child(UI.label("É o que os participantes da sua sessão privada veem.", UI.META_SIZE, UI.DIM))
	var name_row := UI.row(edit, 8)
	name_field = UI.field("Nome público (até 24 caracteres)", String(data.display_name), false, 24)
	name_field.name = "NameField"
	name_field.text_submitted.connect(func(_text: String) -> void: _rename())
	name_row.add_child(name_field)
	var save := UI.button("SALVAR", _rename, "primary", 160.0)
	save.name = "SaveName"
	name_row.add_child(save)
	var avatars := UI.card(list)
	avatars.add_child(UI.heading("RETRATO"))
	var grid := UI.actions(avatars)
	for id: String in UI.AVATAR_ORDER:
		var pick := UI.button(String(UI.CHARACTERS[id].name), _avatar.bind(id), "primary" if id == String(data.avatar) else "normal", 132.0)
		pick.name = "Avatar_" + id
		pick.icon = UI.avatar_texture(id)
		pick.expand_icon = true
		pick.custom_minimum_size.y = 112
		pick.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		pick.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pick.alignment = HORIZONTAL_ALIGNMENT_CENTER
		pick.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		grid.add_child(pick)
	var privacy := UI.detail_panel(side)
	privacy.add_child(UI.heading("PRIVACIDADE", UI.MAGENTA))
	var requests_mode := String(data.privacy.get("friend_requests", "session"))
	privacy.add_child(UI.label("Solicitações de amizade", UI.BODY_SIZE, UI.WHITE))
	var request_row := UI.row(privacy, 8)
	for option in [["session", "DA SESSÃO"], ["none", "NINGUÉM"]]:
		var choice := UI.button(option[1], _privacy_requests.bind(option[0]), "primary" if requests_mode == option[0] else "quiet")
		choice.name = "Requests_" + option[0]
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		request_row.add_child(choice)
	privacy.add_child(UI.label("\"Da sessão\": só participantes já autorizados na sua sessão privada podem pedir.", UI.META_SIZE, UI.DIM))
	var invites_mode := String(data.privacy.get("allow_invites", "friends"))
	privacy.add_child(UI.label("Convites para sessões", UI.BODY_SIZE, UI.WHITE))
	var invite_row := UI.row(privacy, 8)
	for option in [["friends", "AMIGOS"], ["none", "NINGUÉM"]]:
		var choice := UI.button(option[1], _privacy_invites.bind(option[0]), "primary" if invites_mode == option[0] else "quiet")
		choice.name = "Invites_" + option[0]
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		invite_row.add_child(choice)
	privacy.add_child(UI.label("Preferência guardada para o servidor de contas futuro. Hoje convites chegam só como código enviado por você ou por um amigo.", UI.META_SIZE, UI.DIM))
	UI.divider(privacy, UI.MAGENTA)
	privacy.add_child(UI.label("Presença: PRIVADA", UI.BODY_SIZE, UI.WHITE))
	privacy.add_child(UI.label("Sem servidor de contas, seu estado online não é publicado para ninguém.", UI.META_SIZE, UI.DIM))


func _render_friends() -> void:
	var data: Dictionary = profile().data
	var columns := split_body(440.0)
	var list: VBoxContainer = columns[0]
	var side: VBoxContainer = columns[1]
	if data.friends.is_empty():
		empty_state(list, "NENHUM AMIGO AINDA", "Peça amizade a quem está na sua sessão privada ou adicione um contato local pelo ID público.")
	for id: Variant in _sorted_keys(data.friends):
		var friend: Dictionary = data.friends[id]
		var card := UI.card(list)
		var line := UI.row(card, 14)
		line.add_child(UI.avatar(String(friend.get("avatar", "jhon")), 64.0))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(texts)
		texts.add_child(UI.label(String(friend.get("display_name", "")), UI.HEADING_SIZE, UI.WHITE))
		var mutual := String(friend.get("status", "")) == "session_mutual_unverified"
		texts.add_child(UI.label("Confirmado pelos dois na sessão • identidade não verificada" if mutual else "Contato local • não verificado", UI.META_SIZE, UI.CYAN if mutual else UI.DIM))
		texts.add_child(UI.label("ID " + format_id(String(id)) + " • presença indisponível sem servidor", UI.META_SIZE, UI.DIM))
		var actions := UI.actions(card)
		if pending_remove == String(id):
			actions.add_child(UI.label("Remover %s?" % String(friend.get("display_name", "")), UI.META_SIZE, UI.AMBER, false))
			var confirm := UI.button("CONFIRMAR", _remove.bind(String(id)), "danger", 170.0)
			confirm.name = "ConfirmRemove"
			actions.add_child(confirm)
			var cancel := UI.button("CANCELAR", _cancel_remove, "normal", 170.0)
			cancel.name = "CancelRemove"
			actions.add_child(cancel)
		else:
			var remove := UI.button("REMOVER", _ask_remove.bind(String(id)), "normal", 170.0)
			remove.name = "Remove_" + String(id)
			actions.add_child(remove)
			var block := UI.button("BLOQUEAR", _block.bind(String(id)), "danger", 170.0)
			block.name = "Block_" + String(id)
			actions.add_child(block)
	var add := UI.detail_panel(side)
	add.add_child(UI.heading("ADICIONAR AMIGO", UI.MAGENTA))
	add.add_child(UI.label("NA SESSÃO PRIVADA", UI.BODY_SIZE, UI.WHITE))
	var peers := 0
	if session().is_connected_session():
		for entry: Dictionary in session().roster:
			if int(entry.peer) == int(session().peer_id) or not bool(entry.connected):
				continue
			peers += 1
			var line := UI.row(add, 8)
			var who := UI.label("Assento %d • %s" % [int(entry.peer), String(entry.name) if not String(entry.name).is_empty() else "sem nome"], UI.META_SIZE, UI.TEXT)
			line.add_child(who)
			var sent: bool = controller.social.sent.has(int(entry.peer))
			var ask := UI.button("ENVIADA" if sent else "PEDIR", _send_request.bind(int(entry.peer)), "quiet" if sent else "primary", 120.0)
			ask.name = "Ask_%d" % int(entry.peer)
			ask.disabled = sent
			line.add_child(ask)
	if peers == 0:
		add.add_child(UI.label("Entre numa sessão privada para pedir amizade aos participantes autorizados.", UI.META_SIZE, UI.DIM))
	UI.divider(add, UI.MAGENTA)
	add.add_child(UI.label("CONTATO LOCAL POR ID", UI.BODY_SIZE, UI.WHITE))
	id_field = UI.field("ID público (16 caracteres)", "", false, 24)
	id_field.name = "ContactId"
	add.add_child(id_field)
	contact_name_field = UI.field("Apelido do contato", "", false, 24)
	contact_name_field.name = "ContactName"
	add.add_child(contact_name_field)
	var local := UI.button("ADICIONAR CONTATO LOCAL", _add_contact)
	local.name = "AddContact"
	add.add_child(local)
	var draft := UI.button("GUARDAR SOLICITAÇÃO (RASCUNHO)", _draft_request, "quiet")
	draft.name = "DraftRequest"
	add.add_child(draft)
	var online := UI.button("ENVIAR PELA INTERNET", Callable(), "quiet")
	online.name = "OnlineRequest"
	online.disabled = not controller.social.online_accounts_available()
	add.add_child(online)
	add.add_child(UI.label("Envio pela internet exige servidor de contas, ainda não configurado. Nenhum pedido é simulado.", UI.META_SIZE, UI.DIM))


func _render_requests() -> void:
	var data: Dictionary = profile().data
	var list := scroll_body()
	list.add_child(UI.heading("RECEBIDAS"))
	if data.incoming.is_empty():
		list.add_child(UI.label("Nenhuma solicitação recebida. Pedidos chegam de participantes da sua sessão privada.", UI.META_SIZE, UI.DIM))
	for id: Variant in _sorted_keys(data.incoming):
		var entry: Dictionary = data.incoming[id]
		var card := UI.card(list, true)
		var line := UI.row(card, 14)
		line.add_child(UI.avatar(String(entry.get("avatar", "jhon")), 64.0))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(texts)
		texts.add_child(UI.label(String(entry.get("display_name", "")), UI.HEADING_SIZE, UI.WHITE))
		texts.add_child(UI.label("Pela sessão privada • %s • identidade declarada" % UI.local_time(String(entry.get("received_at", ""))), UI.META_SIZE, UI.DIM))
		var actions := UI.actions(card)
		var accept := UI.button("ACEITAR", _accept.bind(String(id)), "primary", 170.0)
		accept.name = "Accept_" + String(id)
		actions.add_child(accept)
		var decline := UI.button("RECUSAR", _decline.bind(String(id)), "normal", 170.0)
		decline.name = "Decline_" + String(id)
		actions.add_child(decline)
		var block := UI.button("BLOQUEAR", _block.bind(String(id)), "danger", 170.0)
		block.name = "BlockIncoming_" + String(id)
		actions.add_child(block)
	UI.spacer(list, 8)
	list.add_child(UI.heading("ENVIADAS"))
	var any_sent := false
	for peer: Variant in controller.social.sent:
		any_sent = true
		var entry: Dictionary = controller.social.sent[peer]
		var card := UI.card(list)
		card.add_child(UI.label("%s • assento %d" % [String(entry.get("name", "")) if not String(entry.get("name", "")).is_empty() else "Participante", int(peer)], UI.BODY_SIZE, UI.WHITE))
		card.add_child(UI.label("Entregue pela sessão privada atual • aguardando resposta", UI.META_SIZE, UI.CYAN))
		var actions := UI.actions(card)
		var cancel := UI.button("CANCELAR", _cancel_sent.bind(int(peer)), "normal", 170.0)
		cancel.name = "CancelSent_%d" % int(peer)
		actions.add_child(cancel)
	for id: Variant in _sorted_keys(data.requests):
		any_sent = true
		var entry: Dictionary = data.requests[id]
		var card := UI.card(list)
		var label_name := String(entry.get("display_name", ""))
		card.add_child(UI.label((label_name if not label_name.is_empty() else "ID " + format_id(String(id))), UI.BODY_SIZE, UI.WHITE))
		card.add_child(UI.label("Rascunho local • NÃO ENVIADO (requer servidor de contas)", UI.META_SIZE, UI.AMBER))
		var actions := UI.actions(card)
		var cancel := UI.button("CANCELAR", _cancel_draft.bind(String(id)), "normal", 170.0)
		cancel.name = "CancelDraft_" + String(id)
		actions.add_child(cancel)
	if not any_sent:
		list.add_child(UI.label("Nenhuma solicitação pendente.", UI.META_SIZE, UI.DIM))


func _render_blocked() -> void:
	var data: Dictionary = profile().data
	var columns := split_body(440.0)
	var list: VBoxContainer = columns[0]
	var side: VBoxContainer = columns[1]
	if data.blocked.is_empty():
		empty_state(list, "NINGUÉM BLOQUEADO", "Jogadores bloqueados não conseguem enviar solicitações para você neste aparelho.")
	for id: Variant in _sorted_keys(data.blocked):
		var entry: Variant = data.blocked[id]
		var known := String(entry.get("display_name", "")) if entry is Dictionary else ""
		var card := UI.card(list)
		card.add_child(UI.label(known if not known.is_empty() else "Jogador bloqueado", UI.HEADING_SIZE, UI.WHITE))
		card.add_child(UI.label("ID " + format_id(String(id)), UI.META_SIZE, UI.DIM))
		var actions := UI.actions(card)
		var unblock := UI.button("DESBLOQUEAR", _unblock.bind(String(id)), "normal", 200.0)
		unblock.name = "Unblock_" + String(id)
		actions.add_child(unblock)
	var add := UI.detail_panel(side)
	add.add_child(UI.heading("BLOQUEAR POR ID", UI.MAGENTA))
	block_field = UI.field("ID público (16 caracteres)", "", false, 24)
	block_field.name = "BlockId"
	add.add_child(block_field)
	var block := UI.button("BLOQUEAR", _block_typed, "danger")
	block.name = "BlockTyped"
	add.add_child(block)
	add.add_child(UI.label("O bloqueio vale neste aparelho: pedidos desse ID são descartados sem aviso ao remetente e ele sai dos amigos. Sem servidor de contas, não impede alguém de usar um código de convite que você enviou — para isso, revogue os convites na sessão.", UI.META_SIZE, UI.DIM))


static func format_id(id: String) -> String:
	if id.length() != 16:
		return id
	return "%s-%s-%s-%s" % [id.substr(0, 4), id.substr(4, 4), id.substr(8, 4), id.substr(12, 4)]


func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var left: Variant = values[a]
		var right: Variant = values[b]
		var a_name := String(left.get("display_name", "")) if left is Dictionary else ""
		var b_name := String(right.get("display_name", "")) if right is Dictionary else ""
		return a_name.naturalnocasecmp_to(b_name) < 0 if a_name != b_name else String(a) < String(b))
	return keys


func _copy_id() -> void:
	DisplayServer.clipboard_set(String(profile().data.public_id))
	notify("ID público copiado.", "ok")


func _rename() -> void:
	if profile().rename(name_field.text):
		refresh()
		notify("Nome público salvo.", "ok")
	else:
		notify("Digite um nome com caracteres visíveis (até 24).", "warn")


func _avatar(id: String) -> void:
	if profile().set_avatar(id):
		refresh()
		notify("Retrato atualizado.", "ok")
	else:
		notify("Não foi possível salvar o retrato.", "error")


func _privacy_requests(mode: String) -> void:
	var data: Dictionary = profile().data
	if profile().set_privacy(String(data.privacy.get("allow_invites", "friends")), false, mode):
		refresh()
		notify("Preferência de solicitações salva.", "ok")


func _privacy_invites(mode: String) -> void:
	if profile().set_privacy(mode, false):
		refresh()
		notify("Preferência de convites salva.", "ok")


func _add_contact() -> void:
	var id := LocalPlayerProfile.normalize_id(id_field.text)
	if id == String(profile().data.public_id):
		notify("Esse é o seu próprio ID.", "warn")
	elif profile().is_blocked(id):
		notify("Esse ID está bloqueado. Desbloqueie antes de adicionar.", "warn")
	elif profile().add_local_contact(id, contact_name_field.text):
		refresh()
		notify("Contato local adicionado (não verificado).", "ok")
	else:
		notify("ID inválido: use os 16 caracteres do ID público (0-9, a-f).", "error")


func _draft_request() -> void:
	var id := LocalPlayerProfile.normalize_id(id_field.text)
	if profile().request_contact(id, contact_name_field.text):
		refresh()
		notify("Rascunho guardado. Ele NÃO foi enviado: não há servidor de contas.", "warn")
	else:
		notify("ID inválido, próprio, bloqueado ou já é amigo.", "error")


func _send_request(peer: int) -> void:
	if controller.social.send_request(peer) != OK:
		notify("Não foi possível enviar: o participante precisa estar conectado à sessão.", "error")
	else:
		refresh()


func _accept(id: String) -> void:
	var message: String = controller.social.accept(id)
	refresh()
	notify(message, "ok" if message.begins_with("Aceito") else "error")


func _decline(id: String) -> void:
	notify(controller.social.decline(id), "info")
	refresh()


func _cancel_sent(peer: int) -> void:
	controller.social.cancel_sent(peer)
	refresh()


func _cancel_draft(id: String) -> void:
	if profile().cancel_request(id):
		refresh()
		notify("Rascunho cancelado.", "info")


func _ask_remove(id: String) -> void:
	pending_remove = id
	refresh()
	call_deferred("_focus_named", "CancelRemove")


func _cancel_remove() -> void:
	pending_remove = ""
	refresh()


func _remove(id: String) -> void:
	pending_remove = ""
	if profile().remove_contact(id):
		notify("Amigo removido.", "info")
	refresh()


func _block(id: String) -> void:
	if controller.social.block(id):
		refresh()
		notify("Jogador bloqueado neste aparelho.", "warn")
	else:
		notify("Não foi possível bloquear.", "error")


func _block_typed() -> void:
	var id := LocalPlayerProfile.normalize_id(block_field.text)
	if id == String(profile().data.public_id):
		notify("Você não pode bloquear o próprio ID.", "warn")
	elif controller.social.block(id):
		refresh()
		notify("ID bloqueado neste aparelho.", "warn")
	else:
		notify("ID inválido: use os 16 caracteres do ID público.", "error")


func _unblock(id: String) -> void:
	if profile().unblock(id):
		refresh()
		notify("Jogador desbloqueado.", "info")


func _focus_named(node_name: String) -> void:
	var target := body.find_child(node_name, true, false) as Control
	if target != null and target.is_visible_in_tree():
		target.grab_focus()


func _on_social_changed(message: String) -> void:
	if is_open():
		refresh()
		notify(message, "info")


func _tick(_delta: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		_update_counts()
