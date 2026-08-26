extends CanvasLayer

const LABELS := {
	&"intellect": ["INTELECTO", "+0,5 s de stamina de escalada", Color(1.0, 0.5, 0.1)],
	&"health": ["SAÚDE", "+5 HP máximo (sem cura)", Color(0.2, 0.9, 0.3)],
	&"strength": ["FORÇA", "+1 dano melee e slam", Color(1.0, 0.2, 0.2)],
}

var active_player: Node = null
var active_chest: Node = null
var options: Array[StringName] = []
var selected_index := 0
var panel: PanelContainer
var title: Label
var buttons: Array[Button] = []

func _ready() -> void:
	add_to_group("attribute_choice_ui")
	_build_interface()
	visible = false

func _build_interface() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.78)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 280)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	for index in 3:
		var button := Button.new()
		button.custom_minimum_size = Vector2(480, 56)
		button.pressed.connect(_choose.bind(index))
		box.add_child(button)
		buttons.append(button)

func open_for(chest: Node, player: Node, available_options: Array[StringName]) -> bool:
	if visible or player == null or player.is_downed or available_options.is_empty():
		return false
	active_chest = chest
	active_player = player
	options = available_options
	selected_index = 0
	title.text = "%s // ESCOLHA UM ATRIBUTO" % String(player.participant_id).to_upper()
	for index in buttons.size():
		var button := buttons[index]
		button.visible = index < options.size()
		if button.visible:
			var data: Array = LABELS[options[index]]
			button.text = "%s — %s" % [data[0], data[1]]
			button.modulate = data[2]
		button.mouse_filter = Control.MOUSE_FILTER_STOP if player.input_profile == "p1" else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if player.input_profile == "p1" else Control.FOCUS_NONE
	player.set_input_enabled(false)
	visible = true
	if player.input_profile == "p1":
		buttons[0].grab_focus()
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

func _update_p2_selection() -> void:
	for index in options.size():
		buttons[index].button_pressed = index == selected_index

func _choose(index: int) -> void:
	if index < 0 or index >= options.size() or active_chest == null or active_player == null:
		return
	if active_chest.apply_choice(active_player, options[index]):
		active_player.set_input_enabled(true)
		visible = false
		active_player = null
		active_chest = null
		options.clear()


func cancel_selection() -> void:
	if active_player:
		active_player.set_input_enabled(false)
	visible = false
	active_player = null
	active_chest = null
	options.clear()
