extends "res://ui/cyber_modal.gd"
## Campanhas solo (03/11): lista de slots em cartões + painel de detalhe e aba de criação.
## Só interface: toda gravação continua em CampaignStore/CampaignController (formato intacto).
const WORLD := preload("res://scene/world/world_state.gd")
const STORE := preload("res://scene/persistence/campaign_store.gd")
var controller: Node
var selected_id := ""
var pending_delete := ""
var viewing_world := false
var name_field: LineEdit
var rename_field: LineEdit
var _summaries: Array[Dictionary] = []


func _build() -> void:
	layer = 96
	title_label.text = "CAMPANHA SOLO"
	subtitle_label.text = "Progresso salvo neste aparelho • cada slot é independente"
	set_status("OFFLINE", UI.DIM)
	add_tab("slots", "CAMPANHAS")
	add_tab("create", "NOVA CAMPANHA")


## Compatível com a API anterior: abre a lista de campanhas.
func open(tab := "slots") -> void:
	controller.game.mode_select.visible = false
	pending_delete = ""
	viewing_world = false
	_reload()
	if tab == "slots" and _summaries.is_empty():
		tab = "create"
	show_modal(tab, not controller.game.mode_selected)


func close() -> void:
	if busy:
		return
	hide_modal()
	closed.emit()
	if not controller.game.mode_selected:
		controller.game.mode_select.return_to(&"solo", &"Manage" if current_tab == "slots" else &"Create")


func _reload() -> void:
	_summaries = controller.store.list_campaigns()
	var found := false
	for summary in _summaries:
		found = found or String(summary.campaign_id) == selected_id
	if not found:
		selected_id = String(_summaries[0].campaign_id) if not _summaries.is_empty() else ""
	(tabs["slots"] as Button).text = "CAMPANHAS (%d)" % _summaries.size()


func _render(tab: String) -> void:
	if tab == "create":
		_render_create()
	elif viewing_world:
		_render_world()
	else:
		_render_slots()


func _render_slots() -> void:
	if _summaries.is_empty():
		var list := scroll_body()
		empty_state(list, "NENHUMA CAMPANHA SALVA", "Crie uma campanha na aba NOVA CAMPANHA. O progresso fica neste aparelho e não exige conta.")
		return
	var columns := split_body(430.0)
	var list: VBoxContainer = columns[0]
	var side: VBoxContainer = columns[1]
	for index in _summaries.size():
		_slot_card(list, index, _summaries[index])
		if String(_summaries[index].campaign_id) == selected_id:
			_detail(side, index, _summaries[index])


func _slot_card(list: VBoxContainer, index: int, summary: Dictionary) -> void:
	var id := String(summary.campaign_id)
	var is_selected := id == selected_id
	var item := Button.new()
	item.name = "Slot_%02d" % (index + 1)
	item.custom_minimum_size = Vector2(0, 92)
	item.focus_mode = Control.FOCUS_ALL
	UI.PRESENTATION.style_button(item)
	var surface := UI.PRESENTATION.style("inventory/slot_selected" if is_selected else "inventory/slot_normal", 10, 14)
	UI.PRESENTATION.set_button_normal(item, surface)
	item.add_theme_stylebox_override("hover", UI.PRESENTATION.style("inventory/slot_selected", 10, 14))
	item.add_theme_stylebox_override("pressed", UI.PRESENTATION.style("inventory/slot_selected", 10, 14))
	item.pressed.connect(_select.bind(id))
	list.add_child(item)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(margin)
	var line := UI.row(margin, 16)
	var slot_label := UI.label("SLOT\n%02d" % (index + 1), UI.META_SIZE, UI.MAGENTA if is_selected else UI.DIM, false)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.custom_minimum_size.x = 52
	line.add_child(slot_label)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 2)
	line.add_child(texts)
	var title := UI.label(String(summary.display_name), UI.HEADING_SIZE, UI.WHITE, false)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(title)
	texts.add_child(UI.label(_state_line(summary), UI.META_SIZE, _state_color(summary), false))
	texts.add_child(UI.label("Último jogo: " + UI.local_time(String(summary.get("last_played_at", ""))), UI.META_SIZE, UI.DIM, false))


