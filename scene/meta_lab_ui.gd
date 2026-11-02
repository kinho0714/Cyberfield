class_name MetaLabUI
extends CanvasLayer
## Terminal da Casa: blueprints → estudo → fabricação → loadout, implantes, acessórios
## e pesquisas permanentes. Fonte de verdade: `MetaProgression` (nada é guardado aqui).
##
## 02/11/2026 (P0-A): a bancada de 01/11 deixou a lista longa demais e o Android não
## conseguia rolar (o projeto desliga a emulação de mouse por toque) — e o foco inicial no
## botão do fim rolava a lista até os acessórios, escondendo os blueprints. Agora:
## abas curtas, VOLTAR fixo no topo, rolagem por arrasto e toque disparado ao soltar
## (`TouchScrollRouter`), alvos de toque ≥ 56 px e painel dimensionado pela área visível.
## Mouse, roda e teclado/controle seguem pelo caminho nativo dos Buttons.

const PANEL_PRESENTATION = preload("res://ui/menu_panel_presentation.gd")
const TAB_PROJECTS := 0
const TAB_CYBERWARE := 1
const TAB_ACCESSORIES := 2
const TAB_RESEARCH := 3
const TAB_LABELS := ["BLUEPRINTS E ARSENAL", "IMPLANTES", "ACESSÓRIOS", "PESQUISA"]
const ROW_HEIGHT := 58.0
const BUTTON_FONT := 15

var overlay: ColorRect
var frame: PanelContainer
var scroll: ScrollContainer
var credits_label: Label
var scrap_label: Label
var stats_label: Label
var hint_label: Label
var purchase_buttons: Dictionary = {}
## Botões ESTUDAR da aba de blueprints (id da arma -> Button), refeitos a cada atualização.
var blueprint_buttons: Dictionary = {}
var tab_buttons: Array[Button] = []
var close_button: Button
var _blueprint_heading: Label
var blocked_player: Node
var current_tab := TAB_PROJECTS
## 01/11/2026: bancada de fabricação (arsenal + cyberware + acessórios ativos).
var equipment_root: VBoxContainer
var craft_rarity: StringName = &"common"
var research_page: VBoxContainer
var projects_page: VBoxContainer
var cyber_page: VBoxContainer
var gadget_page: VBoxContainer
var touch_router: TouchScrollRouter
var _equipment_buttons: Array[Button] = []


func _ready() -> void:
	add_to_group("meta_lab_ui")
	layer = 88
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.003, 0.012, 0.029, 0.97)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	frame = PanelContainer.new()
	frame.name = "Frame"
	frame.add_theme_stylebox_override("panel", PANEL_PRESENTATION.style("inventory/inventory_panel", 20, 14))
	overlay.add_child(frame)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	frame.add_child(body)
	_build_header(body)
	_build_tabs(body)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: StringName in [&"margin_left", &"margin_right"]:
		margin.add_theme_constant_override(side, 14)
	for side: StringName in [&"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 6)
	scroll.add_child(margin)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(pages)
	research_page = _page(pages, "ResearchPage")
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 15)
	research_page.add_child(stats_label)
	var research := Label.new()
	research.text = "PESQUISAS  //  MELHORIAS E LICENÇAS PERMANENTES (CRÉDITOS ◈)"
	research.add_theme_font_size_override("font_size", 16)
	research.add_theme_color_override("font_color", Color("94dce8"))
	research_page.add_child(research)
	for item_value: Variant in MetaProgression.PURCHASES:
		var item_id := StringName(item_value)
		var button := Button.new()
		button.name = ("Buy_%s" % item_id).validate_node_name()
		button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PANEL_PRESENTATION.style_button(button)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_purchase.bind(item_id))
		research_page.add_child(button)
		purchase_buttons[item_id] = button
	equipment_root = VBoxContainer.new()
	equipment_root.name = "EquipmentBench"
	equipment_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(equipment_root)
	projects_page = _page(equipment_root, "ProjectsPage")
	cyber_page = _page(equipment_root, "CyberwarePage")
	gadget_page = _page(equipment_root, "AccessoriesPage")
	_blueprint_heading = Label.new()
	_blueprint_heading.name = "BlueprintHeading"
	_blueprint_heading.text = "PROJETOS RECUPERADOS  //  BLUEPRINTS"
	_blueprint_heading.add_theme_font_size_override("font_size", 16)
	_blueprint_heading.add_theme_color_override("font_color", Color("94dce8"))
	projects_page.add_child(_blueprint_heading)
	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("7f97a8"))
	body.add_child(hint_label)
	touch_router = TouchScrollRouter.new(overlay)
	overlay.visible = false
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_header(body: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 14)
	body.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	var overline := Label.new()
	overline.text = "CYBERFIELD  //  BANCADA DE PREPARAÇÃO"
	overline.add_theme_font_size_override("font_size", 13)
	overline.add_theme_color_override("font_color", Color("5fe5f3"))
	titles.add_child(overline)
	var title := Label.new()
	title.text = "OFICINA DE OPERAÇÕES"
	title.add_theme_font_size_override("font_size", 24)
	titles.add_child(title)
	credits_label = Label.new()
	credits_label.add_theme_font_size_override("font_size", 19)
	credits_label.add_theme_color_override("font_color", Color("f0d48a"))
	credits_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(credits_label)
	scrap_label = Label.new()
	scrap_label.add_theme_font_size_override("font_size", 19)
	scrap_label.add_theme_color_override("font_color", Color("ffb347"))
	scrap_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(scrap_label)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "✕  VOLTAR"
	close_button.custom_minimum_size = Vector2(170, ROW_HEIGHT)
	PANEL_PRESENTATION.style_button(close_button)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(close_terminal)
	header.add_child(close_button)


