extends Control

const MAP_MARGIN := 70.0

var source_teleporter_id: StringName
var _graph: Dictionary = {}
var _blocked_players: Array[Node] = []
var _tree_paused := false
var _destination_panel: VBoxContainer
var _highlighted_teleporter_id: StringName
var _close_button: Button
var _destination_buttons: Dictionary = {}


func _ready() -> void:
	add_to_group("full_map")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_destination_panel = VBoxContainer.new()
	_destination_panel.position = Vector2(size.x - 310.0, 80.0)
	_destination_panel.size = Vector2(250.0, 500.0)
	add_child(_destination_panel)
	_close_button = Button.new()
	_close_button.text = "FECHAR"
	_close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close_button.position = Vector2(-170.0, 20.0)
	_close_button.size = Vector2(150.0, 50.0)
	_close_button.pressed.connect(close_map)
	add_child(_close_button)
	resized.connect(_on_resized)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_map") and not event.is_echo():
		toggle_map()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		close_map()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventScreenTouch and event.pressed:
		var touch_event := event as InputEventScreenTouch
		if _touch_hits(_close_button, touch_event.position):
			close_map()
			get_viewport().set_input_as_handled()
			return
		for button_value: Variant in _destination_buttons:
			var button := button_value as Button
			if _touch_hits(button, touch_event.position):
				_choose_destination(StringName(_destination_buttons[button]))
				get_viewport().set_input_as_handled()
				return


func toggle_map() -> void:
	if visible:
		close_map()
	else:
		open_map()


func open_map(origin_id: StringName = &"") -> void:
	var attribute_ui := get_tree().get_first_node_in_group("attribute_choice_ui")
	if attribute_ui != null and attribute_ui.visible:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or not room_manager.current_is_generated_biome or room_manager.is_transitioning:
		return
	var pause_menu := get_tree().get_first_node_in_group("pause_menu")
	if pause_menu != null and pause_menu.overlay.visible:
		pause_menu.close_menu()
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	if inventory != null and inventory.overlay.visible:
		inventory.close_inventory()
	source_teleporter_id = origin_id
	_graph = room_manager.current_room.get_map_graph()
	_block_local_players(room_manager)
	var lan_session: LanSession = room_manager.get_node("LanSession")
	if not lan_session.is_network_game():
		get_tree().paused = true
		_tree_paused = true
	room_manager.get_node("TouchControls").set_menu_blocked(true)
	visible = true
	_rebuild_destinations()
	queue_redraw()


