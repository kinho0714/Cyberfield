class_name MetaLabUI
extends CanvasLayer

const PANEL_PRESENTATION = preload("res://ui/menu_panel_presentation.gd")

var overlay: ColorRect
var credits_label: Label
var stats_label: Label
var purchase_buttons: Dictionary = {}
var blueprint_buttons: Dictionary = {}
var close_button: Button
var _blueprint_heading: Label
var blocked_player: Node
## 01/11/2026: bancada de fabricação (arsenal + cyberware + acessórios ativos).
var equipment_root: VBoxContainer
var scrap_label: Label
var craft_rarity: StringName = &"common"
var _equipment_buttons: Array[Button] = []


func _ready() -> void:
	add_to_group("meta_lab_ui")
	layer = 88
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.003, 0.012, 0.029, 0.97)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(670, 560)
	panel.add_theme_stylebox_override("panel", PANEL_PRESENTATION.style("inventory/inventory_panel", 20, 16))
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(0, 525)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 26)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var overline := Label.new()
	overline.text = "CYBERFIELD  //  BANCADA DE PREPARAÇÃO"
	overline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overline.add_theme_font_size_override("font_size", 15)
	overline.add_theme_color_override("font_color", Color("5fe5f3"))
	column.add_child(overline)
	var title := Label.new()
	title.text = "OFICINA DE OPERAÇÕES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	credits_label = Label.new()
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.add_theme_font_size_override("font_size", 22)
	column.add_child(credits_label)
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(stats_label)
	var research := Label.new()
	research.text = "PESQUISAS  //  MELHORIAS E LICENÇAS PERMANENTES"
	research.add_theme_font_size_override("font_size", 16)
	research.add_theme_color_override("font_color", Color("94dce8"))
	column.add_child(research)
	for item_value: Variant in MetaProgression.PURCHASES:
		var item_id := StringName(item_value)
		var button := Button.new()
		button.custom_minimum_size = Vector2(570, 60)
		PANEL_PRESENTATION.style_button(button)
		button.pressed.connect(_purchase.bind(item_id))
		column.add_child(button)
		purchase_buttons[item_id] = button
	_blueprint_heading = Label.new()
	_blueprint_heading.text = "PROJETOS RECUPERADOS  //  BLUEPRINTS"
	_blueprint_heading.add_theme_font_size_override("font_size", 16)
	_blueprint_heading.add_theme_color_override("font_color", Color("94dce8"))
	column.add_child(_blueprint_heading)
	for weapon_value: Variant in WeaponCatalog.WEAPONS:
		var weapon_id := StringName(weapon_value)
		var blueprint_button := Button.new()
		blueprint_button.custom_minimum_size = Vector2(570, 52)
		blueprint_button.icon = WeaponCatalog.get_visual_texture(weapon_id, "inventory_icon")
		blueprint_button.expand_icon = false
		PANEL_PRESENTATION.style_button(blueprint_button)
		blueprint_button.pressed.connect(_study_blueprint.bind(weapon_id))
		column.add_child(blueprint_button)
		blueprint_buttons[weapon_id] = blueprint_button
	scrap_label = Label.new()
	scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scrap_label.add_theme_font_size_override("font_size", 20)
	scrap_label.add_theme_color_override("font_color", Color("ffb347"))
	column.add_child(scrap_label)
	equipment_root = VBoxContainer.new()
	equipment_root.name = "EquipmentBench"
	equipment_root.add_theme_constant_override("separation", 6)
	column.add_child(equipment_root)
	close_button = Button.new()
	close_button.text = "VOLTAR AO LABORATÓRIO"
	close_button.custom_minimum_size = Vector2(570, 54)
	PANEL_PRESENTATION.style_button(close_button)
	close_button.pressed.connect(close_terminal)
	column.add_child(close_button)
	overlay.visible = false


