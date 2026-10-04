extends CanvasLayer

const PANEL_PRESENTATION = preload("res://ui/menu_panel_presentation.gd")

var overlay: ColorRect
var slot_buttons: Array[Button] = []
var _blocked_players: Array[Node] = []
var _tree_paused := false
var _return_to_pause := false
var _close_button: Button

var _sidebar: PanelContainer
var _inventory_frame: PanelContainer
var _sidebar_buttons: Array[Button] = []
var _tabs: Array[Button] = []
var _equipment: HBoxContainer
var _summary: Label
var _details: Label
var _preview_index: int = 0
var _selected_tab := 0
var _backpack: Node
var _gadget_labels: Array[Label] = []


func _ready() -> void:
	add_to_group("inventory_ui")
	var run := get_parent().get_node("RunManager")
	_backpack = run.get_node_or_null("RunBackpack")
	if _backpack == null:
		_backpack = preload("res://scene/run_backpack.gd").new()
		_backpack.name = "RunBackpack"
		run.add_child(_backpack)
	run.state_changed.connect(_refresh_open_data)
	_backpack.cargo_changed.connect(_refresh_open_data)
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.005, 0.015, 0.035, 0.66)
	add_child(overlay)
	_sidebar = PanelContainer.new()
	_sidebar.add_theme_stylebox_override("panel", PANEL_PRESENTATION.style("pause/pause_side_panel", 18, 18))
	overlay.add_child(_sidebar)
	var navigation := VBoxContainer.new()
	navigation.add_theme_constant_override("separation", 10)
	_sidebar.add_child(navigation)
	_add_label(navigation, "PAUSA", 28)
	var actions: Array[String] = ["CONTINUAR", "INVENTÁRIO", "CONFIGURAÇÕES", "ABANDONAR RUN", "MENU PRINCIPAL"]
	for index in actions.size():
		var button := Button.new()
		button.text = actions[index]
		button.custom_minimum_size = Vector2(220, 56)
		button.add_theme_font_size_override("font_size", 18)
		PANEL_PRESENTATION.style_button(button)
		button.pressed.connect(_sidebar_action.bind(index))
		navigation.add_child(button)
		_sidebar_buttons.append(button)
	_inventory_frame = PanelContainer.new()
	_inventory_frame.minimum_size_changed.connect(func() -> void: call_deferred("_layout_inventory"))
	_inventory_frame.add_theme_stylebox_override("panel", PANEL_PRESENTATION.style("inventory/inventory_panel", 18, 22))
	overlay.add_child(_inventory_frame)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 16)
	_inventory_frame.add_child(panel)
	var header := HBoxContainer.new()
	panel.add_child(header)
	var title: Label = _add_label(header, "INVENTÁRIO", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var labels: Array[String] = ["EQUIPAMENTOS", "STATUS", "RUN", "MOCHILA"]
	for index in labels.size():
		var tab := Button.new()
		tab.text = labels[index]
		tab.custom_minimum_size = Vector2(104, 48)
		tab.add_theme_font_size_override("font_size", 15)
		PANEL_PRESENTATION.style_button(tab)
		tab.pressed.connect(_show_inventory_tab.bind(index))
		tab.gui_input.connect(_tab_touch.bind(tab, index))
		header.add_child(tab)
		_tabs.append(tab)
	_equipment = HBoxContainer.new()
	_equipment.add_theme_constant_override("separation", 22)
	panel.add_child(_equipment)
	var cards := VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 16)
	_equipment.add_child(cards)
	for index in 2:
		var button := Button.new()
		button.custom_minimum_size = Vector2(200, 128)
		button.pressed.connect(_select_slot.bind(index))
		button.focus_entered.connect(_preview_slot.bind(index))
		button.mouse_entered.connect(_preview_slot.bind(index))
		PANEL_PRESENTATION.style_inventory_slot(button)
		cards.add_child(button)
		slot_buttons.append(button)
	# Two reserved gadget slots; no gadget backend or fake equipment is created.
	for index in 2:
		var empty := _add_label(cards, tr("GADGET %d // VAZIO") % (index + 1), 16)
		empty.name = "Gadget%d" % index
		_gadget_labels.append(empty)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(320, 272)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", PANEL_PRESENTATION.style("inventory/detail_panel", 16, 18))
	_equipment.add_child(detail_panel)
	_details = _add_label(detail_panel, "", 20)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(280, 0)
	_summary = _add_label(panel, "", 22)
	_summary.custom_minimum_size = Vector2(0, 272)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_close_button = Button.new()
	_close_button.text = "VOLTAR"
	_close_button.custom_minimum_size = Vector2(0, 52)
	_close_button.pressed.connect(close_inventory)
	PANEL_PRESENTATION.style_button(_close_button)
	panel.add_child(_close_button)
	get_viewport().size_changed.connect(_layout_inventory)
	_layout_inventory()
	_show_inventory_tab(0)
	overlay.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_inventory") and not event.is_echo():
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif overlay.visible and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		close_inventory()
		get_viewport().set_input_as_handled()
	elif overlay.visible and event is InputEventScreenTouch and event.pressed:
		var touch_event := event as InputEventScreenTouch
		for index in _sidebar_buttons.size():
			if _touch_hits(_sidebar_buttons[index], touch_event.position):
				_sidebar_action(index)
				get_viewport().set_input_as_handled()
				return
		if _touch_hits(_close_button, touch_event.position):
			close_inventory()
			get_viewport().set_input_as_handled()
			return
		for index in slot_buttons.size():
			if _touch_hits(slot_buttons[index], touch_event.position) and not slot_buttons[index].disabled:
				_select_slot(index)
				get_viewport().set_input_as_handled()
				return


