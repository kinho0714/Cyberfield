extends CanvasLayer
const TOUCH := preload("res://ui/touch_scroll_router.gd")
var controller: Node
var overlay: ColorRect
var rows: VBoxContainer
var title: Label
var display_name: LineEdit
var router: RefCounted
var pending_delete := ""


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.color = Color(0.015, 0.025, 0.05, 0.98)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	overlay.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	title = Label.new()
	title.text = "CAMPANHAS SOLO • OFFLINE"
	box.add_child(title)
	display_name = LineEdit.new()
	display_name.placeholder_text = "Nome da campanha"
	display_name.max_length = 80
	box.add_child(display_name)
	_button(box, "NOVA CAMPANHA INDEPENDENTE", _create)
	_button(box, "COPIAR PERFIL LEGADO PARA NOVA CAMPANHA", _import)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	_button(box, "VOLTAR", close)
	router = TOUCH.new(overlay)
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and event.pressed and display_name.get_global_rect().has_point(event.position):
		display_name.grab_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_show(display_name.text)
		get_viewport().set_input_as_handled()
		return
	if router.handle(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	controller.game.mode_select.visible = false
	visible = true
	pending_delete = ""
	_refresh()


func close() -> void:
	visible = false
	controller.game.mode_select.visible = true


func _refresh() -> void:
	for row in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	for summary: Dictionary in controller.store.list_campaigns():
		var id := String(summary.campaign_id)
		var label := Label.new()
		label.text = "%s • %s" % [summary.display_name, "RECUPERÁVEL / INTERROMPIDA" if summary.get("interrupted", false) else "SOLO"]
		if int(summary.get("recovery", {}).get("damaged_revisions", 0)) > 0:
			label.text += " • BACKUP ÍNTEGRO DISPONÍVEL"
		label.text += " • revisão %d" % int(summary.get("revision", 0))
		rows.add_child(label)
		if not summary.has("error"):
			_button(rows, "CONTINUAR", _continue.bind(id))
			_button(rows, "RENOMEAR COM O NOME DIGITADO", _rename.bind(id))
		else:
			var error := Label.new()
			error.text = controller.error_message(String(summary.error))
			rows.add_child(error)
		_button(rows, "CONFIRMAR EXCLUSÃO DESTE SLOT" if pending_delete == id else "EXCLUIR ESTE SLOT…", _delete.bind(id))


func _create() -> void:
	visible = false
	if not await controller.start_new(display_name.text if not display_name.text.strip_edges().is_empty() else "Campanha"):
		visible = true
		title.text = controller.error_message(controller.last_error)
		_refresh()


func _continue(id: String) -> void:
	visible = false
	if not await controller.continue_campaign(id):
		controller.game.mode_select.visible = false
		visible = true
		title.text = controller.error_message(controller.last_error)


func _rename(id: String) -> void:
	if not controller.store.rename_campaign(id, display_name.text):
		title.text = "Informe um nome válido e verifique o armazenamento."
	_refresh()


func _delete(id: String) -> void:
	if pending_delete != id:
		pending_delete = id
	else:
		if not controller.store.delete_campaign(id, pending_delete):
			title.text = "Não foi possível excluir o slot. Dados preservados."
		pending_delete = ""
	_refresh()


func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)


func _import() -> void:
	visible = false
	if not await controller.import_legacy(display_name.text if not display_name.text.strip_edges().is_empty() else "Perfil importado"):
		visible = true
		title.text = controller.error_message(controller.last_error)
		_refresh()
