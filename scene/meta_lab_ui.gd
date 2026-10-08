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
