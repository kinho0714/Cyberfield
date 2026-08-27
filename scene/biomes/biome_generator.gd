class_name BiomeGenerator
extends Node2D

const SOURCE_MODULE_SIZE := Vector2(960.0, 540.0)
const CELL_SIZE := Vector2(840.0, 480.0)
const FLOOR_TOP := 420.0
const FLOOR_HEIGHT := 60.0
const ENEMY_SCENE := preload("res://entities/Enemy.tscn")
const RANGED_ENEMY_SCENE := preload("res://entities/RangedEnemy.tscn")
const ATTRIBUTE_CHEST_SCENE := preload("res://scene/interactables/attribute_chest.tscn")
const LOOT_SCENE := preload("res://scene/biomes/biome_loot_placeholder.tscn")
const EXIT_SCENE := preload("res://scene/biomes/biome_exit.tscn")

@export var biome_definition: BiomeDefinition

var generated_module_count := 0
var generation_fallback := false
var generation_failure_reason := ""
var generated_bounds := Rect2()
var generation_signature := ""
var spawned_loot_count := 0
var spawned_attribute_count := 0
var spawned_enemy_count := 0
var _start_position := Vector2.ZERO
var _nodes: Array[Dictionary] = []
var _sockets := {"enemy": [], "loot": [], "attribute": [], "exit": []}
var _exit_module_indices: Array[int] = []
var _content_modules: Dictionary = {
	"loot": [],
	"attribute": [],
	"exit": [],
	"enemy": [],
}


func generate(run_seed: int, run_manager: Node) -> bool:
	_clear_generated_children()
	generation_fallback = false
	generation_failure_reason = ""
	if biome_definition == null:
		return _build_fallback(run_seed, run_manager, "BiomeDefinition ausente")
	var definitions := biome_definition.get_module_definitions()
	if definitions.is_empty():
		return _build_fallback(run_seed, run_manager, "module_pool vazio")
	var maximum_attempts: int = int(biome_definition.generation_rules.get("maximum_attempts", 8))
	maximum_attempts = clampi(maximum_attempts, 1, 32)
	for attempt in maximum_attempts:
		var rng := RandomNumberGenerator.new()
		rng.seed = run_seed + attempt * 104729 + _stable_hash(String(biome_definition.biome_id))
		var target_count := rng.randi_range(biome_definition.min_modules, biome_definition.max_modules)
		_nodes = _build_exploration_layout(target_count, rng)
		_assign_module_roles()
		_assign_module_definitions(definitions, rng)
		var validation := _validate_layout()
		if bool(validation.valid):
			generation_failure_reason = ""
			_build_world(rng, run_manager)
			generated_module_count = _nodes.size()
			return true
		generation_failure_reason = "tentativa %d: %s" % [attempt + 1, String(validation.reason)]
	return _build_fallback(run_seed, run_manager, generation_failure_reason)


func get_start_position() -> Vector2:
	return _start_position


func get_generated_bounds() -> Rect2:
	return generated_bounds


func get_generation_report() -> Dictionary:
	return {
		"biome_id": biome_definition.biome_id if biome_definition else &"fallback",
		"display_name": biome_definition.display_name if biome_definition else "FALLBACK",
		"module_count": generated_module_count,
		"fallback": generation_fallback,
		"failure_reason": generation_failure_reason,
		"exit_count": _exit_module_indices.size(),
		"loot_count": spawned_loot_count,
		"attribute_count": spawned_attribute_count,
		"enemy_count": spawned_enemy_count,
		"signature": generation_signature,
	}


func get_map_graph() -> Dictionary:
	var modules: Array[Dictionary] = []
	for index in _nodes.size():
		var data: Dictionary = _nodes[index]
		var definition := data.definition as BiomeModuleDefinition
		modules.append({
			"index": index,
			"grid": data.grid,
			"world_rect": Rect2(Vector2(data.grid) * CELL_SIZE, CELL_SIZE),
			"neighbors": (data.neighbors as Array).duplicate(),
			"main_route": bool(data.main_route),
			"role": StringName(data.role),
			"module_id": definition.module_id if definition != null else &"unknown",
		})
	return {
		"modules": modules,
		"start_module": 0,
		"exit_modules": _exit_module_indices.duplicate(),
		"content_modules": _content_modules.duplicate(true),
		"cell_size": CELL_SIZE,
		"signature": generation_signature,
	}


