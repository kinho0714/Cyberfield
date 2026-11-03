extends CanvasLayer
const TOUCH := preload("res://ui/touch_scroll_router.gd")
const PRESENTATION := preload("res://ui/menu_panel_presentation.gd")
var controller: Node
var overlay: ColorRect
var rows: VBoxContainer
var title: Label
var hub_button: Button
var router: RefCounted
var was_paused := false
var name_input: LineEdit
var contact_input: LineEdit
var contact_name: LineEdit
var endpoint_input: LineEdit
var room_input: LineEdit
var token_input: LineEdit
var connection_label: Label


func _ready() -> void:
	layer = 38
	process_mode = Node.PROCESS_MODE_ALWAYS
	hub_button = Button.new()
	hub_button.text = "MUNDO / SESSÃO"
	hub_button.position = Vector2(20, 52)
	hub_button.custom_minimum_size = Vector2(190, 44)
	PRESENTATION.style_button(hub_button)
	add_child(hub_button)
	hub_button.pressed.connect(open)
	overlay = ColorRect.new()
	overlay.color = Color(0.015, 0.025, 0.05, 0.98)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	overlay.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	margin.add_child(box)
	title = Label.new()
	box.add_child(title)
	button(box, "MUNDO", show_world)
	button(box, "PERFIL / AMIGOS LOCAIS", show_profile)
	button(box, "COOP PRIVADO • CONEXÃO", show_private)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	button(box, "VOLTAR", close)
	router = TOUCH.new(overlay)
	overlay.visible = false


