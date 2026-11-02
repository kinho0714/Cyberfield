extends CanvasLayer
## Interface do Modo Dev: botão DEV no HUD + painel com abas montado a partir do registro
## do `DevMode` (nenhuma ferramenta é desenhada aqui). Toque pelo TouchScrollRouter
## (o projeto não emula mouse por toque), mouse/teclado pelo caminho nativo, F9 no PC.

const PANEL_PRESENTATION = preload("res://ui/menu_panel_presentation.gd")
const ROW_HEIGHT := 52.0

var dev_mode: DevMode
var hud_button: Button
var overlay: ColorRect
var frame: PanelContainer
var scroll: ScrollContainer
var content: VBoxContainer
var tabs_row: HBoxContainer
var status_label: Label
var log_label: Label
var close_button: Button
var touch_router: TouchScrollRouter
var current_section: StringName = &"player"
var _tab_buttons: Dictionary = {}
var _paused_by_panel := false
var _blocked_player: Node
var _button_touch := -1


func _ready() -> void:
	add_to_group("dev_mode_panel")
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud_button = Button.new()
	hud_button.name = "DevHudButton"
	hud_button.text = "DEV"
	hud_button.focus_mode = Control.FOCUS_NONE
	hud_button.custom_minimum_size = Vector2(76, 46)
	hud_button.size = Vector2(76, 46)
	hud_button.modulate = Color(1, 1, 1, 0.78)
	PANEL_PRESENTATION.style_button(hud_button)
	hud_button.add_theme_font_size_override("font_size", 16)
	hud_button.add_theme_color_override("font_color", Color("ffd27a"))
	hud_button.pressed.connect(toggle_panel)
	hud_button.visible = false
	add_child(hud_button)
	_build_panel()
	touch_router = TouchScrollRouter.new(overlay)
	get_viewport().size_changed.connect(_layout)
	dev_mode.log_changed.connect(_update_log)
	_layout()


func _build_panel() -> void:
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.015, 0.03, 0.62)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)
	frame = PanelContainer.new()
	frame.name = "Frame"
	frame.add_theme_stylebox_override("panel", PANEL_PRESENTATION.style("inventory/inventory_panel", 20, 12))
	overlay.add_child(frame)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	frame.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	body.add_child(header)
	var title := Label.new()
	title.text = "MODO DEV"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ffd27a"))
	header.add_child(title)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(status_label)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "✕  FECHAR"
	close_button.custom_minimum_size = Vector2(150, ROW_HEIGHT)
	PANEL_PRESENTATION.style_button(close_button)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)
	tabs_row = HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 6)
	body.add_child(tabs_row)
	for section: Dictionary in dev_mode.get_sections():
		var tab := Button.new()
		tab.name = "Tab_%s" % section.id
		tab.text = String(section.title)
		tab.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PANEL_PRESENTATION.style_button(tab)
		tab.add_theme_font_size_override("font_size", 15)
		tab.pressed.connect(select_section.bind(StringName(section.id)))
		tabs_row.add_child(tab)
		_tab_buttons[StringName(section.id)] = tab
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	log_label = Label.new()
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.add_theme_color_override("font_color", Color("9fe8b8"))
	log_label.clip_text = true
	body.add_child(log_label)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.x <= 0.0 or frame == null:
		return
	# Coluna esquerda, logo abaixo do painel do jogador/equipamento: não cobre a barra do
	# chefe (topo), o minimapa, a pausa nem o joystick (base).
	hud_button.position = Vector2(24.0, 206.0)
	var width := clampf(view.x * 0.66, minf(620.0, view.x - 24.0), 980.0)
	frame.position = Vector2(view.x - width - 12.0, 10.0)
	frame.size = Vector2(width, view.y - 20.0)


func is_open() -> bool:
	return overlay != null and overlay.visible


func refresh_button() -> void:
	if hud_button == null:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var show := dev_mode.is_available() and not is_open() and room_manager != null and not bool(room_manager.is_transitioning) and not _other_modal_open()
	hud_button.visible = show


func _process(_delta: float) -> void:
	refresh_button()


func _other_modal_open() -> bool:
	var pause := get_tree().get_first_node_in_group("pause_menu")
	if pause != null and pause.get_node("Overlay").visible:
		return true
	var lab := get_tree().get_first_node_in_group("meta_lab_ui")
	if lab != null and lab.is_open():
		return true
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	if inventory != null and inventory.overlay.visible:
		return true
	var attribute := get_tree().get_first_node_in_group("attribute_choice_ui")
	return attribute != null and attribute.visible


func toggle_panel() -> void:
	if is_open():
		close_panel()
	else:
		open_panel()