func close_map() -> void:
	if _tree_paused:
		get_tree().paused = false
		_tree_paused = false
	visible = false
	source_teleporter_id = &""
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.get_node("TouchControls").set_menu_blocked(false)
	for player in _blocked_players:
		if is_instance_valid(player):
			player.set_input_enabled(true)
	_blocked_players.clear()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.015, 0.035, 0.96), true)
	var modules: Array = _graph.get("modules", []) as Array
	if modules.is_empty():
		return
	var state := _map_state()
	if state == null:
		return
	var transform := _map_transform(modules)
	var origin: Vector2 = transform.origin
	var scale: float = transform.scale
	for module_value: Variant in modules:
		var module := module_value as Dictionary
		var module_id := StringName(module.instance_id)
		if not state.discovered_module_ids.has(module_id):
			continue
		var from := origin + Vector2(module.grid) * scale
		for neighbor_value: Variant in module.neighbors:
			var neighbor := modules[int(neighbor_value)] as Dictionary
			if not state.discovered_connections.has(BiomeMapState.connection_id(module_id, StringName(neighbor.instance_id))):
				continue
			var to := origin + Vector2(neighbor.grid) * scale
			draw_line(from, to, Color(0.2, 0.72, 0.9), 5.0, true)
	for module_value: Variant in modules:
		var module := module_value as Dictionary
		if not state.discovered_module_ids.has(StringName(module.instance_id)):
			continue
		var point := origin + Vector2(module.grid) * scale
		var vertical_offset := -7.0 if StringName(module.route_style) == &"upper_lower" else 7.0 if StringName(module.route_style) == &"lower_upper" else 0.0
		draw_rect(Rect2(point + Vector2(-15, -10 + vertical_offset), Vector2(30, 20)), Color(0.12, 0.42, 0.62), true)
	_draw_content(origin, scale, modules, state)
	_draw_players(origin, scale, modules)
	draw_string(ThemeDB.fallback_font, Vector2(54, 48), "MAPA DO BIOMA  //  TAB / ESC PARA FECHAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.75, 0.95, 1.0))


func _draw_content(origin: Vector2, scale: float, modules: Array, state: BiomeMapState) -> void:
	for entry_value: Variant in _graph.get("content_entries", []):
		var entry := entry_value as Dictionary
		var kind := StringName(entry.kind)
		var content_id := StringName(entry.content_id)
		var visible_marker := kind == &"exit" and state.discovered_exit_ids.has(content_id)
		visible_marker = visible_marker or kind == &"loot" and state.discovered_loot_ids.has(content_id) and not state.collected_loot_ids.has(content_id)
		visible_marker = visible_marker or kind == &"attribute" and state.discovered_attribute_ids.has(content_id) and not state.collected_attribute_ids.has(content_id)
		visible_marker = visible_marker or kind == &"weapon" and state.discovered_weapon_ids.has(content_id) and not state.collected_weapon_ids.has(content_id)
		if not visible_marker:
			continue
		var module := modules[int(entry.module_index)] as Dictionary
		var color := Color.ORANGE if kind == &"exit" else Color.YELLOW if kind == &"loot" else Color.CYAN if kind == &"weapon" else Color.MEDIUM_PURPLE
		draw_circle(origin + Vector2(module.grid) * scale + Vector2(0, -18), 6.0, color)
	for entry_value: Variant in _graph.get("teleporters", []):
		var entry := entry_value as Dictionary
		var teleporter_id := StringName(entry.teleporter_id)
		if not state.discovered_teleporter_ids.has(teleporter_id):
			continue
		var module := modules[int(entry.module_index)] as Dictionary
		var point := origin + Vector2(module.grid) * scale + Vector2(18, 0)
		var highlighted := teleporter_id == _highlighted_teleporter_id
		draw_circle(point, 12.0 if highlighted else 8.0, Color.WHITE if highlighted else Color.CYAN, false, 4.0 if highlighted else 3.0)
		var short_label := String(entry.display_name).trim_prefix("SETOR ")
		draw_string(ThemeDB.fallback_font, point + Vector2(12, -10), short_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE if highlighted else Color.CYAN)


func _draw_players(origin: Vector2, scale: float, modules: Array) -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	for player in room_manager.get_players():
		var index := int(room_manager.current_room.get_module_index_at(player.global_position))
		if index < 0:
			continue
		var module := modules[index] as Dictionary
		var color := Color.WHITE if player.participant_id == &"player_1" else Color(0.35, 0.75, 1.0)
		draw_circle(origin + Vector2(module.grid) * scale, 7.0, color)


func _rebuild_destinations() -> void:
	_destination_buttons.clear()
	for child in _destination_panel.get_children():
		child.queue_free()
	if source_teleporter_id.is_empty():
		return
	var title := Label.new()
	title.text = "TELEPORTES ATIVOS"
	_destination_panel.add_child(title)
	var state := _map_state()
	for entry_value: Variant in _graph.get("teleporters", []):
		var entry := entry_value as Dictionary
		var destination_id := StringName(entry.teleporter_id)
		if destination_id == source_teleporter_id or not state.active_teleporter_ids.has(destination_id):
			continue
		var button := Button.new()
		button.text = String(entry.display_name)
		button.pressed.connect(_choose_destination.bind(destination_id))
		button.focus_entered.connect(_highlight_destination.bind(destination_id))
		button.mouse_entered.connect(_highlight_destination.bind(destination_id))
		_destination_panel.add_child(button)
		_destination_buttons[button] = destination_id
		if not button.has_focus():
			button.grab_focus()


func _choose_destination(destination_id: StringName) -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var origin_id := source_teleporter_id
	close_map()
	room_manager.request_fast_travel(origin_id, destination_id)


func _highlight_destination(destination_id: StringName) -> void:
	_highlighted_teleporter_id = destination_id
	queue_redraw()


func _block_local_players(room_manager: Node) -> void:
	_blocked_players.clear()
	var lan_session: LanSession = room_manager.get_node("LanSession")
	for player in room_manager.get_players():
		var local: bool = not lan_session.is_network_game() or lan_session.is_host() and player.participant_id == &"player_1" or lan_session.is_client() and player.participant_id == &"player_2"
		if local and player.input_enabled:
			player.set_input_enabled(false)
			_blocked_players.append(player)


func _map_state() -> BiomeMapState:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	return run_manager.get_current_map_state() if run_manager != null else null


func _touch_hits(control: Control, position: Vector2) -> bool:
	return control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(position)


func _map_transform(modules: Array) -> Dictionary:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for value: Variant in modules:
		var grid := Vector2((value as Dictionary).grid)
		minimum = minimum.min(grid)
		maximum = maximum.max(grid)
	var available := Vector2(size.x - 390.0, size.y) - Vector2.ONE * MAP_MARGIN * 2.0
	var scale := minf(available.x / maxf(maximum.x - minimum.x, 1.0), available.y / maxf(maximum.y - minimum.y, 1.0))
	return {"origin": Vector2(MAP_MARGIN, size.y * 0.5) - Vector2(minimum.x, (minimum.y + maximum.y) * 0.5) * scale, "scale": clampf(scale, 38.0, 92.0)}


func _on_resized() -> void:
	_destination_panel.position = Vector2(size.x - 310.0, 80.0)