func open_terminal(player: Node) -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or not room_manager.current_is_hub or overlay.visible:
		return
	blocked_player = player
	if blocked_player != null and bool(blocked_player.get("input_enabled")):
		blocked_player.set_input_enabled(false)
	room_manager.get_node("TouchControls").set_menu_blocked(true)
	overlay.visible = true
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null:
		audio.play_event(&"ui_open")
	_refresh()
	close_button.grab_focus()


func close_terminal() -> void:
	overlay.visible = false
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null:
		audio.play_event(&"ui_close")
	get_viewport().gui_release_focus()
	if is_instance_valid(blocked_player):
		blocked_player.set_input_enabled(true)
	blocked_player = null
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.get_node("TouchControls").set_menu_blocked(false)


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		close_terminal()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		var position := (event as InputEventScreenTouch).position
		if close_button.get_global_rect().has_point(position):
			close_terminal()
			get_viewport().set_input_as_handled()
			return
		for item_value: Variant in purchase_buttons:
			var button := purchase_buttons[item_value] as Button
			if button.get_global_rect().has_point(position) and not button.disabled:
				_purchase(StringName(item_value))
				get_viewport().set_input_as_handled()
				return
		for blueprint_value: Variant in blueprint_buttons:
			var blueprint_button := blueprint_buttons[blueprint_value] as Button
			if blueprint_button.visible and blueprint_button.get_global_rect().has_point(position) and not blueprint_button.disabled:
				_study_blueprint(StringName(blueprint_value))
				get_viewport().set_input_as_handled()
				return
		for equipment_button: Button in _equipment_buttons.duplicate():
			if is_instance_valid(equipment_button) and equipment_button.is_visible_in_tree() and not equipment_button.disabled and equipment_button.get_global_rect().has_point(position):
				equipment_button.pressed.emit()
				get_viewport().set_input_as_handled()
				return


func _purchase(item_id: StringName) -> void:
	var meta := get_tree().get_first_node_in_group("meta_progression") as MetaProgression
	if meta != null:
		meta.purchase(item_id)
	_refresh()


func _study_blueprint(model_id: StringName) -> void:
	var meta := get_tree().get_first_node_in_group("meta_progression") as MetaProgression
	if meta != null:
		meta.study_blueprint(model_id)
	_refresh()


func _refresh() -> void:
	var meta := get_tree().get_first_node_in_group("meta_progression") as MetaProgression
	if meta == null:
		return
	credits_label.text = "CRÉDITOS PERMANENTES  ◈ %d" % meta.credits
	credits_label.add_theme_color_override("font_color", Color("f0d48a"))
	var best_time := float(meta.statistics.get("best_time", 0.0))
	var best_time_text := "%02d:%02d" % [floori(best_time / 60.0), floori(best_time) % 60] if best_time > 0.0 else "--:--"
	stats_label.text = "RUNS %d   VITÓRIAS %d   MORTES %d   BOSSES %d\nMAIOR STAGE %d/6   MELHOR TEMPO %s\nMODELOS EXTRAÍDOS %d   BLUEPRINTS %d" % [int(meta.statistics.get("runs", 0)), int(meta.statistics.get("victories", 0)), int(meta.statistics.get("deaths", 0)), int(meta.statistics.get("bosses_defeated", 0)), int(meta.statistics.get("highest_stage", 0)), best_time_text, meta.recovered_models.size(), meta.blueprints.size()]
	for item_value: Variant in purchase_buttons:
		var item_id := StringName(item_value)
		var definition: Dictionary = MetaProgression.PURCHASES[item_id]
		var button := purchase_buttons[item_id] as Button
		var unlocked := meta.is_unlocked(item_id)
		button.text = "%s  //  %s" % [String(definition.get("name", item_id)), "DESBLOQUEADO" if unlocked else "◈ %d" % int(definition.get("cost", 0))]
		button.disabled = unlocked or meta.credits < int(definition.get("cost", 0))
	var visible_blueprints := 0
	for weapon_value: Variant in blueprint_buttons:
		var weapon_id := StringName(weapon_value)
		var blueprint_button := blueprint_buttons[weapon_id] as Button
		var recovered := meta.recovered_models.has(weapon_id)
		var studied := meta.blueprints.has(weapon_id)
		blueprint_button.visible = recovered or studied
		if blueprint_button.visible:
			visible_blueprints += 1
		blueprint_button.disabled = studied
		blueprint_button.text = "BLUEPRINT // %s // %s" % [WeaponCatalog.get_display_name(weapon_id), "ESTUDADO" if studied else "ESTUDAR"]
	_blueprint_heading.visible = visible_blueprints > 0
	_refresh_equipment(meta)


