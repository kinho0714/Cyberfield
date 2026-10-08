extends CanvasLayer

signal network_choice_submitted(attribute: StringName)
const PANEL_PRESENTATION = preload("res://ui/menu_panel_presentation.gd")

const LABELS := {
	&"intellect": ["INTELECTO", "+0,5 s de stamina de escalada", Color(1.0, 0.5, 0.1)],
	&"health": ["SAÚDE", "+HP máximo com ganho decrescente", Color(0.2, 0.9, 0.3)],
	&"strength": ["FORÇA", "+16% dano melee e slam", Color(1.0, 0.2, 0.2)],
}


func _option_data(option_id: StringName) -> Array:
	var definition := AttributeUpgradeCatalog.get_definition(option_id)
	if definition.is_empty():
		var legacy := LABELS.get(option_id, [String(option_id).to_upper(), "UPGRADE", Color.WHITE]) as Array
		return [legacy[0], "ATRIBUTO", legacy[1], legacy[2]]
	var category := StringName(definition.category)
	var color := Color(0.2, 0.9, 0.3) if category == &"health" else Color(1.0, 0.2, 0.2) if category == &"strength" else Color(1.0, 0.5, 0.1)
	return [AttributeUpgradeCatalog.CATEGORY_LABELS.get(category, String(category).to_upper()), String(definition.name), String(definition.effect), color]

var active_player: Node = null
var active_chest: Node = null
var options: Array[StringName] = []
var selected_index := 0
var panel: PanelContainer
var title: Label
var buttons: Array[Button] = []
var network_choice_mode := false

func _ready() -> void:
	add_to_group("attribute_choice_ui")
	_build_interface()
	visible = false

func _build_interface() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.004, 0.012, 0.026, 0.91)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(670, 405)
	panel.add_theme_stylebox_override("panel", PANEL_PRESENTATION.style("inventory/inventory_panel", 20, 25))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var eyebrow := Label.new()
	eyebrow.text = "CYBERFIELD  //  MÓDULO DE EVOLUÇÃO"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 16)
	eyebrow.add_theme_color_override("font_color", Color("61ddec"))
	box.add_child(eyebrow)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("e6f5ff"))
	box.add_child(title)
	var instruction := Label.new()
	instruction.text = "ESCOLHA UMA MELHORIA  //  BÔNUS VÁLIDO NESTA RUN"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_font_size_override("font_size", 14)
	instruction.add_theme_color_override("font_color", Color("97b6c5"))
	box.add_child(instruction)
	for index in 3:
		var button := Button.new()
		button.custom_minimum_size = Vector2(580, 70)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 17)
		PANEL_PRESENTATION.style_button(button)
		button.pressed.connect(_choose.bind(index))
		box.add_child(button)
		buttons.append(button)

func open_for(chest: Node, player: Node, available_options: Array[StringName]) -> bool:
	if visible or player == null or player.is_downed or available_options.is_empty():
		return false
	_close_other_modals()
	active_chest = chest
	active_player = player
	network_choice_mode = false
	options = available_options
	selected_index = 0
	title.text = "%s // %s" % [String(player.participant_id).replace("player_", "P").to_upper(), tr("ESCOLHA UM ATRIBUTO")]
	for index in buttons.size():
		var button: Button = buttons[index]
		button.visible = index < options.size()
		if button.visible:
			var data := _option_data(options[index])
			button.text = "0%d  //  %s  //  %s\n%s" % [index + 1, data[0], data[1], data[2]]
			button.add_theme_color_override("font_color", (data[3] as Color).lerp(Color.WHITE, 0.30))
		button.mouse_filter = Control.MOUSE_FILTER_STOP if player.input_profile == "p1" else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if player.input_profile == "p1" else Control.FOCUS_NONE
	player.set_input_enabled(false)
	_set_touch_controls_blocked(true)
	visible = true
	_play_ui_event(&"ui_open")
	if player.input_profile == "p1":
		buttons[0].grab_focus()
	_update_p2_selection()
	return true


