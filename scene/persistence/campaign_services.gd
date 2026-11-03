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
	hub_button.visible = controller.game.mode_selected and controller.game.current_is_hub and not controller.active.is_empty() and not overlay.visible and not get_tree().paused


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		if hub_button.visible and event is InputEventScreenTouch and event.pressed and hub_button.get_global_rect().has_point(event.position):
			open()
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
