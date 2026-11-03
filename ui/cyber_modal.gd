extends CanvasLayer
## Base das telas modais de menu (campanhas, social, cooperativo).
## Estrutura: cabeçalho (título, subtítulo, etiqueta de estado) → abas → corpo → rodapé
## (mensagem de retorno + VOLTAR). Toque via TouchScrollRouter (o projeto desliga a
## emulação de mouse), campos de texto abrem o teclado virtual, ui_cancel fecha.
const UI := preload("res://ui/cyber_ui.gd")
const TOUCH := preload("res://ui/touch_scroll_router.gd")

signal closed

const TITLE_BACKDROP := Color(0.008, 0.014, 0.03, 0.80)

var overlay: ColorRect
var frame_box: VBoxContainer
var title_label: Label
var subtitle_label: Label
var status_badge: PanelContainer
var tab_bar: HBoxContainer
var body: VBoxContainer
var feedback: Label
var back_button: Button
var router: RefCounted
var tabs: Dictionary = {}
var current_tab := ""
var busy := false
var _feedback_tween: Tween
var _pulse := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = UI.BACKDROP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	ContentRegistry.apply_ui_theme(overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(margin)
	frame_box = VBoxContainer.new()
	frame_box.name = "Frame"
	frame_box.add_theme_constant_override("separation", 10)
	frame_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(frame_box)
	UI.PRESENTATION.background(frame_box, "settings/settings_panel")
	var header := UI.row(frame_box, 14)
	var accent := ColorRect.new()
	accent.color = UI.MAGENTA
	accent.custom_minimum_size = Vector2(4, 40)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(accent)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(titles)
	title_label = UI.label("", UI.TITLE_SIZE, UI.CYAN, false)
	title_label.name = "Title"
	titles.add_child(title_label)
	subtitle_label = UI.label("", UI.META_SIZE, UI.DIM)
	titles.add_child(subtitle_label)
	status_badge = UI.badge("OFFLINE", UI.DIM)
	header.add_child(status_badge)
	tab_bar = UI.row(frame_box, 6)
	tab_bar.name = "Tabs"
	UI.divider(frame_box)
	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_box.add_child(body)
	UI.divider(frame_box, UI.MAGENTA)
	var footer := UI.row(frame_box, 12)
	feedback = UI.label("", UI.BODY_SIZE, UI.TEXT)
	feedback.name = "Feedback"
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(feedback)
	back_button = UI.button("VOLTAR", close, "normal", 210.0)
	back_button.name = "Back"
	footer.add_child(back_button)
	router = TOUCH.new(overlay)
	overlay.visible = false
	_build()


## Subclasses montam abas e estado inicial aqui.
func _build() -> void:
	pass


func add_tab(id: String, text: String) -> Button:
	var item := UI.tab(text, select_tab.bind(id))
	item.name = "Tab_" + id
	tab_bar.add_child(item)
	tabs[id] = item
	return item


func select_tab(id: String) -> void:
	current_tab = id
	for key: String in tabs:
		UI.set_tab_selected(tabs[key], key == id)
	clear_body()
	_render(id)
	call_deferred("focus_first")


## Subclasses desenham o conteúdo da aba atual.
func _render(_tab: String) -> void:
	pass


func refresh() -> void:
	if not current_tab.is_empty():
		var previous := get_viewport().gui_get_focus_owner()
		var previous_name := previous.name if previous != null and overlay.is_ancestor_of(previous) else &""
		clear_body()
		_render(current_tab)
		if previous_name != &"":
			call_deferred("_restore_focus", previous_name)


func _restore_focus(node_name: StringName) -> void:
	var found := body.find_child(String(node_name), true, false) as Control
	if found != null and found.is_visible_in_tree() and found.focus_mode != Control.FOCUS_NONE:
		found.grab_focus()
	else:
		focus_first()


func clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


func is_open() -> bool:
	return overlay != null and overlay.visible


## `over_title`: aberto a partir do menu inicial — a cidade animada aparece por trás.
func show_modal(tab := "", over_title := false) -> void:
	overlay.color = TITLE_BACKDROP if over_title else UI.BACKDROP
	if over_title:
		add_to_group(&"title_menu_modal")
	elif is_in_group(&"title_menu_modal"):
		remove_from_group(&"title_menu_modal")
	overlay.visible = true
	router.reset()
	notify("")
	overlay.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(overlay, "modulate:a", 1.0, 0.16)
	if not tab.is_empty() and tabs.has(tab):
		select_tab(tab)
	elif not current_tab.is_empty():
		select_tab(current_tab)
	elif not tabs.is_empty():
		select_tab(String(tabs.keys()[0]))
	else:
		clear_body()
		_render("")
		call_deferred("focus_first")


func hide_modal() -> void:
	overlay.visible = false
	if is_in_group(&"title_menu_modal"):
		remove_from_group(&"title_menu_modal")
	router.reset()
	set_busy(false)
	get_viewport().gui_release_focus()


## Comportamento padrão de VOLTAR; subclasses estendem para voltar ao menu certo.
func close() -> void:
	if busy:
		return
	hide_modal()
	closed.emit()


func focus_first() -> void:
	if not is_open():
		return
	for node in body.find_children("*", "BaseButton", true, false):
		var item := node as BaseButton
		if item.is_visible_in_tree() and not item.disabled and item.focus_mode != Control.FOCUS_NONE:
			item.grab_focus()
			return
	if tabs.has(current_tab):
		(tabs[current_tab] as Control).grab_focus()
	else:
		back_button.grab_focus()


## Mensagem de retorno no rodapé. kind: info, ok, warn, error, busy.
func notify(text: String, kind := "info") -> void:
	if feedback == null:
		return
	var colors := {"info": UI.TEXT, "ok": UI.GREEN, "warn": UI.AMBER, "error": UI.RED, "busy": UI.CYAN}
	feedback.text = text
	feedback.add_theme_color_override("font_color", colors.get(kind, UI.TEXT))
	if _feedback_tween != null:
		_feedback_tween.kill()
	if not text.is_empty():
		feedback.modulate.a = 0.2
		_feedback_tween = create_tween()
		_feedback_tween.tween_property(feedback, "modulate:a", 1.0, 0.18)


func set_status(text: String, color: Color) -> void:
	UI.set_badge(status_badge, text, color)


## Bloqueia toques/botões durante operações assíncronas (carregar, conectar).
func set_busy(value: bool, message := "") -> void:
	busy = value
	for node in overlay.find_children("*", "BaseButton", true, false):
		var item := node as BaseButton
		if value:
			if not item.disabled:
				item.set_meta("cyber_busy_disabled", true)
				item.disabled = true
		elif item.has_meta("cyber_busy_disabled"):
			item.remove_meta("cyber_busy_disabled")
			item.disabled = false
	if value and not message.is_empty():
		notify(message, "busy")


func _process(delta: float) -> void:
	if not is_open():
		return
	if busy and feedback != null:
		_pulse = fmod(_pulse + delta * 2.4, TAU)
		feedback.modulate.a = 0.55 + 0.45 * absf(sin(_pulse))
	_tick(delta)


## Atualizações periódicas da aba visível (contadores, estado de conexão).
func _tick(_delta: float) -> void:
	pass


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventScreenTouch and event.pressed:
		for node in overlay.find_children("*", "LineEdit", true, false):
			var item := node as LineEdit
			if item.is_visible_in_tree() and item.editable and item.get_global_rect().has_point(event.position) and _inside_scroll_clip(item, event.position):
				item.grab_focus()
				if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
					DisplayServer.virtual_keyboard_show(item.text, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT, item.max_length)
				get_viewport().set_input_as_handled()
				return
	if router.handle(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not event.is_echo():
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit and overlay.is_ancestor_of(focus):
			focus.release_focus()
			back_button.grab_focus()
		else:
			close()
		get_viewport().set_input_as_handled()


func _inside_scroll_clip(control: Control, position: Vector2) -> bool:
	var parent := control.get_parent()
	while parent != null and parent != overlay:
		if parent is ScrollContainer and not (parent as Control).get_global_rect().has_point(position):
			return false
		parent = parent.get_parent()
	return true


## Corpo rolável (lista) e coluna lateral fixa, para aproveitar telas 20:9.
func split_body(side_width := 400.0) -> Array:
	var columns := UI.row(body, 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = "List"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)
	var side_scroll := ScrollContainer.new()
	side_scroll.name = "Side"
	side_scroll.custom_minimum_size = Vector2(side_width, 0)
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_scroll.add_child(side)
	return [list, side]


func scroll_body() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "List"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)
	return list


func empty_state(parent: Node, title: String, hint: String) -> void:
	var box := UI.card(parent)
	box.add_child(UI.label(title, UI.HEADING_SIZE, UI.WHITE))
	box.add_child(UI.label(hint, UI.META_SIZE, UI.DIM))