func open_network_for(player: Node, available_options: Array[StringName]) -> bool:
	if visible or player == null or available_options.is_empty():
		return false
	_close_other_modals()
	active_chest = null
	active_player = player
	network_choice_mode = true
	options = available_options
	selected_index = 0
	title.text = "%s // %s" % [String(player.participant_id).replace("player_", "P").to_upper(), tr("ESCOLHA UM ATRIBUTO")]
	for index in buttons.size():
		var button: Button = buttons[index]
		button.visible = index < options.size()
		if button.visible:
			var data := _option_data(options[index])
			button.text = "0%d  //  %s  //  %s\n%s" % [index + 1, data[0], data[1], data[2]]
			button.add_theme_color_override("font_color", (data[3] as Color).lerp(Color.WHITE, 0.30))
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.focus_mode = Control.FOCUS_ALL
	player.set_input_enabled(false)
	_set_touch_controls_blocked(true)
	visible = true
	_play_ui_event(&"ui_open")
	buttons[0].grab_focus()
	_update_p2_selection()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not visible or active_player == null or active_player.input_profile != "p2":
		return
	if event.is_action_pressed("p2_left"):
		selected_index = wrapi(selected_index - 1, 0, options.size())
	elif event.is_action_pressed("p2_right"):
		selected_index = wrapi(selected_index + 1, 0, options.size())
	elif event.is_action_pressed("p2_interact"):
		_choose(selected_index)
	else:
		return
	_update_p2_selection()
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventScreenTouch) or not event.pressed:
		return
	var touch_event := event as InputEventScreenTouch
	for index in options.size():
		var button: Button = buttons[index]
		if button.is_visible_in_tree() and button.get_global_rect().has_point(touch_event.position):
			_choose(index)
			get_viewport().set_input_as_handled()
			return

func _update_p2_selection() -> void:
	for index in options.size():
		PANEL_PRESENTATION.mark_equipped(buttons[index], index == selected_index)

func _choose(index: int) -> void:
	if index < 0 or index >= options.size() or active_player == null:
		return
	if network_choice_mode:
		var selected_attribute: StringName = options[index]
		active_player.set_input_enabled(true)
		visible = false
		_play_ui_event(&"ui_close")
		get_viewport().gui_release_focus()
		active_player = null
		options.clear()
		network_choice_mode = false
		_set_touch_controls_blocked(false)
		network_choice_submitted.emit(selected_attribute)
		return
	if active_chest == null:
		return
	if active_chest.apply_choice(active_player, options[index]):
		active_player.set_input_enabled(true)
		visible = false
		_play_ui_event(&"ui_close")
		get_viewport().gui_release_focus()
		active_player = null
		active_chest = null
		options.clear()
		_set_touch_controls_blocked(false)


func cancel_selection() -> void:
	if active_player:
		active_player.set_input_enabled(true)
	visible = false
	_play_ui_event(&"ui_cancel")
	get_viewport().gui_release_focus()
	active_player = null
	active_chest = null
	options.clear()
	network_choice_mode = false
	_set_touch_controls_blocked(false)


func _close_other_modals() -> void:
	var full_map := get_tree().get_first_node_in_group("full_map")
	if full_map != null and full_map.visible:
		full_map.close_map()
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	if inventory != null and inventory.overlay.visible:
		inventory.close_inventory()
	var pause := get_tree().get_first_node_in_group("pause_menu")
	if pause != null and pause.overlay.visible:
		pause.close_menu()
	visible = false
	active_player = null
	active_chest = null
	options.clear()
	network_choice_mode = false


func _set_touch_controls_blocked(value: bool) -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null:
		return
	var touch_controls := room_manager.get_node_or_null("TouchControls")
	if touch_controls != null and touch_controls.has_method("set_menu_blocked"):
		touch_controls.set_menu_blocked(value)


func _play_ui_event(event_id: StringName) -> void:
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null:
		audio.play_event(event_id)
