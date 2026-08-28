extends Control

const MAP_PADDING := 14.0
@export var update_interval := 0.12

var _graph: Dictionary = {}
var _discovered: Dictionary = {}
var _elapsed := 0.0
var _source_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	visible = false


func _on_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	var activated: bool = event is InputEventScreenTouch and bool(event.pressed)
	activated = activated or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if activated:
		var full_map := get_tree().get_first_node_in_group("full_map")
		if full_map != null:
			full_map.open_map()
		accept_event()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < update_interval:
		return
	_elapsed = 0.0
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager != null and (run_manager.run_is_lost or run_manager.run_is_completed):
		visible = false
		return
	if room_manager == null or not bool(room_manager.current_is_generated_biome):
		visible = false
		return
	var biome_root: Node = room_manager.current_room
	if biome_root == null or not biome_root.has_method("get_map_graph"):
		visible = false
		return
	var next_graph: Dictionary = biome_root.get_map_graph()
	var next_signature := String(next_graph.get("signature", ""))
	if next_signature != _source_signature:
		_source_signature = next_signature
		_graph = next_graph
		_discovered.clear()
	visible = true
	_discover_player_modules(room_manager.get_players(), biome_root)
	_sync_discovered_from_state()
	queue_redraw()


func _discover_player_modules(players: Array[Node], biome_root: Node) -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var lan_session: LanSession = room_manager.get_node("LanSession")
	var modules: Array = _graph.get("modules", []) as Array
	for player in players:
		if not player.visible:
			continue
		var module_index := int(biome_root.get_module_index_at(player.global_position))
		if module_index < 0 or module_index >= modules.size():
			continue
		var module := modules[module_index] as Dictionary
		var module_id := StringName(module.instance_id)
		if lan_session.is_client():
			if player.participant_id == &"player_2" and not run_manager.get_current_map_state().discovered_module_ids.has(module_id):
				lan_session.request_map_discovery(module_id)
			continue
		var neighbors: Array[StringName] = []
		for neighbor_value: Variant in module.neighbors:
			neighbors.append(StringName((modules[int(neighbor_value)] as Dictionary).instance_id))
		run_manager.discover_map_module(module_id, neighbors)
		_discover_module_content(run_manager, module_index)


func _discover_module_content(run_manager: Node, module_index: int) -> void:
	for entry_value: Variant in _graph.get("content_entries", []):
		var entry := entry_value as Dictionary
		if int(entry.module_index) == module_index:
			run_manager.discover_map_content(StringName(entry.kind), StringName(entry.content_id))
	for entry_value: Variant in _graph.get("teleporters", []):
		var entry := entry_value as Dictionary
		if int(entry.module_index) == module_index:
			run_manager.discover_map_content(&"teleporter", StringName(entry.teleporter_id))


func _sync_discovered_from_state() -> void:
	_discovered.clear()
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var state: BiomeMapState = run_manager.get_current_map_state()
	for module_value: Variant in _graph.get("modules", []):
		var module := module_value as Dictionary
		if state.discovered_module_ids.has(StringName(module.instance_id)):
			_discovered[int(module.index)] = true


func _draw() -> void:
	if _graph.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.025, 0.05, 0.84), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.75, 0.9, 0.7), false, 2.0)
	var modules: Array = _graph.get("modules", []) as Array
	if modules.is_empty():
		return
	var transform_data := _calculate_map_transform(modules)
	var map_origin: Vector2 = transform_data.origin
	var map_scale: float = transform_data.scale
	for module_value: Variant in modules:
		var module: Dictionary = module_value as Dictionary
		var module_index := int(module.index)
		if not _discovered.has(module_index):
			continue
		var from_point := map_origin + Vector2(module.grid) * map_scale
		var neighbors: Array = module.neighbors as Array
		for neighbor_value: Variant in neighbors:
			var neighbor_index := int(neighbor_value)
			if neighbor_index <= module_index or not _discovered.has(neighbor_index):
				continue
			var neighbor: Dictionary = modules[neighbor_index] as Dictionary
			var to := map_origin + Vector2(neighbor.grid) * map_scale
			draw_line(from_point, to, Color(0.2, 0.65, 0.8, 0.8), 3.0, true)
	for module_value: Variant in modules:
		var module: Dictionary = module_value as Dictionary
		var module_index := int(module.index)
		if not _discovered.has(module_index):
			continue
		var point := map_origin + Vector2(module.grid) * map_scale
		var role := StringName(module.role)
		var color := Color(0.15, 0.42, 0.58, 1.0)
		if role == &"start":
			color = Color(0.3, 0.95, 0.55, 1.0)
		elif role == &"exit":
			color = Color(1.0, 0.72, 0.2, 1.0)
		elif role == &"reward":
			color = Color(0.75, 0.4, 1.0, 1.0)
		draw_circle(point, 6.0, color)
	_draw_discovered_content(modules, map_origin, map_scale)
	_draw_teleporters(modules, map_origin, map_scale)
	_draw_players(map_origin, map_scale)