# --- Bancada de fabricação -----------------------------------------------------------

func _refresh_equipment(meta: MetaProgression) -> void:
	scrap_label.text = "SUCATA  ⚙ %d" % meta.scrap
	var focused := get_viewport().gui_get_focus_owner()
	var focused_name := String(focused.name) if focused != null and equipment_root.is_ancestor_of(focused) else ""
	for child in equipment_root.get_children():
		equipment_root.remove_child(child)
		child.queue_free()
	_equipment_buttons.clear()
	_heading("ARSENAL  //  FABRICAR E PREPARAR A PRÓXIMA RUN")
	var rarity_row := _row()
	_button(rarity_row, "CycleRarity", "RARIDADE DA FABRICAÇÃO: %s  ▸" % RarityTable.label(craft_rarity), 300, _cycle_rarity, false, RarityTable.color(craft_rarity))
	_note(rarity_row, "Raridade multiplica os atributos. Nível (MK) é melhoria separada.")
	var loadout_text: PackedStringArray = []
	for slot in 2:
		var loadout_id := meta.loadout_weapons[slot]
		loadout_text.append("SLOT %d: %s" % [slot + 1, "%s [%s]" % [WeaponCatalog.get_display_name(loadout_id), RarityTable.label(meta.armory_rarity(loadout_id))] if not loadout_id.is_empty() else "VAZIO"])
	_note(equipment_root, "LOADOUT INICIAL  —  " + "   |   ".join(loadout_text))
	for weapon_value: Variant in WeaponCatalog.WEAPONS:
		var weapon_id := StringName(weapon_value)
		var known := meta.is_blueprint_known(weapon_id)
		var owned := meta.armory.has(weapon_id)
		if not known and not meta.recovered_models.has(weapon_id):
			continue
		var row := _row()
		var icon := TextureRect.new()
		icon.texture = WeaponCatalog.get_visual_texture(weapon_id, "inventory_icon")
		icon.custom_minimum_size = Vector2(64, 30)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var stats := WeaponCatalog.stats_for(weapon_id, meta.armory_rarity(weapon_id) if owned else craft_rarity)
		var info := "%s  %s\n%s  DANO %d  CAD %.2fs" % [WeaponCatalog.get_display_name(weapon_id), "[%s]" % RarityTable.label(meta.armory_rarity(weapon_id)) if owned else ("[BLUEPRINT]" if known else "[ESTUDE O BLUEPRINT]"), WeaponCatalog.category_label(weapon_id), int(stats.damage), float(stats.cooldown)]
		_note(row, info, 200, RarityTable.color(meta.armory_rarity(weapon_id)) if owned else Color("94dce8"))
		if known:
			var cost := WeaponCatalog.craft_cost(weapon_id, craft_rarity)
			var can := meta.can_fabricate_weapon(weapon_id, craft_rarity)
			_button(row, "Fab_%s" % weapon_id, "FABRICAR ⚙%d" % cost, 120, _fabricate_weapon.bind(weapon_id), not can)
		if owned:
			for slot in 2:
				var in_slot := meta.loadout_weapons[slot] == weapon_id
				_button(row, "Slot%d_%s" % [slot, weapon_id], "◆ S%d" % (slot + 1) if in_slot else "S%d" % (slot + 1), 56, _set_loadout.bind(slot, weapon_id), false, Color("5fe5f3") if in_slot else Color.WHITE)
	_heading("CYBERWARE  //  LABORATÓRIO DE IMPLANTES")
	var slot_text: PackedStringArray = []
	for slot: StringName in GameplayProgressionFoundation.CYBERWARE_SLOTS:
		var installed := meta.find_cyberware(String(meta.installed_cyberwares.get(slot, "")))
		slot_text.append("%s: %s" % [CyberwareCatalog.SLOT_LABELS.get(slot, slot), String(CyberwareCatalog.line_data(StringName(installed.line)).short) + " MK%d" % int(installed.level) if not installed.is_empty() else "—"])
	_note(equipment_root, "INSTALADOS  —  " + "   ".join(slot_text))
	var fabricate_row := _row()
	for line: StringName in CyberwareCatalog.LINE_ORDER:
		var line_button := _button(fabricate_row, "CyFab_%s" % line, "%s\n⚙%d" % [CyberwareCatalog.line_data(line).short, CyberwareCatalog.fabricate_cost(craft_rarity)], 94, _fabricate_cyberware.bind(line), meta.scrap < CyberwareCatalog.fabricate_cost(craft_rarity), CyberwareCatalog.line_data(line).color)
		line_button.icon = CyberwareCatalog.icon(line)
		line_button.add_theme_font_size_override("font_size", 11)
		line_button.tooltip_text = String(CyberwareCatalog.line_data(line).description)
	for instance: Dictionary in meta.cyberwares:
		var row := _row()
		var uid := String(instance.uid)
		var icon := TextureRect.new()
		icon.texture = CyberwareCatalog.icon(StringName(instance.line))
		icon.custom_minimum_size = Vector2(32, 32)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate = Color.WHITE
		row.add_child(icon)
		var rarity := StringName(instance.rarity)
		_note(row, "%s  [%s]\n%s" % [CyberwareCatalog.display_name(instance), RarityTable.label(rarity), CyberwareCatalog.describe(instance)], 230, RarityTable.color(rarity))
		var installed := meta.is_cyberware_installed(uid)
		_button(row, "CyIns_%s" % uid, "INSTALADO" if installed else "INSTALAR", 96, _install_cyberware.bind(uid, installed), false, Color("43f2b0") if installed else Color.WHITE)
		var upgrade := CyberwareCatalog.upgrade_cost(instance)
		_button(row, "CyUp_%s" % uid, "MK MÁX" if upgrade < 0 else "MELHORAR ⚙%d" % upgrade, 112, _upgrade_cyberware.bind(uid), upgrade < 0 or meta.scrap < upgrade)
		_button(row, "CySal_%s" % uid, "DESMONTAR", 92, _salvage_cyberware.bind(uid), installed)
	_heading("ACESSÓRIOS ATIVOS  //  DOIS SLOTS (F / G  ·  LT / ▲)")
	for accessory_id: StringName in AccessoryCatalog.ORDER:
		var row := _row()
		var icon := TextureRect.new()
		icon.texture = AccessoryCatalog.icon(accessory_id)
		icon.custom_minimum_size = Vector2(32, 32)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var data := AccessoryCatalog.get_definition(accessory_id)
		_note(row, "%s\n%s  CARGAS %d  RECARGA %ds" % [AccessoryCatalog.display_name(accessory_id), String(data.description), int(data.charges), int(data.recharge)], 300, data.color)
		if not meta.owned_accessories.has(accessory_id):
			_button(row, "AcFab_%s" % accessory_id, "FABRICAR ⚙%d" % AccessoryCatalog.craft_cost(accessory_id), 130, _fabricate_accessory.bind(accessory_id), meta.scrap < AccessoryCatalog.craft_cost(accessory_id))
		else:
			for slot in AccessoryCatalog.SLOT_COUNT:
				var equipped := meta.equipped_accessories[slot] == accessory_id
				_button(row, "AcSlot%d_%s" % [slot, accessory_id], "◆ A%d" % (slot + 1) if equipped else "A%d" % (slot + 1), 64, _equip_accessory.bind(slot, accessory_id, equipped), false, Color("ffd27a") if equipped else Color.WHITE)
	if not focused_name.is_empty():
		var restored := equipment_root.find_child(focused_name, true, false) as Control
		if restored != null and restored.focus_mode != Control.FOCUS_NONE:
			restored.call_deferred("grab_focus")


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("94dce8"))
	equipment_root.add_child(label)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	equipment_root.add_child(row)
	return row