func _process(_delta: float) -> void:
	if is_instance_valid(connection_label):
		connection_label.text = "Conexão: %s • revisão %d • %d/4" % [controller.private_session.status, int(controller.private_session.revision), controller.private_session.lobby.get("connected", []).size()]
	hub_button.visible = controller.game.mode_selected and controller.game.current_is_hub and not controller.active.is_empty() and not overlay.visible and not get_tree().paused


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		if hub_button.visible and event is InputEventScreenTouch and event.pressed and hub_button.get_global_rect().has_point(event.position):
			open()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and event.pressed:
		for field in overlay.find_children("*", "LineEdit", true, false):
			if field.is_visible_in_tree() and field.get_global_rect().has_point(event.position):
				field.grab_focus()
				if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
					DisplayServer.virtual_keyboard_show(field.text)
				get_viewport().set_input_as_handled()
				return
	if router.handle(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	controller.save_now()
	was_paused = get_tree().paused
	get_tree().paused = true
	controller.game._set_all_player_input(false)
	controller.game.mode_select.visible = false
	add_to_group("meta_lab_ui")
	overlay.visible = true
	if controller.active.is_empty():
		show_profile()
	else:
		show_world()


func close() -> void:
	overlay.visible = false
	remove_from_group("meta_lab_ui")
	get_tree().paused = was_paused
	controller.game.mode_select.visible = not controller.game.mode_selected
	if controller.game.mode_selected and not was_paused:
		controller.game._set_all_player_input(true)


func clear() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()


func show_world() -> void:
	clear()
	title.text = "MUNDO CONHECIDO • SOLO OFFLINE"
	if controller.active.is_empty():
		label("Selecione ou crie uma campanha para explorar regiões.")
		return
	for location: Dictionary in controller.geography.known_regions():
		label("%s • %s [%s]" % [location.kind, location.display_name, location.narrative_status])
		if location.kind == "neighborhood" and location.implementation == "implemented":
			button(rows, "EXPLORAR NA PRÓXIMA RUN", _choose.bind(String(location.id)))
	label("Intervalo de autosave: %d s" % int(controller.autosave_seconds))
	for seconds in [15, 30, 60]:
		button(rows, "AUTOSAVE %d s" % seconds, _interval.bind(float(seconds)))


func _choose(id: String) -> void:
	title.text = "Região selecionada para a próxima run." if controller.geography.choose_region(id) else "Não foi possível selecionar esta região."


func _interval(seconds: float) -> void:
	if controller.set_autosave_interval(seconds):
		show_world()
	else:
		title.text = controller.error_message(controller.last_error)


func label(text: String) -> void:
	var item: Label = Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(item)


func button(parent: Node, text: String, action: Callable) -> void:
	var item: Button = Button.new()
	item.text = text
	item.custom_minimum_size.y = 44
	PRESENTATION.style_button(item)
	item.pressed.connect(action)
	parent.add_child(item)


func is_open() -> bool:
	return overlay != null and overlay.visible


func field(placeholder: String, value: String = "", secret := false) -> LineEdit:
	var item: LineEdit = LineEdit.new()
	item.placeholder_text = placeholder
	item.text = value
	item.secret = secret
	item.max_length = 256
	item.custom_minimum_size.y = 44
	rows.add_child(item)
	return item


func show_profile() -> void:
	clear()
	title.text = "PERFIL LOCAL • OFFLINE • SEM AUTENTICAÇÃO ONLINE"
	if not controller.profile.initialize():
		label("Perfil indisponível. Os arquivos existentes foram preservados.")
		return
	var profile: Node = controller.profile
	label("Identificador público local: " + String(profile.data.public_id))
	label("Contatos e solicitações abaixo são locais e não verificados. Nenhum convite foi enviado pela internet.")
	name_input = field("Nome público", String(profile.data.display_name))
	button(rows, "SALVAR NOME", _rename_profile)
	contact_input = field("ID público local do contato (16 caracteres hexadecimais)")
	contact_name = field("Nome do contato")
	button(rows, "ADICIONAR CONTATO LOCAL", _add_contact)
	button(rows, "REGISTRAR SOLICITAÇÃO LOCAL (NÃO ENVIADA)", _request_contact)
	button(rows, "CONVITES: SOMENTE AMIGOS • PRESENÇA PRIVADA", _privacy.bind("friends"))
	button(rows, "NÃO PERMITIR CONVITES", _privacy.bind("none"))
	for id: Variant in profile.data.friends:
		label("%s • %s • local não verificado" % [profile.data.friends[id].display_name, id])
		button(rows, "REMOVER CONTATO", _remove_contact.bind(String(id)))
		button(rows, "BLOQUEAR CONTATO", _block.bind(String(id)))
	for id: Variant in profile.data.requests:
		label("Solicitação local pendente: " + String(id))
	for id: Variant in profile.data.blocked:
		label("Bloqueado localmente: " + String(id))
		button(rows, "DESBLOQUEAR", _unblock.bind(String(id)))


func _rename_profile() -> void:
	if controller.profile.rename(name_input.text):
		show_profile()
	else:
		title.text = "Nome inválido ou falha ao salvar o perfil."


func _add_contact() -> void:
	if controller.profile.add_local_contact(contact_input.text.strip_edges(), contact_name.text):
		show_profile()
	else:
		title.text = "ID inválido, próprio ou bloqueado; ou falha de armazenamento."


func _request_contact() -> void:
	if controller.profile.request_contact(contact_input.text.strip_edges()):
		show_profile()
	else:
		title.text = "Não foi possível registrar esta solicitação local."


func _remove_contact(id: String) -> void:
	controller.profile.remove_contact(id)
	show_profile()


func _block(id: String) -> void:
	controller.profile.block(id)
	show_profile()


func _unblock(id: String) -> void:
	controller.profile.unblock(id)
	show_profile()


func _privacy(invites: String) -> void:
	controller.profile.set_privacy(invites, false)
	show_profile()


func show_private() -> void:
	clear()
	title.text = "COOP PRIVADO • PROTÓTIPO WSS"
	label("Transporte e lobby em validação. Gameplay ainda não sincronizado. Nenhum servidor público foi configurado.")
	connection_label = Label.new()
	rows.add_child(connection_label)
	endpoint_input = field("Endpoint wss:// do serviço de jogo", controller.private_session.endpoint)
	room_input = field("ID da sessão privada", controller.private_session.room_id)
	token_input = field("Convite ou chave do proprietário (não será salvo)", "", true)
	button(rows, "ENTRAR COM CONVITE PRIVADO", _connect_private.bind("join"))
	button(rows, "CRIAR SESSÃO (CHAVE DO PROPRIETÁRIO)", _connect_private.bind("create"))
	button(rows, "VALIDAR QUATRO CONEXÕES • SEM INICIAR GAMEPLAY", _start_private)
	button(rows, "SALVAR ESTADO RECEBIDO E DESCONECTAR", _leave_private)
	button(rows, "ATUALIZAR INFORMAÇÕES", show_private)
	if not controller.private_session.room_id.is_empty():
		label("Sessão: " + controller.private_session.room_id)
	for index in controller.private_session.invitations.size():
		button(rows, "COPIAR CONVITE PRIVADO %d (EXPIRA EM ATÉ 10 MIN)" % (index + 1), _copy_invite.bind(index))
	if not controller.private_session.last_error.is_empty():
		label("Conexão indisponível ou rejeitada: verifique endpoint, autorização e validade do convite. Backups recebidos preservados.")


func _connect_private(operation: String) -> void:
	var shared_id: String = Crypto.new().generate_random_bytes(16).hex_encode() if operation == "create" else ""
	var result: Error = controller.private_session.connect_session(endpoint_input.text.strip_edges(), operation, token_input.text.strip_edges(), room_input.text.strip_edges(), shared_id)
	token_input.clear()
	if result != OK:
		title.text = "Não foi possível conectar. Use wss:// e um convite/chave válido."


func _start_private() -> void:
	if controller.private_session.start_session() != OK:
		title.text = "Conecte-se primeiro. A sessão exige exatamente quatro conexões autorizadas."


func _leave_private() -> void:
	controller.private_session.leave()
	show_private()


func _copy_invite(index: int) -> void:
	if index >= 0 and index < controller.private_session.invitations.size():
		DisplayServer.clipboard_set(controller.private_session.invitations[index])
		title.text = "Convite copiado. Compartilhe somente com o convidado; limpe a área de transferência após o uso."