func _detail(side: VBoxContainer, index: int, summary: Dictionary) -> void:
	var id := String(summary.campaign_id)
	var box := UI.detail_panel(side)
	box.add_child(UI.label("SLOT %02d" % (index + 1), UI.META_SIZE, UI.MAGENTA, false))
	box.add_child(UI.label(String(summary.display_name), UI.HEADING_SIZE, UI.WHITE))
	if summary.has("error"):
		box.add_child(UI.label(controller.error_message(String(summary.error)), UI.BODY_SIZE, UI.RED))
		box.add_child(UI.label("Os arquivos deste slot foram preservados no aparelho.", UI.META_SIZE, UI.DIM))
	else:
		var progress: Dictionary = summary.get("progress", {})
		box.add_child(UI.label(_state_line(summary), UI.BODY_SIZE, _state_color(summary)))
		for text in _progress_lines(summary, progress):
			box.add_child(UI.label(text, UI.META_SIZE, UI.TEXT))
		var main_actions := UI.row(box, 8)
		var play := UI.button("CONTINUAR", _continue.bind(id), "primary")
		play.name = "Continue"
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_actions.add_child(play)
		var world := UI.button("MUNDO", _show_world.bind(id))
		world.name = "World"
		world.custom_minimum_size.x = 130
		main_actions.add_child(world)
		UI.divider(box, UI.MAGENTA)
		var rename_row := UI.row(box, 8)
		rename_field = UI.field("Novo nome", String(summary.display_name), false, 40)
		rename_field.name = "RenameField"
		rename_field.text_submitted.connect(func(_text: String) -> void: _rename(id))
		rename_row.add_child(rename_field)
		var rename := UI.button("RENOMEAR", _rename.bind(id), "normal", 150.0)
		rename.name = "Rename"
		rename_row.add_child(rename)
	UI.divider(box, UI.MAGENTA)
	if pending_delete == id:
		box.add_child(UI.label("Excluir \"%s\"? O slot sai da lista; os arquivos ficam arquivados no aparelho." % String(summary.display_name), UI.META_SIZE, UI.AMBER))
		var actions := UI.row(box, 8)
		var confirm := UI.button("CONFIRMAR", _delete.bind(id), "danger")
		confirm.name = "ConfirmDelete"
		confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(confirm)
		var cancel := UI.button("CANCELAR", _cancel_delete)
		cancel.name = "CancelDelete"
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(cancel)
	else:
		var remove := UI.button("EXCLUIR SLOT…", _delete.bind(id), "danger")
		remove.name = "Delete"
		box.add_child(remove)


func _state_line(summary: Dictionary) -> String:
	if summary.has("error"):
		return "SAVE INDISPONÍVEL"
	var progress: Dictionary = summary.get("progress", {})
	var place := "NO HUB" if bool(progress.get("in_hub", true)) else "EM EXPEDIÇÃO • ESTÁGIO %d" % int(progress.get("stage", 1))
	if not bool(progress.get("has_session", false)):
		place = "NOVA"
	var parts: Array[String] = [place]
	if bool(summary.get("interrupted", false)):
		parts.append("RETOMADA AUTOMÁTICA")
	if int(summary.get("recovery", {}).get("damaged_revisions", 0)) > 0:
		parts.append("BACKUP ÍNTEGRO EM USO")
	return " • ".join(parts)


func _state_color(summary: Dictionary) -> Color:
	if summary.has("error"):
		return UI.RED
	if int(summary.get("recovery", {}).get("damaged_revisions", 0)) > 0:
		return UI.AMBER
	return UI.CYAN