func get_module_index_at(world_position: Vector2) -> int:
	for index in _nodes.size():
		var module_rect := Rect2(Vector2(_nodes[index].grid) * CELL_SIZE, CELL_SIZE)
		if module_rect.has_point(world_position):
			return index
	return -1


func _build_exploration_layout(target_count: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	# A compact, Manhattan-connected macro graph. Its two loops force meaningful
	# vertical traversal while every connector remains one safe module step apart.
	var main_route: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, -1),
		Vector2i(3, -1), Vector2i(4, -1), Vector2i(4, 0), Vector2i(5, 0),
		Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1), Vector2i(7, 0),
		Vector2i(8, 0),
	]
	var optional_routes: Array[Vector2i] = [
		Vector2i(4, -2), Vector2i(5, -2), Vector2i(6, -2), Vector2i(6, -1), Vector2i(6, 0),
		Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2), Vector2i(8, 1),
	]
	var desired_count := clampi(target_count, 23, 25)
	if desired_count >= 24:
		optional_routes.append(Vector2i(1, 1))
	if desired_count >= 25:
		optional_routes.append(Vector2i(8, -1))
	var mirror_vertical := rng.randi_range(0, 1) == 1
	var layout: Array[Dictionary] = []
	for coordinate in main_route:
		var grid := Vector2i(coordinate.x, -coordinate.y if mirror_vertical else coordinate.y)
		layout.append(_new_layout_node(grid, true))
	for coordinate in optional_routes:
		var grid := Vector2i(coordinate.x, -coordinate.y if mirror_vertical else coordinate.y)
		layout.append(_new_layout_node(grid, false))
	for first in layout.size():
		var first_grid: Vector2i = layout[first].grid
		for second in range(first + 1, layout.size()):
			var second_grid: Vector2i = layout[second].grid
			if absi(first_grid.x - second_grid.x) + absi(first_grid.y - second_grid.y) == 1:
				_add_edge(layout, first, second)
	var exit_a_grid := Vector2i(6, 2 if mirror_vertical else -2)
	var exit_b_grid := Vector2i(8, -2 if mirror_vertical else 2)
	_exit_module_indices = [_find_grid_index(layout, exit_a_grid), _find_grid_index(layout, exit_b_grid)]
	return layout


func _find_grid_index(layout: Array[Dictionary], grid: Vector2i) -> int:
	for index in layout.size():
		if Vector2i(layout[index].grid) == grid:
			return index
	return -1


func _new_layout_node(grid_position: Vector2i, main_route: bool) -> Dictionary:
	return {
		"grid": grid_position,
		"neighbors": [],
		"main_route": main_route,
		"definition": null,
		"required_connectors": [],
		"role": &"traversal",
	}


func _assign_module_roles() -> void:
	var optional_modules: Array[int] = []
	for index in _nodes.size():
		var data: Dictionary = _nodes[index]
		if index == 0:
			data.role = &"start"
		elif _exit_module_indices.has(index):
			data.role = &"exit"
		elif not bool(data.main_route):
			data.role = &"reward" if (data.neighbors as Array).size() == 1 else &"combat"
			optional_modules.append(index)
		elif index % 4 == 2:
			data.role = &"combat"
		else:
			data.role = &"traversal"
	if not optional_modules.is_empty():
		var reward_positions: Array[int] = [0, floori(optional_modules.size() * 0.5), optional_modules.size() - 1]
		for reward_position in reward_positions:
			_nodes[optional_modules[reward_position]].role = &"reward"


func _add_edge(layout: Array[Dictionary], first: int, second: int) -> void:
	if not layout[first].neighbors.has(second):
		layout[first].neighbors.append(second)
	if not layout[second].neighbors.has(first):
		layout[second].neighbors.append(first)