func toggle_inventory() -> void:
	if overlay.visible:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	var attribute_ui := get_tree().get_first_node_in_group("attribute_choice_ui")
	if attribute_ui != null and attribute_ui.visible:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or not room_manager.mode_selected or room_manager.is_transitioning:
		return
	var full_map := get_tree().get_first_node_in_group("full_map")
	if full_map != null and full_map.visible:
		full_map.close_map()
	var pause := get_tree().get_first_node_in_group("pause_menu")
	if pause != null and pause.overlay.visible:
		pause.close_menu()
	_block_local_players(room_manager)
	var lan_session: LanSession = room_manager.get_node("LanSession")
	if not lan_session.is_network_game():
		get_tree().paused = true
		_tree_paused = true
	room_manager.get_node("TouchControls").set_menu_blocked(true)
	overlay.visible = true
	_show_inventory_tab(0)
	_refresh()
	slot_buttons[0].grab_focus()


func open_from_pause() -> void:
	_return_to_pause = true
	open_inventory()


func close_inventory() -> void:
	if _tree_paused:
		get_tree().paused = false
		_tree_paused = false
	overlay.visible = false
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.get_node("TouchControls").set_menu_blocked(false)
	for player in _blocked_players:
		if is_instance_valid(player):
			player.set_input_enabled(true)
	_blocked_players.clear()
	if _return_to_pause:
		_return_to_pause = false
		var pause := get_tree().get_first_node_in_group("pause_menu")
		if pause != null:
			pause.open_menu()


func _select_slot(index: int) -> void:
	var player := _local_player()
	if player != null and not player.equipped_weapons[index].is_empty():
		player.active_weapon_slot = index
		_refresh()


func _refresh() -> void:
	var player := _local_player()
	if player == null:
		return
	for index in 2:
		var weapon_id: StringName = player.equipped_weapons[index]
		if weapon_id.is_empty():
			slot_buttons[index].icon = null
			slot_buttons[index].text = tr("SLOT %d // VAZIO") % (index + 1)
			slot_buttons[index].disabled = true
			continue
		var data := WeaponCatalog.get_definition(weapon_id)
		slot_buttons[index].icon = WeaponCatalog.get_visual_texture(weapon_id, "inventory_icon")
		slot_buttons[index].disabled = false
		PANEL_PRESENTATION.mark_equipped(slot_buttons[index], player.active_weapon_slot == index)
		slot_buttons[index].text = "%sSLOT %d\n%s\n%s" % ["▶ " if player.active_weapon_slot == index else "", index + 1, tr(data.name), tr(String(data.type).to_upper())]
	_preview_slot(_preview_index)



func _local_player() -> Node:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null:
		return null
	var lan: LanSession = room_manager.get_node("LanSession")
	for player in room_manager.get_players():
		if not lan.is_network_game() or player.participant_id == lan.get_local_participant_id():
			return player
	return null


func _block_local_players(room_manager: Node) -> void:
	_blocked_players.clear()
	var local := _local_player()
	if local != null and local.input_enabled:
		local.set_input_enabled(false)
		_blocked_players.append(local)