func _progress_lines(summary: Dictionary, progress: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var biome := String(progress.get("biome", ""))
	if not bool(progress.get("in_hub", true)) and not biome.is_empty():
		lines.append("Bioma: " + biome)
	lines.append("Créditos %d • Sucata %d • Casa nível %d" % [int(progress.get("credits", 0)), int(progress.get("scrap", 0)), int(progress.get("house_stage", 0))])
	lines.append("Expedições %d • Salas exploradas %d" % [int(progress.get("runs", 0)), int(progress.get("rooms", 0))])
	lines.append("Criada em %s • último jogo %s" % [UI.local_time(String(summary.get("created_at", ""))).left(10), UI.local_time(String(summary.get("last_played_at", "")))])
	return lines


func _render_create() -> void:
	var list := scroll_body()
	var box := UI.card(list, true)
	box.add_child(UI.heading("NOVA CAMPANHA INDEPENDENTE"))
	box.add_child(UI.label("Começa do zero, em um slot próprio. Dificuldade NORMAL • solo • offline.", UI.META_SIZE, UI.DIM))
	name_field = UI.field("Nome da campanha", "", false, 40)
	name_field.name = "NameField"
	name_field.text_submitted.connect(func(_text: String) -> void: _create())
	box.add_child(name_field)
	var actions := UI.actions(box)
	var create := UI.button("CRIAR E JOGAR", _create, "primary", 260.0)
	create.name = "Create"
	actions.add_child(create)
	var legacy := UI.card(list)
	legacy.add_child(UI.heading("IMPORTAR PERFIL CLÁSSICO", UI.TEXT))
	legacy.add_child(UI.label("Copia o progresso da PARTIDA AVULSA para uma nova campanha. O perfil original não é alterado.", UI.META_SIZE, UI.DIM))
	var legacy_actions := UI.actions(legacy)
	var import := UI.button("IMPORTAR PARA NOVO SLOT", _import, "normal", 300.0)
	import.name = "Import"
	legacy_actions.add_child(import)


func _render_world() -> void:
	var list := scroll_body()
	var campaign: Dictionary = controller.store.load_campaign(selected_id)
	if campaign.is_empty() or not campaign.has("world"):
		empty_state(list, "MUNDO AINDA NÃO REGISTRADO", "Continue a campanha para registrar regiões descobertas.")
	else:
		list.add_child(UI.heading("MUNDO CONHECIDO • " + String(campaign.display_name)))
		var view: Dictionary = WORLD.public_view(campaign.world)
		for location: Dictionary in view.locations:
			var card := UI.card(list)
			card.add_child(UI.label(String(location.display_name), UI.BODY_SIZE, UI.WHITE))
			card.add_child(UI.label("%s • %s" % [UI.location_kind(String(location.kind)), UI.narrative_status(String(location.narrative_status))], UI.META_SIZE, UI.DIM))
		list.add_child(UI.label("Salas registradas: %d" % campaign.world.exploration.size(), UI.META_SIZE, UI.TEXT))
	var back := UI.button("VOLTAR ÀS CAMPANHAS", _leave_world, "primary", 300.0)
	back.name = "LeaveWorld"
	list.add_child(back)


func _select(id: String) -> void:
	if selected_id != id:
		pending_delete = ""
	selected_id = id
	refresh()
	call_deferred("_focus_named", "Continue")


func _focus_named(node_name: String) -> void:
	var target := body.find_child(node_name, true, false) as Control
	if target != null and target.is_visible_in_tree():
		target.grab_focus()


func _create() -> void:
	if busy:
		return
	var display_name := UI.clean_name(name_field.text, 40) if name_field != null else ""
	if display_name.is_empty():
		display_name = "Campanha %d" % (_summaries.size() + 1)
	hide_modal()
	busy = true
	var started: bool = await controller.start_new(display_name)
	busy = false
	if not started:
		_reopen_with_error("create")


func _continue(id: String) -> void:
	if busy:
		return
	hide_modal()
	busy = true
	var restored: bool = await controller.continue_campaign(id)
	busy = false
	if not restored:
		_reopen_with_error("slots")


func _import() -> void:
	if busy:
		return
	var display_name := UI.clean_name(name_field.text, 40) if name_field != null else ""
	hide_modal()
	busy = true
	var imported: bool = await controller.import_legacy(display_name if not display_name.is_empty() else "Perfil importado")
	busy = false
	if not imported:
		_reopen_with_error("create")


func _reopen_with_error(tab: String) -> void:
	controller.game.mode_select.visible = false
	_reload()
	show_modal(tab, not controller.game.mode_selected)
	notify(controller.error_message(controller.last_error), "error")


func _rename(id: String) -> void:
	var display_name := UI.clean_name(rename_field.text, 40) if rename_field != null else ""
	if display_name.is_empty():
		notify("Digite um nome com pelo menos um caractere visível.", "warn")
		return
	if controller.store.rename_campaign(id, display_name):
		_reload()
		refresh()
		notify("Nome salvo.", "ok")
	else:
		notify("Não foi possível renomear. O save anterior foi preservado.", "error")


func _delete(id: String) -> void:
	if pending_delete != id:
		pending_delete = id
		refresh()
		call_deferred("_focus_named", "CancelDelete")
		notify("Confirme a exclusão do slot.", "warn")
		return
	if controller.store.delete_campaign(id, pending_delete):
		notify("Slot excluído da lista e arquivado no aparelho.", "ok")
		selected_id = ""
	else:
		notify("Não foi possível excluir. Os dados foram preservados.", "error")
	pending_delete = ""
	_reload()
	if _summaries.is_empty():
		select_tab("create")
	else:
		refresh()
		call_deferred("focus_first")


func _cancel_delete() -> void:
	pending_delete = ""
	refresh()
	notify("Exclusão cancelada.", "info")
	call_deferred("_focus_named", "Delete")


func _show_world(id: String) -> void:
	selected_id = id
	viewing_world = true
	refresh()
	call_deferred("_focus_named", "LeaveWorld")


func _leave_world() -> void:
	viewing_world = false
	refresh()
	call_deferred("_focus_named", "World")


func select_tab(id: String) -> void:
	if id != "slots":
		viewing_world = false
	super.select_tab(id)