func open_panel() -> bool:
	if is_open() or not dev_mode.is_available() or _other_modal_open():
		return false
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or bool(room_manager.is_transitioning):
		return false
	_blocked_player = dev_mode.local_player()
	if _blocked_player != null and bool(_blocked_player.input_enabled):
		_blocked_player.set_input_enabled(false)
	else:
		_blocked_player = null
	room_manager.get_node("TouchControls").set_menu_blocked(true)
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_panel = true
	touch_router.reset()
	_layout()
	overlay.visible = true
	hud_button.visible = false
	select_section(current_section)
	return true


func close_panel() -> void:
	if not is_open():
		return
	overlay.visible = false
	touch_router.reset()
	get_viewport().gui_release_focus()
	if _paused_by_panel:
		get_tree().paused = false
		_paused_by_panel = false
	if is_instance_valid(_blocked_player):
		_blocked_player.set_input_enabled(true)
	_blocked_player = null
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.get_node("TouchControls").set_menu_blocked(false)


func select_section(section_id: StringName) -> void:
	current_section = section_id
	scroll.scroll_vertical = 0
	_rebuild()


func _rebuild() -> void:
	if not is_open():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var focused_name := String(focused.name) if focused != null and content.is_ancestor_of(focused) else ""
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for id: StringName in _tab_buttons:
		var tab := _tab_buttons[id] as Button
		tab.add_theme_color_override("font_color", Color("ffd27a") if id == current_section else Color("f2f7ff"))
	for entry: Dictionary in dev_mode.get_entries(current_section):
		match String(entry.get("kind", "info")):
			"header":
				var header := _label(String(entry.text), 15, Color("94dce8"))
				content.add_child(header)
			"info":
				content.add_child(_label(String(entry.text), 13, Color("c8d6e0")))
			"button":
				content.add_child(_entry_button(entry, 0.0))
			"row":
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
				if entry.get("icon") != null:
					var icon := TextureRect.new()
					icon.texture = entry.icon
					icon.custom_minimum_size = Vector2(56, 34)
					icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					row.add_child(icon)
				var label := _label(String(entry.get("label", "")), 13, Color("e8f0f8"))
				label.custom_minimum_size = Vector2(150, 0)
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(label)
				for button_data: Dictionary in entry.get("buttons", []) as Array:
					row.add_child(_entry_button(button_data, 0.0))
				content.add_child(row)
	_update_status()
	_update_log()
	if not focused_name.is_empty():
		var restored := content.find_child(focused_name, true, false) as Control
		if restored != null:
			restored.call_deferred("grab_focus")


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _entry_button(data: Dictionary, width: float) -> Button:
	var button := Button.new()
	button.name = ("Dev_%s" % String(data.get("id", data.get("label", "action")))).validate_node_name()
	button.text = String(data.get("label", ""))
	button.custom_minimum_size = Vector2(maxf(width, 72.0), ROW_HEIGHT - 4.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PANEL_PRESENTATION.style_button(button)
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(_on_entry_pressed.bind(data))
	return button


func _on_entry_pressed(data: Dictionary) -> void:
	var action: Callable = data.get("action", Callable())
	if not action.is_valid():
		return
	if bool(data.get("closes", false)):
		close_panel()
		action.call()
		return
	action.call()
	call_deferred("_rebuild")


func _update_status() -> void:
	if status_label == null:
		return
	status_label.text = "PERFIL DE TESTE ATIVO — o save real não é gravado" if dev_mode.is_sandbox_active() else "Perfil real intacto até a 1ª ferramenta (aí entra o perfil de teste)."
	status_label.add_theme_color_override("font_color", Color("ffb347") if dev_mode.is_sandbox_active() else Color("7f97a8"))


func _update_log() -> void:
	if log_label != null:
		log_label.text = dev_mode.log_lines[dev_mode.log_lines.size() - 1] if not dev_mode.log_lines.is_empty() else "Pronto. F9 abre/fecha no PC."


func _input(event: InputEvent) -> void:
	if not is_open():
		# Botão DEV por toque (sem emulação de mouse) e atalho F9.
		if hud_button.visible and event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and hud_button.get_global_rect().has_point(touch.position):
				_button_touch = touch.index
				get_viewport().set_input_as_handled()
			elif not touch.pressed and touch.index == _button_touch:
				_button_touch = -1
				get_viewport().set_input_as_handled()
				if hud_button.get_global_rect().has_point(touch.position):
					open_panel()
		elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F9 and dev_mode.is_available():
			open_panel()
			get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed(&"ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F9)):
		close_panel()
		get_viewport().set_input_as_handled()
		return
	for blocked: StringName in [&"pause_menu", &"open_inventory", &"open_map"]:
		if InputMap.has_action(blocked) and event.is_action(blocked):
			get_viewport().set_input_as_handled()
			return
	if touch_router.handle(event):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open():
		close_panel()