func _draw_discovered_content(modules: Array, map_origin: Vector2, map_scale: float) -> void:
	var state: BiomeMapState = get_tree().get_first_node_in_group("run_manager").get_current_map_state()
	var content: Dictionary = _graph.get("content_modules", {}) as Dictionary
	var styles := {
		"loot": {"color": Color(1.0, 0.9, 0.25), "offset": Vector2(-7.0, -7.0)},
		"attribute": {"color": Color(0.72, 0.35, 1.0), "offset": Vector2(7.0, -7.0)},
		"weapon": {"color": Color(0.25, 0.9, 1.0), "offset": Vector2(-7.0, 7.0)},
		"exit": {"color": Color(1.0, 0.55, 0.15), "offset": Vector2(0.0, 8.0)},
	}
	for content_type_value: Variant in styles.keys():
		var content_type := String(content_type_value)
		var style: Dictionary = styles[content_type] as Dictionary
		var content_offset: Vector2 = style.get("offset", Vector2.ZERO)
		var content_color: Color = style.get("color", Color.WHITE)
		var module_indices: Array = content.get(content_type, []) as Array
		for module_index_value: Variant in module_indices:
			var module_index := int(module_index_value)
			if not _discovered.has(module_index) or module_index < 0 or module_index >= modules.size():
				continue
			var has_visible_entry := false
			for entry_value: Variant in _graph.get("content_entries", []):
				var entry := entry_value as Dictionary
				if String(entry.kind) != content_type or int(entry.module_index) != module_index:
					continue
				var content_id := StringName(entry.content_id)
				has_visible_entry = content_type == "exit" and state.discovered_exit_ids.has(content_id)
				has_visible_entry = has_visible_entry or content_type == "loot" and state.discovered_loot_ids.has(content_id) and not state.collected_loot_ids.has(content_id)
				has_visible_entry = has_visible_entry or content_type == "attribute" and state.discovered_attribute_ids.has(content_id) and not state.collected_attribute_ids.has(content_id)
				has_visible_entry = has_visible_entry or content_type == "weapon" and state.discovered_weapon_ids.has(content_id) and not state.collected_weapon_ids.has(content_id)
				if has_visible_entry:
					break
			if not has_visible_entry:
				continue
			var module: Dictionary = modules[module_index] as Dictionary
			var point := map_origin + Vector2(module.grid) * map_scale + content_offset
			draw_rect(Rect2(point - Vector2.ONE * 2.5, Vector2.ONE * 5.0), content_color, true)


func _draw_players(map_origin: Vector2, map_scale: float) -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or room_manager.current_room == null:
		return
	for player in room_manager.get_players():
		if not player.visible:
			continue
		var module_index := int(room_manager.current_room.get_module_index_at(player.global_position))
		if module_index < 0:
			continue
		var modules: Array = _graph.get("modules", []) as Array
		var module: Dictionary = modules[module_index] as Dictionary
		var point := map_origin + Vector2(module.grid) * map_scale
		var color := Color.WHITE if player.participant_id == &"player_1" else Color(0.35, 0.75, 1.0)
		draw_circle(point, 3.0, color)
		draw_arc(point, 9.0, 0.0, TAU, 24, color, 2.0, true)


func _draw_teleporters(modules: Array, map_origin: Vector2, map_scale: float) -> void:
	var state: BiomeMapState = get_tree().get_first_node_in_group("run_manager").get_current_map_state()
	for entry_value: Variant in _graph.get("teleporters", []):
		var entry := entry_value as Dictionary
		if not state.active_teleporter_ids.has(StringName(entry.teleporter_id)):
			continue
		var module := modules[int(entry.module_index)] as Dictionary
		var point := map_origin + Vector2(module.grid) * map_scale + Vector2(8, 0)
		draw_circle(point, 4.5, Color.CYAN, false, 2.0)


func _calculate_map_transform(modules: Array) -> Dictionary:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for module_value: Variant in modules:
		var module: Dictionary = module_value as Dictionary
		var grid := Vector2(module.grid)
		minimum = minimum.min(grid)
		maximum = maximum.max(grid)
	var grid_size := (maximum - minimum).max(Vector2.ONE)
	var usable_size := size - Vector2.ONE * MAP_PADDING * 2.0
	var map_scale := minf(usable_size.x / grid_size.x, usable_size.y / grid_size.y)
	map_scale = clampf(map_scale, 14.0, 34.0)
	var drawn_size := grid_size * map_scale
	var origin := (size - drawn_size) * 0.5 - minimum * map_scale
	return {"origin": origin, "scale": map_scale}