func _touch_hits(control: Control, position: Vector2) -> bool:
	return control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(position)


func _add_label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e5f4ff"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _layout_inventory() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_sidebar.position = Vector2(32, maxf(24, (screen.y - 402) * 0.5))
	_sidebar.size = Vector2(256, 402)
	var height := maxf(464, _inventory_frame.get_combined_minimum_size().y)
	_inventory_frame.position = Vector2(332, maxf(24, (screen.y - height) * 0.5))
	_inventory_frame.size = Vector2(maxf(740, screen.x - 364), height)


func _preview_slot(index: int) -> void:
	_preview_index = index
	var player := _local_player()
	if player == null or player.equipped_weapons[index].is_empty():
		_details.text = tr("SLOT %d\n\nVAZIO") % (index + 1)
		return
	var data := WeaponCatalog.get_definition(player.equipped_weapons[index])
	_details.text = "%s\n%s\n\n%s  %d\n%s  %.2fs\n%s  %s\n\n%s" % [tr(data.name), tr(String(data.rarity).to_upper()), tr("DANO"), data.damage, tr("RECARGA"), data.cooldown, tr("TIPO"), tr(String(data.type).to_upper()), tr("EQUIPADO") if player.active_weapon_slot == index else tr("Ative o slot para equipar.")]


func _show_inventory_tab(index: int) -> void:
	_selected_tab = index
	call_deferred("_layout_inventory")
	_equipment.visible = index == 0
	_summary.visible = index != 0
	for n in _tabs.size():
		PANEL_PRESENTATION.set_button_normal(_tabs[n], PANEL_PRESENTATION.style("inventory/tab_selected" if n == index else "inventory/tab_normal", 8, 8))
		for state in ["hover", "pressed"]:
			_tabs[n].add_theme_stylebox_override(state, PANEL_PRESENTATION.style("inventory/tab_selected", 8, 8))
	var player := _local_player()
	if index == 1 and player != null:
		_summary.text = "%s\n\n%s  %d / %d\n%s  %d\n%s  %d\n%s  %d\n%s  %d / %d" % [tr("STATUS"), tr("VIDA"), player.health, player.max_health, tr("SAÚDE"), player.health_attribute, tr("INTELIGÊNCIA"), player.intellect, tr("FORÇA"), player.strength, tr("DOSES"), player.heal_doses, player.max_heal_doses]
	elif index == 2:
		var hud := get_parent().get_node_or_null("RunDebugHUD")
		var run := get_parent().get_node_or_null("RunManager")
		_summary.text = "RUN\n\n" + (hud.get_session_summary() if hud != null else "")
		if run != null:
			_summary.text += "\n%s  %s\n%s  %d" % [tr("TEMPO"), run.format_run_time(), tr("DINHEIRO"), run.dirty_money]
	elif index == 3:
		_summary.text = tr("MOCHILA") + "\n\n"
		if player != null:
			var cargo: Dictionary = _backpack.snapshot(player.participant_id)
			_summary.text += "%s  %d\n\n" % [tr("DINHEIRO SUJO (EQUIPE)"), cargo.team_dirty_money]
			for item: Dictionary in cargo.items:
				_summary.text += "%s × %d\n" % [tr(String(item.get("name_key", item.get("id", "")))), int(item.get("quantity", 0))]
			if cargo.items.is_empty():
				_summary.text += tr("Nenhum item carregado.")
		_summary.text += "\n\n" + tr("Carga temporária da operação.")


func _refresh_open_data() -> void:
	if overlay != null and overlay.visible:
		_refresh()
		_show_inventory_tab(_selected_tab)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
		_show_inventory_tab(_selected_tab)
		for index in 2:
			_gadget_labels[index].text = tr("GADGET %d // VAZIO") % (index + 1)


func _tab_touch(event: InputEvent, button: Button, index: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_show_inventory_tab(index)
		button.grab_focus()
		button.accept_event()


func _sidebar_action(index: int) -> void:
	if index == 1:
		_show_inventory_tab(0)
		return
	_return_to_pause = false
	close_inventory()
	var pause := get_tree().get_first_node_in_group("pause_menu")
	if pause == null:
		return
	if index == 2:
		pause.open_menu()
		pause._show_settings()
	elif index == 3:
		pause._abandon_run()
	elif index == 4:
		pause._return_to_main_menu()