func _note(parent: Control, text: String, width: float = 0.0, color: Color = Color("c8d6e0")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		label.custom_minimum_size = Vector2(width, 0)
	else:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _button(parent: Control, node_name: String, text: String, width: float, callback: Callable, disabled: bool = false, color: Color = Color.WHITE) -> Button:
	var button := Button.new()
	button.name = node_name.validate_node_name()
	button.text = text
	button.custom_minimum_size = Vector2(width, 40)
	PANEL_PRESENTATION.style_button(button)
	button.add_theme_font_size_override("font_size", 12)
	if color != Color.WHITE:
		button.add_theme_color_override("font_color", color)
	button.disabled = disabled
	button.expand_icon = false
	button.pressed.connect(callback)
	parent.add_child(button)
	_equipment_buttons.append(button)
	return button


func _meta() -> MetaProgression:
	return get_tree().get_first_node_in_group("meta_progression") as MetaProgression


func _after_bench_action(success: bool) -> void:
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null:
		audio.play_event(&"ui_confirm" if success else &"ui_close")
	if success:
		# Hub mostra o jogador já com o novo equipamento.
		var room_manager := get_tree().get_first_node_in_group("room_manager")
		if room_manager != null and room_manager.has_method("apply_meta_loadout"):
			room_manager.apply_meta_loadout()
	# Reconstrói a lista fora do sinal do botão que acabou de ser pressionado.
	call_deferred("_refresh")


func _cycle_rarity() -> void:
	var tiers := RarityTable.enabled_tiers()
	craft_rarity = tiers[(tiers.find(craft_rarity) + 1) % tiers.size()]
	call_deferred("_refresh")


func _fabricate_weapon(weapon_id: StringName) -> void:
	_after_bench_action(_meta().fabricate_weapon(weapon_id, craft_rarity))


func _set_loadout(slot: int, weapon_id: StringName) -> void:
	var meta := _meta()
	if meta.loadout_weapons[slot] == weapon_id:
		_after_bench_action(meta.set_loadout_weapon(slot, &""))
	else:
		_after_bench_action(meta.set_loadout_weapon(slot, weapon_id))


func _fabricate_cyberware(line: StringName) -> void:
	var instance := _meta().fabricate_cyberware(line, craft_rarity)
	if not instance.is_empty() and not _meta().installed_cyberwares.has(CyberwareCatalog.slot_for(line)):
		_meta().install_cyberware(String(instance.uid))
	_after_bench_action(not instance.is_empty())


func _install_cyberware(uid: String, installed: bool) -> void:
	var meta := _meta()
	if installed:
		var instance := meta.find_cyberware(uid)
		_after_bench_action(meta.uninstall_cyberware(CyberwareCatalog.slot_for(StringName(instance.line))))
	else:
		_after_bench_action(meta.install_cyberware(uid))


func _upgrade_cyberware(uid: String) -> void:
	_after_bench_action(_meta().upgrade_cyberware(uid))


func _salvage_cyberware(uid: String) -> void:
	_after_bench_action(_meta().salvage_cyberware(uid) > 0)


func _fabricate_accessory(accessory_id: StringName) -> void:
	_after_bench_action(_meta().fabricate_accessory(accessory_id))


func _equip_accessory(slot: int, accessory_id: StringName, equipped: bool) -> void:
	_after_bench_action(_meta().equip_accessory(slot, &"" if equipped else accessory_id))