func _assign_module_definitions(definitions: Array[BiomeModuleDefinition], rng: RandomNumberGenerator) -> void:
	for index in _nodes.size():
		var required := _required_connectors(index)
		_nodes[index].required_connectors = required
		var candidates: Array[BiomeModuleDefinition] = []
		for definition in definitions:
			if definition.supports(required):
				candidates.append(definition)
		var horizontal_only := required.size() == 2 and required.has(&"left") and required.has(&"right")
		if horizontal_only and _nodes[index].role == &"traversal" and index % 3 != 0:
			var route_candidates: Array[BiomeModuleDefinition] = []
			for candidate in candidates:
				if candidate.route_style in ["upper_lower", "lower_upper"]:
					route_candidates.append(candidate)
			if not route_candidates.is_empty():
				candidates = route_candidates
		if _exit_module_indices.has(index):
			var exit_candidates := candidates.filter(func(value: BiomeModuleDefinition) -> bool: return value.module_id == &"exit_platform")
			if not exit_candidates.is_empty():
				candidates = exit_candidates
		_nodes[index].definition = candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else null


func _required_connectors(index: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var current: Vector2i = _nodes[index].grid
	for neighbor_index in _nodes[index].neighbors:
		var difference: Vector2i = _nodes[neighbor_index].grid - current
		var direction: StringName
		if difference.x < 0:
			direction = &"left"
		elif difference.x > 0:
			direction = &"right"
		elif difference.y < 0:
			direction = &"up"
		else:
			direction = &"down"
		if not result.has(direction):
			result.append(direction)
	return result


func _validate_layout() -> Dictionary:
	if _nodes.is_empty():
		return {"valid": false, "reason": "layout vazio"}
	if _exit_module_indices.size() != 2 or _exit_module_indices[0] == _exit_module_indices[1]:
		return {"valid": false, "reason": "saídas inválidas"}
	var occupied := {}
	for index in _nodes.size():
		var grid_key := str(_nodes[index].grid)
		if occupied.has(grid_key):
			return {"valid": false, "reason": "sobreposição em %s" % grid_key}
		occupied[grid_key] = true
		var definition := _nodes[index].definition as BiomeModuleDefinition
		if definition == null or not definition.supports(_nodes[index].required_connectors):
			return {"valid": false, "reason": "conectores incompatíveis no módulo %d" % index}
	var visited := {}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		for neighbor in _nodes[current].neighbors:
			if not visited.has(neighbor):
				queue.append(neighbor)
	for index in _nodes.size():
		if not visited.has(index):
			return {"valid": false, "reason": "módulo %d desconectado" % index}
	for exit_index in _exit_module_indices:
		if not visited.has(exit_index):
			return {"valid": false, "reason": "saída inalcançável"}
		var exit_definition := _nodes[exit_index].definition as BiomeModuleDefinition
		if exit_definition.exit_sockets.is_empty() or exit_definition.attribute_sockets.is_empty():
			return {"valid": false, "reason": "saída sem sockets obrigatórios"}
	var loot_capacity := 0
	var enemy_capacity := 0
	for data in _nodes:
		var definition := data.definition as BiomeModuleDefinition
		loot_capacity += definition.loot_sockets.size()
		enemy_capacity += definition.enemy_sockets.size()
	if loot_capacity < 3 or enemy_capacity < 7:
		return {"valid": false, "reason": "capacidade de conteúdo insuficiente"}
	return {"valid": true, "reason": ""}


func _build_world(rng: RandomNumberGenerator, run_manager: Node) -> void:
	_sockets = {"enemy": [], "loot": [], "attribute": [], "exit": []}
	spawned_loot_count = 0
	spawned_attribute_count = 0
	spawned_enemy_count = 0
	_content_modules = {"loot": [], "attribute": [], "exit": [], "enemy": []}
	generation_signature = _build_generation_signature()
	var modules_root := Node2D.new()
	modules_root.name = "Modules"
	add_child(modules_root)
	for index in _nodes.size():
		_build_module(modules_root, index)
	_build_vertical_connections()
	_build_outer_safety()
	_start_position = Vector2(140.0, FLOOR_TOP - 36.0)
	_spawn_required_content(rng, run_manager)
	generated_bounds = _calculate_bounds().grow(160.0)


func _build_module(parent: Node2D, index: int) -> void:
	var data: Dictionary = _nodes[index]
	var definition := data.definition as BiomeModuleDefinition
	var module := Node2D.new()
	module.name = "Module_%02d_%s" % [index, definition.module_id]
	module.position = Vector2(data.grid) * CELL_SIZE
	module.set_meta("module_index", index)
	module.set_meta("module_id", definition.module_id)
	parent.add_child(module)
	if definition.custom_scene != null:
		module.add_child(definition.custom_scene.instantiate())
	else:
		var background := Polygon2D.new()
		background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(CELL_SIZE.x, 0.0), CELL_SIZE, Vector2(0.0, CELL_SIZE.y)])
		background.color = Color(0.018, 0.045, 0.075, 1.0) if int(data.grid.y) == 0 else Color(0.025, 0.06, 0.09, 1.0)
		background.z_index = -10
		module.add_child(background)
	_build_floor(module, data.required_connectors.has(&"down"))
	var has_vertical_route: bool = data.required_connectors.has(&"up") or data.required_connectors.has(&"down")
	var has_internal_routes := definition.route_style in ["upper_lower", "lower_upper"]
	var has_purposeful_platforms: bool = has_vertical_route or has_internal_routes or data.role in [&"combat", &"reward", &"exit"]
	if has_purposeful_platforms:
		for platform_rect in definition.platform_rects:
			_add_static_rect(module, _scale_source_rect(platform_rect), Color(0.09, 0.23, 0.28, 1.0))
	_create_module_sockets(module, definition, index)
	if biome_definition.debug_draw_modules:
		var label := Label.new()
		label.position = Vector2(24.0, 24.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "MODULE %02d // %s\nGRID %s" % [index, definition.display_name, data.grid]
		module.add_child(label)
	if biome_definition.debug_draw_connectors:
		for direction in data.required_connectors:
			_add_connector_debug(module, direction)


func _build_floor(module: Node2D, has_down_connection: bool) -> void:
	if has_down_connection:
		var opening_half_width := 70.0
		var left_width := CELL_SIZE.x * 0.5 - opening_half_width
		var right_start := CELL_SIZE.x * 0.5 + opening_half_width
		_add_static_rect(module, Rect2(0.0, FLOOR_TOP, left_width, FLOOR_HEIGHT), Color(0.08, 0.18, 0.23, 1.0))
		_add_static_rect(module, Rect2(right_start, FLOOR_TOP, CELL_SIZE.x - right_start, FLOOR_HEIGHT), Color(0.08, 0.18, 0.23, 1.0))
	else:
		_add_static_rect(module, Rect2(0.0, FLOOR_TOP, CELL_SIZE.x, FLOOR_HEIGHT), Color(0.08, 0.18, 0.23, 1.0))


func _add_static_rect(parent: Node2D, rectangle: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = rectangle.position + rectangle.size * 0.5
	parent.add_child(body)
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rectangle.size
	shape_node.shape = shape
	body.add_child(shape_node)
	var visual := Polygon2D.new()
	var half := rectangle.size * 0.5
	visual.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	visual.color = color
	body.add_child(visual)


func _create_module_sockets(module: Node2D, definition: BiomeModuleDefinition, module_index: int) -> void:
	_create_socket_type(module, definition.enemy_sockets, &"enemy", module_index)
	_create_socket_type(module, definition.loot_sockets, &"loot", module_index)
	_create_socket_type(module, definition.attribute_sockets, &"attribute", module_index)
	_create_socket_type(module, definition.exit_sockets, &"exit", module_index)


func _create_socket_type(module: Node2D, positions: Array[Vector2], socket_type: StringName, module_index: int) -> void:
	for socket_index in positions.size():
		var marker := Marker2D.new()
		marker.name = "%s_%02d_%02d" % [socket_type, module_index, socket_index]
		marker.position = _scale_source_position(positions[socket_index])
		marker.add_to_group(StringName("%s_spawn_point" % socket_type))
		marker.set_meta("module_index", module_index)
		module.add_child(marker)
		_sockets[socket_type].append(marker)
		if biome_definition.debug_draw_sockets:
			var label := Label.new()
			label.position = Vector2(-45.0, -24.0)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.text = String(socket_type).to_upper()
			marker.add_child(label)


func _add_connector_debug(module: Node2D, direction: StringName) -> void:
	var marker := Marker2D.new()
	marker.name = "Connector_%s" % direction
	match direction:
		&"left": marker.position = Vector2(12.0, FLOOR_TOP - 40.0)
		&"right": marker.position = Vector2(CELL_SIZE.x - 12.0, FLOOR_TOP - 40.0)
		&"up": marker.position = Vector2(CELL_SIZE.x * 0.5, 12.0)
		&"down": marker.position = Vector2(CELL_SIZE.x * 0.5, CELL_SIZE.y - 12.0)
	module.add_child(marker)
	var label := Label.new()
	label.position = Vector2(-28.0, -14.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = String(direction).to_upper()
	label.modulate = Color(0.1, 0.95, 1.0)
	marker.add_child(label)


func _build_vertical_connections() -> void:
	var connections := Node2D.new()
	connections.name = "VerticalConnections"
	add_child(connections)
	for index in _nodes.size():
		var origin_grid: Vector2i = _nodes[index].grid
		for neighbor_index in _nodes[index].neighbors:
			if neighbor_index <= index:
				continue
			var neighbor_grid: Vector2i = _nodes[neighbor_index].grid
			if origin_grid.x != neighbor_grid.x:
				continue
			var upper_y := mini(origin_grid.y, neighbor_grid.y) * int(CELL_SIZE.y)
			var lower_floor := maxi(origin_grid.y, neighbor_grid.y) * int(CELL_SIZE.y) + int(FLOOR_TOP)
			var center_x := origin_grid.x * int(CELL_SIZE.x) + int(CELL_SIZE.x * 0.5)
			var shaft_top := upper_y + int(FLOOR_TOP) + 8
			var shaft_height := lower_floor - shaft_top
			# Two continuous climbable walls replace the old artificial staircase.
			# Small opposed rests keep the route bidirectional without filling it.
			_add_static_rect(connections, Rect2(center_x - 92.0, shaft_top, 18.0, shaft_height), Color(0.11, 0.35, 0.38, 1.0))
			_add_static_rect(connections, Rect2(center_x + 74.0, shaft_top, 18.0, shaft_height), Color(0.11, 0.35, 0.38, 1.0))
			_add_static_rect(connections, Rect2(center_x - 74.0, shaft_top + shaft_height * 0.34, 72.0, 16.0), Color(0.11, 0.35, 0.38, 1.0))
			_add_static_rect(connections, Rect2(center_x + 2.0, shaft_top + shaft_height * 0.68, 72.0, 16.0), Color(0.11, 0.35, 0.38, 1.0))


func _spawn_required_content(rng: RandomNumberGenerator, run_manager: Node) -> void:
	var stage_prefix := String(run_manager.current_stage_id) if not String(run_manager.current_stage_id).is_empty() else "lower_city"
	var exit_a: StringName = biome_definition.possible_exits[0] if biome_definition.possible_exits.size() > 0 else &"exit_a"
	var exit_b: StringName = biome_definition.possible_exits[1] if biome_definition.possible_exits.size() > 1 else &"exit_b"
	_spawn_exit(0, _exit_module_indices[0], exit_a, &"next_biome_a")
	_spawn_exit(1, _exit_module_indices[1], exit_b, &"next_biome_b")
	_spawn_attribute_reward(0, _exit_module_indices[0], stage_prefix)
	_spawn_attribute_reward(1, _exit_module_indices[1], stage_prefix)
	_spawn_loot(rng, run_manager, stage_prefix)
	_spawn_enemies(rng, run_manager, stage_prefix)


func _spawn_exit(socket_order: int, module_index: int, exit_id: StringName, destination: StringName) -> void:
	var marker := _find_socket_for_module(&"exit", module_index)
	if marker == null:
		return
	var exit := EXIT_SCENE.instantiate()
	exit.name = String(exit_id).to_pascal_case()
	exit.exit_id = exit_id
	exit.destination_id = destination
	add_child(exit)
	exit.global_position = marker.global_position
	(_content_modules.exit as Array).append(module_index)
	var exit_label := "A" if socket_order == 0 else "B"
	exit.get_node("Label").text = "EXIT %s → %s" % [exit_label, destination]


func _spawn_attribute_reward(reward_index: int, module_index: int, stage_prefix: String) -> void:
	var marker := _find_socket_for_module(&"attribute", module_index)
	if marker == null:
		return
	var chest := ATTRIBUTE_CHEST_SCENE.instantiate()
	chest.name = "ExitAttributeReward%d" % (reward_index + 1)
	chest.chest_type = "free"
	var exit_suffix := "a" if reward_index == 0 else "b"
	chest.chest_id = StringName("%s_exit_%s_attribute" % [stage_prefix, exit_suffix])
	add_child(chest)
	chest.global_position = marker.global_position
	spawned_attribute_count += 1
	(_content_modules.attribute as Array).append(module_index)


func _spawn_loot(rng: RandomNumberGenerator, run_manager: Node, stage_prefix: String) -> void:
	var candidates: Array = _sockets.loot.duplicate()
	candidates = candidates.filter(func(marker: Marker2D) -> bool:
		var module_index := int(marker.get_meta("module_index"))
		return module_index != 0 and not _exit_module_indices.has(module_index) and _nodes[module_index].role == &"reward"
	)
	_shuffle(candidates, rng)
	var configured_maximum := clampi(biome_definition.loot_chest_count, 2, 3)
	var desired_count := mini(configured_maximum, candidates.size())
	var selected: Array[Marker2D] = []
	var used_modules: Dictionary = {}
	for marker in candidates:
		var module_index := int(marker.get_meta("module_index"))
		if (_nodes[module_index].neighbors as Array).size() == 1:
			selected.append(marker)
			used_modules[module_index] = true
			if selected.size() >= desired_count:
				break
	for marker in candidates:
		if selected.size() >= desired_count:
			break
		var module_index := int(marker.get_meta("module_index"))
		if not bool(_nodes[module_index].main_route) and not used_modules.has(module_index):
			selected.append(marker)
			used_modules[module_index] = true
			break
	for marker in candidates:
		if selected.size() >= desired_count:
			break
		var module_index := int(marker.get_meta("module_index"))
		if selected.has(marker) or used_modules.has(module_index):
			continue
		selected.append(marker)
		used_modules[module_index] = true
	for index in selected.size():
		var marker := selected[index]
		var loot := LOOT_SCENE.instantiate()
		loot.name = "BiomeLoot%02d" % (index + 1)
		loot.loot_id = StringName("%s_loot_%02d" % [stage_prefix, index + 1])
		loot.amount = 15 + run_manager.extra_enemy_count * 5
		add_child(loot)
		loot.global_position = marker.global_position
		spawned_loot_count += 1
		(_content_modules.loot as Array).append(int(marker.get_meta("module_index")))


func _spawn_enemies(rng: RandomNumberGenerator, run_manager: Node, stage_prefix: String) -> void:
	var candidates: Array = _sockets.enemy.duplicate()
	candidates = candidates.filter(func(marker: Marker2D) -> bool: return int(marker.get_meta("module_index")) != 0 and not _exit_module_indices.has(int(marker.get_meta("module_index"))))
	_shuffle(candidates, rng)
	var priority_candidates: Array[Marker2D] = []
	var traversal_candidates: Array[Marker2D] = []
	for marker_value: Variant in candidates:
		var marker := marker_value as Marker2D
		var module_index := int(marker.get_meta("module_index"))
		if _nodes[module_index].role in [&"combat", &"reward"]:
			priority_candidates.append(marker)
		else:
			traversal_candidates.append(marker)
	var ordered_candidates: Array[Marker2D] = []
	ordered_candidates.append_array(priority_candidates)
	ordered_candidates.append_array(traversal_candidates)
	var desired_count := mini(12 + run_manager.extra_enemy_count * 2, ordered_candidates.size())
	var ranged_count := mini(maxi(2, desired_count / 4) + run_manager.extra_enemy_count, desired_count)
	for index in desired_count:
		var enemy := RANGED_ENEMY_SCENE.instantiate() if index < ranged_count else ENEMY_SCENE.instantiate()
		enemy.name = "LowerCityEnemy%02d" % (index + 1)
		enemy.persistent_id = StringName("%s_enemy_%02d" % [stage_prefix, index + 1])
		enemy.run_room_id = StringName(stage_prefix)
		add_child(enemy)
		enemy.global_position = ordered_candidates[index].global_position
		spawned_enemy_count += 1
		var module_index := int(ordered_candidates[index].get_meta("module_index"))
		if not (_content_modules.enemy as Array).has(module_index):
			(_content_modules.enemy as Array).append(module_index)


func _find_socket_for_module(socket_type: StringName, module_index: int) -> Marker2D:
	for marker in _sockets[socket_type]:
		if int(marker.get_meta("module_index")) == module_index:
			return marker as Marker2D
	return null


func _build_outer_safety() -> void:
	var bounds := _calculate_bounds()
	var safety := Node2D.new()
	safety.name = "WorldSafety"
	add_child(safety)
	_add_static_rect(safety, Rect2(bounds.position.x - 60.0, bounds.position.y - 200.0, 60.0, bounds.size.y + 400.0), Color.TRANSPARENT)
	_add_static_rect(safety, Rect2(bounds.end.x, bounds.position.y - 200.0, 60.0, bounds.size.y + 400.0), Color.TRANSPARENT)
	var kill_zone := Area2D.new()
	kill_zone.collision_layer = 0
	kill_zone.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(bounds.size.x + 240.0, 100.0)
	collision.shape = shape
	collision.position = Vector2(bounds.get_center().x, bounds.end.y + 220.0)
	kill_zone.add_child(collision)
	kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	safety.add_child(kill_zone)


func _calculate_bounds() -> Rect2:
	if _nodes.is_empty():
		return Rect2(0.0, 0.0, 1280.0, 720.0)
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for data in _nodes:
		var position := Vector2(data.grid) * CELL_SIZE
		minimum = minimum.min(position)
		maximum = maximum.max(position + CELL_SIZE)
	return Rect2(minimum, maximum - minimum)


func _build_fallback(run_seed: int, run_manager: Node, reason: String) -> bool:
	generation_fallback = true
	generation_failure_reason = reason
	var definitions: Array[BiomeModuleDefinition] = []
	if biome_definition != null:
		definitions = biome_definition.get_module_definitions()
	var corridor: BiomeModuleDefinition = null
	for definition in definitions:
		if definition.module_id == &"corridor":
			corridor = definition
			break
	if corridor == null:
		push_error("GENERATION FALLBACK FAILED: %s" % reason)
		return false
	_nodes.clear()
	for x in 5:
		_nodes.append(_new_layout_node(Vector2i(x, 0), true))
		_nodes[x].definition = corridor
		if x > 0:
			_add_edge(_nodes, x - 1, x)
	for index in _nodes.size():
		_nodes[index].required_connectors = _required_connectors(index)
	_exit_module_indices = [3, 4]
	_assign_module_roles()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	_build_world(rng, run_manager)
	generated_module_count = _nodes.size()
	push_warning("GENERATION FALLBACK: %s" % reason)
	return true


func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func _build_generation_signature() -> String:
	var parts: PackedStringArray = []
	for index in _nodes.size():
		var definition := _nodes[index].definition as BiomeModuleDefinition
		parts.append("%d:%s:%s:%s" % [index, _nodes[index].grid, definition.module_id, _nodes[index].neighbors])
	return "|".join(parts)


func _clear_generated_children() -> void:
	for child in get_children():
		child.queue_free()
	_nodes.clear()
	_exit_module_indices.clear()
	_content_modules = {"loot": [], "attribute": [], "exit": [], "enemy": []}


func _scale_source_position(value: Vector2) -> Vector2:
	return value * (CELL_SIZE / SOURCE_MODULE_SIZE)


func _scale_source_rect(value: Rect2) -> Rect2:
	var scale_factor := CELL_SIZE / SOURCE_MODULE_SIZE
	return Rect2(value.position * scale_factor, value.size * scale_factor)


func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("enter_downed"):
		body.enter_downed()


func _stable_hash(value: String) -> int:
	var result := 2166136261
	for byte in value.to_utf8_buffer():
		result = int((result ^ byte) * 16777619) & 0x7fffffff
	return result
