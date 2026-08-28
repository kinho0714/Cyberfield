class_name MetaLabUI
extends CanvasLayer

var overlay: ColorRect
var credits_label: Label
var stats_label: Label
var purchase_buttons: Dictionary = {}
var close_button: Button
var blocked_player: Node


func _ready() -> void:
	add_to_group("meta_lab_ui")
	layer = 88
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.005, 0.018, 0.035, 0.96)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 510)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 26)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "TERMINAL DE PREPARAÇÃO"
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
	for item_value: Variant in MetaProgression.PURCHASES:
		var item_id := StringName(item_value)
		var button := Button.new()
		button.custom_minimum_size = Vector2(590, 58)
		button.pressed.connect(_purchase.bind(item_id))
		column.add_child(button)
		purchase_buttons[item_id] = button
	close_button = Button.new()
	close_button.text = "VOLTAR AO LABORATÓRIO"
	close_button.custom_minimum_size = Vector2(590, 54)
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
	_refresh()
	close_button.grab_focus()


func close_terminal() -> void:
	overlay.visible = false
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


func _purchase(item_id: StringName) -> void:
	var meta := get_tree().get_first_node_in_group("meta_progression") as MetaProgression
	if meta != null:
		meta.purchase(item_id)
	_refresh()


func _refresh() -> void:
	var meta := get_tree().get_first_node_in_group("meta_progression") as MetaProgression
	if meta == null:
		return
	credits_label.text = "CRÉDITOS PERMANENTES  ◈ %d" % meta.credits
	var best_time := float(meta.statistics.get("best_time", 0.0))
	var best_time_text := "%02d:%02d" % [floori(best_time / 60.0), floori(best_time) % 60] if best_time > 0.0 else "--:--"
	stats_label.text = "RUNS %d   VITÓRIAS %d   MORTES %d   BOSSES %d\nMAIOR STAGE %d/6   MELHOR TEMPO %s" % [int(meta.statistics.get("runs", 0)), int(meta.statistics.get("victories", 0)), int(meta.statistics.get("deaths", 0)), int(meta.statistics.get("bosses_defeated", 0)), int(meta.statistics.get("highest_stage", 0)), best_time_text]
	for item_value: Variant in purchase_buttons:
		var item_id := StringName(item_value)
		var definition: Dictionary = MetaProgression.PURCHASES[item_id]
		var button := purchase_buttons[item_id] as Button
		var unlocked := meta.is_unlocked(item_id)
		button.text = "%s  //  %s" % [String(definition.get("name", item_id)), "DESBLOQUEADO" if unlocked else "◈ %d" % int(definition.get("cost", 0))]
		button.disabled = unlocked or meta.credits < int(definition.get("cost", 0))