func _build_tabs(body: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for index in TAB_LABELS.size():
		var button := Button.new()
		button.name = "Tab%d" % index
		button.text = TAB_LABELS[index]
		button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PANEL_PRESENTATION.style_button(button)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(select_tab.bind(index))
		tabs.add_child(button)
		tab_buttons.append(button)


func _page(parent: Control, page_name: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = page_name
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8)
	parent.add_child(page)
	return page


## Painel cobre a área segura visível (20:9 no celular, 16:9 no PC), sem tamanho fixo.
func _layout() -> void:
	if frame == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var safe := Rect2(Vector2.ZERO, view)
	if OS.has_feature("mobile"):
		var display := Vector2(DisplayServer.screen_get_size())
		var area := DisplayServer.get_display_safe_area()
		if display.x > 0.0 and display.y > 0.0 and area.size.x > 0 and area.size.y > 0:
			var ratio := view / display
			safe = Rect2(Vector2(area.position) * ratio, Vector2(area.size) * ratio)
	var width := minf(safe.size.x - 32.0, 1240.0)
	var height := safe.size.y - 24.0
	frame.position = Vector2(safe.position.x + (safe.size.x - width) * 0.5, safe.position.y + 12.0)
	frame.size = Vector2(width, height)


func open_terminal(player: Node) -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or not room_manager.current_is_hub or overlay.visible:
		return
	blocked_player = player
	if blocked_player != null and bool(blocked_player.get("input_enabled")):
		blocked_player.set_input_enabled(false)
	room_manager.get_node("TouchControls").set_menu_blocked(true)
	touch_router.reset()
	_layout()
	overlay.visible = true
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null:
		audio.play_event(&"ui_open")
	select_tab(TAB_PROJECTS)
	tab_buttons[TAB_PROJECTS].grab_focus()


func close_terminal() -> void:
	overlay.visible = false
	touch_router.reset()
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


func is_open() -> bool:
	return overlay != null and overlay.visible


func select_tab(index: int) -> void:
	current_tab = clampi(index, 0, TAB_LABELS.size() - 1)
	research_page.visible = current_tab == TAB_RESEARCH
	projects_page.visible = current_tab == TAB_PROJECTS
	cyber_page.visible = current_tab == TAB_CYBERWARE
	gadget_page.visible = current_tab == TAB_ACCESSORIES
	scroll.scroll_vertical = 0
	_refresh()


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		close_terminal()
		get_viewport().set_input_as_handled()
		return
	# Com o terminal aberto, pausa/inventário/mapa não abrem por baixo dele.
	for blocked: StringName in [&"pause_menu", &"open_inventory", &"open_map"]:
		if InputMap.has_action(blocked) and event.is_action(blocked):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.is_echo():
		var key := (event as InputEventKey).keycode
		if key == KEY_Q or key == KEY_E:
			select_tab(posmod(current_tab + (1 if key == KEY_E else -1), TAB_LABELS.size()))
			tab_buttons[current_tab].grab_focus()
			get_viewport().set_input_as_handled()
			return
	if touch_router.handle(event):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open():
		close_terminal()


func _purchase(item_id: StringName) -> void:
	var meta := _meta()
	if meta != null:
		meta.purchase(item_id)
	call_deferred("_refresh")


func _study_blueprint(model_id: StringName) -> void:
	var meta := _meta()
	var studied := meta != null and meta.study_blueprint(model_id)
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and studied:
		audio.play_event(&"ui_confirm")
	call_deferred("_refresh")


func _refresh() -> void:
	var meta := _meta()
	if meta == null:
		return
	credits_label.text = "◈ %d" % meta.credits
	scrap_label.text = "⚙ %d" % meta.scrap
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
	var pending := 0
	for model_id: StringName in meta.recovered_models:
		if not meta.blueprints.has(model_id) and not meta.is_blueprint_known(model_id):
			pending += 1
	for index in tab_buttons.size():
		var label: String = TAB_LABELS[index]
		if index == TAB_PROJECTS and pending > 0:
			label += "  (%d NOVO%s)" % [pending, "S" if pending > 1 else ""]
		tab_buttons[index].text = ("▸ " if index == current_tab else "") + label
		tab_buttons[index].add_theme_color_override("font_color", Color("5fe5f3") if index == current_tab else Color("f2f7ff"))
	hint_label.text = "Arraste para rolar  ·  toque para escolher  ·  Q/E troca de aba  ·  Esc/Voltar fecha" if not OS.has_feature("mobile") else "Arraste para rolar  ·  toque para escolher"
	_refresh_equipment(meta)


# --- Bancada de fabricação -----------------------------------------------------------

func _refresh_equipment(meta: MetaProgression) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focused_name := String(focused.name) if focused != null and equipment_root.is_ancestor_of(focused) else ""
	for page: VBoxContainer in [projects_page, cyber_page, gadget_page]:
		for child in page.get_children():
			if child == _blueprint_heading:
				continue
			page.remove_child(child)
			child.queue_free()
	_equipment_buttons.clear()
	blueprint_buttons.clear()
	_build_projects_page(meta)
	_build_cyber_page(meta)
	_build_gadget_page(meta)
	if not focused_name.is_empty():
		var restored := equipment_root.find_child(focused_name, true, false) as Control
		if restored != null and restored.focus_mode != Control.FOCUS_NONE and restored.is_visible_in_tree():
			restored.call_deferred("grab_focus")


func _build_projects_page(meta: MetaProgression) -> void:
	var discovered := 0
	for weapon_value: Variant in WeaponCatalog.WEAPONS:
		var weapon_id := StringName(weapon_value)
		if meta.is_blueprint_known(weapon_id) or meta.recovered_models.has(weapon_id):
			discovered += 1
	_blueprint_heading.text = "PROJETOS RECUPERADOS  //  BLUEPRINTS  %d/%d" % [discovered, WeaponCatalog.WEAPONS.size()]
	var rarity_row := _row(projects_page)
	_button(rarity_row, "CycleRarity", "RARIDADE DA FABRICAÇÃO: %s  ▸" % RarityTable.label(craft_rarity), 330, _cycle_rarity, false, RarityTable.color(craft_rarity))
	_note(rarity_row, "Raridade multiplica os atributos. Nível (MK) é melhoria separada.", 240.0)
	var loadout_text: PackedStringArray = []
	for slot in 2:
		var loadout_id := meta.loadout_weapons[slot]
		loadout_text.append("SLOT %d: %s" % [slot + 1, "%s [%s]" % [WeaponCatalog.get_display_name(loadout_id), RarityTable.label(meta.armory_rarity(loadout_id))] if not loadout_id.is_empty() else "VAZIO"])
	_note(projects_page, "LOADOUT INICIAL  —  " + "   |   ".join(loadout_text), 0.0, Color("5fe5f3"))
	var hidden := 0
	for weapon_value: Variant in WeaponCatalog.WEAPONS:
		var weapon_id := StringName(weapon_value)
		var known := meta.is_blueprint_known(weapon_id)
		var recovered := meta.recovered_models.has(weapon_id)
		var owned := meta.armory.has(weapon_id)
		if not known and not recovered:
			hidden += 1
			continue
		var row := _row(projects_page)
		var icon := TextureRect.new()
		icon.texture = WeaponCatalog.get_visual_texture(weapon_id, "inventory_icon")
		icon.custom_minimum_size = Vector2(76, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var stats := WeaponCatalog.stats_for(weapon_id, meta.armory_rarity(weapon_id) if owned else craft_rarity)
		var state := "[%s]" % RarityTable.label(meta.armory_rarity(weapon_id)) if owned else ("[BLUEPRINT]" if known else "[NOVO — ESTUDE O BLUEPRINT]")
		var info := "%s  %s\n%s  ·  DANO %d  ·  CAD %.2fs" % [WeaponCatalog.get_display_name(weapon_id), state, WeaponCatalog.category_label(weapon_id), int(stats.damage), float(stats.cooldown)]
		_note(row, info, 240.0, RarityTable.color(meta.armory_rarity(weapon_id)) if owned else (Color("94dce8") if known else Color("ffd27a")))
		if not known:
			var study := _button(row, "Study_%s" % weapon_id, "ESTUDAR BLUEPRINT", 210, _study_blueprint.bind(weapon_id), false, Color("ffd27a"))
			blueprint_buttons[weapon_id] = study
			continue
		var cost := WeaponCatalog.craft_cost(weapon_id, craft_rarity)
		var can := meta.can_fabricate_weapon(weapon_id, craft_rarity)
		_button(row, "Fab_%s" % weapon_id, "FABRICAR ⚙%d" % cost, 160, _fabricate_weapon.bind(weapon_id), not can)
		if owned:
			for slot in 2:
				var in_slot := meta.loadout_weapons[slot] == weapon_id
				_button(row, "Slot%d_%s" % [slot, weapon_id], "◆ S%d" % (slot + 1) if in_slot else "S%d" % (slot + 1), 76, _set_loadout.bind(slot, weapon_id), false, Color("5fe5f3") if in_slot else Color.WHITE)
	if hidden > 0:
		_note(projects_page, "%d PROJETO%s AINDA NÃO ENCONTRADO%s — armas achadas nas runs (baús, inimigos, chefes) viram blueprint aqui, mesmo na derrota." % [hidden, "S" if hidden > 1 else "", "S" if hidden > 1 else ""], 0.0, Color("7f97a8"))


func _build_cyber_page(meta: MetaProgression) -> void:
	_heading(cyber_page, "CYBERWARE  //  LABORATÓRIO DE IMPLANTES  (raridade: %s)" % RarityTable.label(craft_rarity))
	var slot_text: PackedStringArray = []
	for slot: StringName in GameplayProgressionFoundation.CYBERWARE_SLOTS:
		var installed := meta.find_cyberware(String(meta.installed_cyberwares.get(slot, "")))
		slot_text.append("%s: %s" % [CyberwareCatalog.SLOT_LABELS.get(slot, slot), String(CyberwareCatalog.line_data(StringName(installed.line)).short) + " MK%d" % int(installed.level) if not installed.is_empty() else "—"])
	_note(cyber_page, "INSTALADOS  —  " + "   ".join(slot_text), 0.0, Color("43f2b0"))
	var fabricate_row := HFlowContainer.new()
	fabricate_row.add_theme_constant_override("h_separation", 8)
	fabricate_row.add_theme_constant_override("v_separation", 8)
	cyber_page.add_child(fabricate_row)
	for line: StringName in CyberwareCatalog.LINE_ORDER:
		var line_button := _button(fabricate_row, "CyFab_%s" % line, "%s  ⚙%d" % [CyberwareCatalog.line_data(line).short, CyberwareCatalog.fabricate_cost(craft_rarity)], 180, _fabricate_cyberware.bind(line), meta.scrap < CyberwareCatalog.fabricate_cost(craft_rarity), CyberwareCatalog.line_data(line).color)
		line_button.icon = CyberwareCatalog.icon(line)
		line_button.tooltip_text = String(CyberwareCatalog.line_data(line).description)
	if meta.cyberwares.is_empty():
		_note(cyber_page, "Nenhum implante no estoque. Fabrique acima ou traga um da run (só fica na vitória; na derrota vira sucata).", 0.0, Color("7f97a8"))
	for instance: Dictionary in meta.cyberwares:
		var row := _row(cyber_page)
		var uid := String(instance.uid)
		var icon := TextureRect.new()
		icon.texture = CyberwareCatalog.icon(StringName(instance.line))
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var rarity := StringName(instance.rarity)
		_note(row, "%s  [%s]\n%s" % [CyberwareCatalog.display_name(instance), RarityTable.label(rarity), CyberwareCatalog.describe(instance)], 240.0, RarityTable.color(rarity))
		var installed := meta.is_cyberware_installed(uid)
		_button(row, "CyIns_%s" % uid, "INSTALADO" if installed else "INSTALAR", 130, _install_cyberware.bind(uid, installed), false, Color("43f2b0") if installed else Color.WHITE)
		var upgrade := CyberwareCatalog.upgrade_cost(instance)
		_button(row, "CyUp_%s" % uid, "MK MÁX" if upgrade < 0 else "MELHORAR ⚙%d" % upgrade, 160, _upgrade_cyberware.bind(uid), upgrade < 0 or meta.scrap < upgrade)
		_button(row, "CySal_%s" % uid, "DESMONTAR", 130, _salvage_cyberware.bind(uid), installed)


func _build_gadget_page(meta: MetaProgression) -> void:
	_heading(gadget_page, "ACESSÓRIOS ATIVOS  //  DOIS SLOTS (F / G  ·  LT / ▲)")
	for accessory_id: StringName in AccessoryCatalog.ORDER:
		var row := _row(gadget_page)
		var icon := TextureRect.new()
		icon.texture = AccessoryCatalog.icon(accessory_id)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var data := AccessoryCatalog.get_definition(accessory_id)
		_note(row, "%s\n%s  CARGAS %d  RECARGA %ds" % [AccessoryCatalog.display_name(accessory_id), String(data.description), int(data.charges), int(data.recharge)], 240.0, data.color)
		if not meta.owned_accessories.has(accessory_id):
			_button(row, "AcFab_%s" % accessory_id, "FABRICAR ⚙%d" % AccessoryCatalog.craft_cost(accessory_id), 170, _fabricate_accessory.bind(accessory_id), meta.scrap < AccessoryCatalog.craft_cost(accessory_id))
		else:
			for slot in AccessoryCatalog.SLOT_COUNT:
				var equipped := meta.equipped_accessories[slot] == accessory_id
				_button(row, "AcSlot%d_%s" % [slot, accessory_id], "◆ A%d" % (slot + 1) if equipped else "A%d" % (slot + 1), 84, _equip_accessory.bind(slot, accessory_id, equipped), false, Color("ffd27a") if equipped else Color.WHITE)


func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("94dce8"))
	parent.add_child(label)


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	parent.add_child(row)
	return row


func _note(parent: Control, text: String, width: float = 0.0, color: Color = Color("c8d6e0")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Largura mínima evita que o texto quebrado encolha a zero dentro da linha.
	label.custom_minimum_size = Vector2(width, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _button(parent: Control, node_name: String, text: String, width: float, callback: Callable, disabled: bool = false, color: Color = Color.WHITE) -> Button:
	var button := Button.new()
	button.name = node_name.validate_node_name()
	button.text = text
	button.custom_minimum_size = Vector2(width, ROW_HEIGHT - 4.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PANEL_PRESENTATION.style_button(button)
	button.add_theme_font_size_override("font_size", BUTTON_FONT)
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
