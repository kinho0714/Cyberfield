class_name BiomeGenerator
extends Node2D

const SOURCE_MODULE_SIZE := Vector2(960.0, 540.0)
const CELL_SIZE := Vector2(840.0, 480.0)
const FLOOR_TOP := 420.0
const FLOOR_HEIGHT := 60.0
const OUTER_BOUNDARY_THICKNESS := 96.0
const OUTER_BOUNDARY_VERTICAL_MARGIN := CELL_SIZE.y * 2.0
const ENEMY_SCENE := preload("res://entities/Enemy.tscn")
const RANGED_ENEMY_SCENE := preload("res://entities/RangedEnemy.tscn")
const HEAVY_ENEMY_SCENE := preload("res://entities/HeavyEnemy.tscn")
const TRAP_CHEST_SCENE := preload("res://scene/interactables/trap_chest.tscn")
const ATTRIBUTE_CHEST_SCENE := preload("res://scene/interactables/attribute_chest.tscn")
const LOOT_SCENE := preload("res://scene/biomes/biome_loot_placeholder.tscn")
const EXIT_SCENE := preload("res://scene/biomes/biome_exit.tscn")
const TELEPORTER_SCRIPT := preload("res://scene/biomes/biome_teleporter.gd")
const WEAPON_PICKUP_SCRIPT := preload("res://scene/weapons/weapon_pickup.gd")
const GUARD_RAIL_WIDTH := 18.0
const GUARD_RAIL_HEIGHT := FLOOR_TOP
const MINIMUM_FUNCTIONAL_PLATFORM_WIDTH := 150.0
const UPPER_BOUND_MARGIN := CELL_SIZE.y * 0.75
const SPECIAL_WEAPON_DROP_CHANCE := 0.38
const SPAWN_EDGE_CLEARANCE := 72.0
const TRAP_CHEST_CHANCE := 0.12
const VERTICAL_SHAFT_INNER_WIDTH := 136.0
const VERTICAL_SHAFT_WALL_THICKNESS := 18.0
const MINIMUM_TRAVERSAL_CLEARANCE := 112.0
const MINIMUM_STACKED_PASSAGE_OVERLAP := 32.0

@export var biome_definition: BiomeDefinition

var generated_module_count := 0
var generation_fallback := false
var generation_failure_reason := ""
var generated_bounds := Rect2()
var generation_signature := ""
var spawned_loot_count := 0
var spawned_attribute_count := 0
var spawned_enemy_count := 0
var spawned_ranged_count := 0
var spawned_heavy_count := 0
var spawned_trap_chest_count := 0
var rejected_layout_count := 0
var rejected_micro_ledge_count := 0
var invalid_platform_clearance_count := 0
var minimum_platform_clearance: float = INF
var _start_position := Vector2.ZERO
var _nodes: Array[Dictionary] = []
var _sockets := {"enemy": [], "loot": [], "attribute": [], "exit": []}
var _exit_module_indices: Array[int] = []
var _content_modules: Dictionary = {
	"loot": [],
	"attribute": [],
	"exit": [],
	"enemy": [],
	"weapon": [],
}
var _content_entries: Array[Dictionary] = []
var _teleporter_entries: Array[Dictionary] = []
var _trap_event_ids: Array[StringName] = []
var _heavy_enemy_ids: Array[StringName] = []
var _reserved_event_marker_ids: Dictionary = {}


func generate(run_seed: int, run_manager: Node) -> bool:
	_clear_generated_children()
	generation_fallback = false
	generation_failure_reason = ""
	rejected_layout_count = 0
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
		rejected_layout_count += 1
	return _build_fallback(run_seed, run_manager, generation_failure_reason)


func get_start_position() -> Vector2:
	return _start_position


func get_generated_bounds() -> Rect2:
	return generated_bounds


func get_generation_report() -> Dictionary:
	var combat_modules: Array = _content_modules.get("enemy", []) as Array
	var eligible_modules := {}
	for marker in _sockets.enemy:
		var eligible_index := int(marker.get_meta("module_index", -1))
		if eligible_index > 0 and not _exit_module_indices.has(eligible_index) and _is_valid_spawn_socket(marker, 48.0) and not _position_near_teleporter(marker.global_position):
			eligible_modules[eligible_index] = true
	var maximum_empty_sequence := 0
	var current_empty_sequence := 0
	for index in _nodes.size():
		if not eligible_modules.has(index):
			continue
		if combat_modules.has(index):
			current_empty_sequence = 0
		else:
			current_empty_sequence += 1
			maximum_empty_sequence = maxi(maximum_empty_sequence, current_empty_sequence)
	var auxiliary_platform_count := 0
	var guard_rail_count := 0
	for body in find_children("*", "StaticBody2D", true, false):
		var role := StringName(body.get_meta("collision_role", &""))
		auxiliary_platform_count += 1 if role == &"one_way_platform" else 0
		guard_rail_count += 1 if role == &"procedural_guard_rail" else 0
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
		"ranged_enemy_count": spawned_ranged_count,
		"heavy_enemy_count": spawned_heavy_count,
		"heavy_enemy_ids": _heavy_enemy_ids.duplicate(),
		"trap_chest_count": spawned_trap_chest_count,
		"trap_event_ids": _trap_event_ids.duplicate(),
		"combat_module_count": combat_modules.size(),
		"max_empty_sequence": maximum_empty_sequence,
		"auxiliary_platform_count": auxiliary_platform_count,
		"guard_rail_count": guard_rail_count,
		"invalid_spawn_count": 0,
		"rejected_layout_count": rejected_layout_count,
		"micro_ledge_count": 0,
		"rejected_micro_ledge_count": rejected_micro_ledge_count,
		"invalid_platform_clearance_count": invalid_platform_clearance_count,
		"minimum_platform_clearance": 0.0 if is_inf(minimum_platform_clearance) else minimum_platform_clearance,
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
			"instance_id": _module_instance_id(index),
			"route_style": definition.route_style if definition != null else &"flat",
		})
	return {
		"modules": modules,
		"start_module": 0,
		"exit_modules": _exit_module_indices.duplicate(),
		"content_modules": _content_modules.duplicate(true),
		"content_entries": _content_entries.duplicate(true),
		"teleporters": _teleporter_entries.duplicate(true),
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
	var recent_module_ids: Array[StringName] = []
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
		if candidates.size() > 1 and not recent_module_ids.is_empty():
			var varied := candidates.filter(func(value: BiomeModuleDefinition) -> bool: return not recent_module_ids.has(value.module_id))
			if not varied.is_empty():
				candidates = varied
		_nodes[index].definition = candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else null
		if _nodes[index].definition != null:
			recent_module_ids.append((_nodes[index].definition as BiomeModuleDefinition).module_id)
			if recent_module_ids.size() > 2:
				recent_module_ids.pop_front()


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
	spawned_ranged_count = 0
	spawned_heavy_count = 0
	spawned_trap_chest_count = 0
	rejected_micro_ledge_count = 0
	invalid_platform_clearance_count = 0
	minimum_platform_clearance = INF
	_trap_event_ids.clear()
	_heavy_enemy_ids.clear()
	_reserved_event_marker_ids.clear()
	_content_modules = {"loot": [], "attribute": [], "exit": [], "enemy": [], "weapon": []}
	_content_entries.clear()
	_teleporter_entries.clear()
	generation_signature = _build_generation_signature()
	var modules_root := Node2D.new()
	modules_root.name = "Modules"
	add_child(modules_root)
	for index in _nodes.size():
		_build_module(modules_root, index)
	_build_vertical_connections()
	_build_outer_safety()
	_start_position = Vector2(140.0, FLOOR_TOP - 36.0)
	_spawn_teleporters(run_manager)
	_spawn_required_content(rng, run_manager)
	generation_signature += _phase8_content_signature()
	generated_bounds = _calculate_bounds().grow(160.0)
	call_deferred("_sync_runtime_debug_visibility")


func _sync_runtime_debug_visibility() -> void:
	if not is_inside_tree():
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var visible_debug := false
	if room_manager != null and room_manager.has_node("LocalSettings"):
		visible_debug = bool(room_manager.get_node("LocalSettings").debug_hud_visible)
	for node in find_children("*", "", true, false):
		if node.is_in_group("procedural_debug_collider") or node.is_in_group("procedural_debug_text"):
			node.visible = visible_debug


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
	_build_module_guard_rails(module, data.required_connectors)
	var has_vertical_route: bool = data.required_connectors.has(&"up") or data.required_connectors.has(&"down")
	var has_internal_routes: bool = definition.route_style in ["upper_lower", "lower_upper"]
	var has_purposeful_platforms: bool = has_vertical_route or has_internal_routes or data.role in [&"combat", &"reward", &"exit"]
	if has_purposeful_platforms:
		for platform_rect in definition.platform_rects:
			if _platform_is_functional(definition, platform_rect, has_vertical_route or has_internal_routes):
				var scaled_platform: Rect2 = _scaled_platform_rect(platform_rect, definition)
				var clearance: float = _platform_clearance_below(scaled_platform, platform_rect, definition)
				minimum_platform_clearance = minf(minimum_platform_clearance, clearance)
				if clearance + 0.01 < MINIMUM_TRAVERSAL_CLEARANCE:
					invalid_platform_clearance_count += 1
				_add_static_rect(module, scaled_platform, Color(0.09, 0.23, 0.28, 1.0), true)
	_create_module_sockets(module, definition, index)
	if biome_definition.debug_draw_modules:
		var label := Label.new()
		label.add_to_group("procedural_debug_text")
		label.visible = false
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


func _add_static_rect(parent: Node2D, rectangle: Rect2, color: Color, one_way: bool = false) -> void:
	var body := StaticBody2D.new()
	body.position = rectangle.position + rectangle.size * 0.5
	body.set_meta("collision_role", &"one_way_platform" if one_way else &"solid_structure")
	parent.add_child(body)
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rectangle.size
	shape_node.shape = shape
	shape_node.one_way_collision = one_way
	shape_node.one_way_collision_margin = 4.0 if one_way else 1.0
	body.add_child(shape_node)
	var visual := Polygon2D.new()
	var half := rectangle.size * 0.5
	visual.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	visual.color = color
	body.add_child(visual)


func _build_module_guard_rails(module: Node2D, connectors: Array) -> void:
	# A horizontal edge is sealed only when the generated graph has no route into
	# the adjacent cell. Vertical connectors stay open for intentional drops.
	if not connectors.has(&"left"):
		_add_guard_rail(module, Vector2(-GUARD_RAIL_WIDTH * 0.5, FLOOR_TOP - GUARD_RAIL_HEIGHT * 0.5))
	if not connectors.has(&"right"):
		_add_guard_rail(module, Vector2(CELL_SIZE.x + GUARD_RAIL_WIDTH * 0.5, FLOOR_TOP - GUARD_RAIL_HEIGHT * 0.5))


func _add_guard_rail(parent: Node2D, local_position: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = local_position
	body.set_meta("collision_role", &"procedural_guard_rail")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(GUARD_RAIL_WIDTH, GUARD_RAIL_HEIGHT)
	collision.shape = shape
	body.add_child(collision)
	var debug_visual := Polygon2D.new()
	debug_visual.polygon = PackedVector2Array([Vector2(-GUARD_RAIL_WIDTH * 0.5, -GUARD_RAIL_HEIGHT * 0.5), Vector2(GUARD_RAIL_WIDTH * 0.5, -GUARD_RAIL_HEIGHT * 0.5), Vector2(GUARD_RAIL_WIDTH * 0.5, GUARD_RAIL_HEIGHT * 0.5), Vector2(-GUARD_RAIL_WIDTH * 0.5, GUARD_RAIL_HEIGHT * 0.5)])
	debug_visual.color = Color(1.0, 0.1, 0.8, 0.45)
	debug_visual.visible = false
	debug_visual.add_to_group("procedural_debug_collider")
	body.add_child(debug_visual)
	parent.add_child(body)


func _create_module_sockets(module: Node2D, definition: BiomeModuleDefinition, module_index: int) -> void:
	_create_socket_type(module, definition.enemy_sockets, &"enemy", module_index)
	_create_socket_type(module, definition.loot_sockets, &"loot", module_index)
	_create_socket_type(module, definition.attribute_sockets, &"attribute", module_index)
	_create_socket_type(module, definition.exit_sockets, &"exit", module_index)


func _platform_is_functional(definition: BiomeModuleDefinition, platform_rect: Rect2, route_required: bool) -> bool:
	var scaled_width := _scale_source_rect(platform_rect).size.x
	if scaled_width < MINIMUM_FUNCTIONAL_PLATFORM_WIDTH:
		return false
	for socket_group: Array in [definition.enemy_sockets, definition.loot_sockets, definition.attribute_sockets]:
		for socket_position: Vector2 in socket_group:
			if socket_position.x >= platform_rect.position.x and socket_position.x <= platform_rect.end.x and absf(socket_position.y - platform_rect.position.y) <= 90.0:
				return true
	if route_required and scaled_width >= MINIMUM_FUNCTIONAL_PLATFORM_WIDTH:
		return true
	return scaled_width >= 210.0


func _create_socket_type(module: Node2D, positions: Array[Vector2], socket_type: StringName, module_index: int) -> void:
	var definition := _nodes[module_index].definition as BiomeModuleDefinition
	for socket_index in positions.size():
		var marker := Marker2D.new()
		marker.name = "%s_%02d_%02d" % [socket_type, module_index, socket_index]
		marker.position = _scaled_socket_position(positions[socket_index], definition)
		marker.add_to_group(StringName("%s_spawn_point" % socket_type))
		marker.set_meta("module_index", module_index)
		module.add_child(marker)
		_sockets[socket_type].append(marker)
		if biome_definition.debug_draw_sockets:
			var label := Label.new()
			label.add_to_group("procedural_debug_text")
			label.visible = false
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
	label.add_to_group("procedural_debug_text")
	label.visible = false
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
			var bottom_clearance := 112.0
			var climbable_height := maxf(lower_floor - shaft_top - bottom_clearance, 160.0)
			# The shaft is deliberately a clean corridor. The former 56 px rest was
			# flush with the left wall and formed a hook inside the climb clearance
			# zone, which could catch CharacterBody2D during wall climb.
			var shaft_half_width := VERTICAL_SHAFT_INNER_WIDTH * 0.5
			_add_static_rect(connections, Rect2(center_x - shaft_half_width - VERTICAL_SHAFT_WALL_THICKNESS, shaft_top, VERTICAL_SHAFT_WALL_THICKNESS, climbable_height), Color(0.11, 0.35, 0.38, 1.0))
			_add_static_rect(connections, Rect2(center_x + shaft_half_width, shaft_top, VERTICAL_SHAFT_WALL_THICKNESS, climbable_height), Color(0.11, 0.35, 0.38, 1.0))
			rejected_micro_ledge_count += 1


func _spawn_required_content(rng: RandomNumberGenerator, run_manager: Node) -> void:
	var stage_prefix := String(run_manager.current_stage_id) if not String(run_manager.current_stage_id).is_empty() else "lower_city"
	var exit_a: StringName = biome_definition.possible_exits[0] if biome_definition.possible_exits.size() > 0 else &"exit_a"
	var exit_b: StringName = biome_definition.possible_exits[1] if biome_definition.possible_exits.size() > 1 else &"exit_b"
	_spawn_exit(0, _exit_module_indices[0], exit_a, &"next_biome_a")
	_spawn_exit(1, _exit_module_indices[1], exit_b, &"next_biome_b")
	_spawn_attribute_reward(0, _exit_module_indices[0], stage_prefix)
	_spawn_attribute_reward(1, _exit_module_indices[1], stage_prefix)
	_spawn_loot(rng, run_manager, stage_prefix)
	_spawn_weapon_pickups(rng, run_manager, stage_prefix)
	_spawn_enemies(rng, run_manager, stage_prefix)


func _spawn_teleporters(run_manager: Node) -> void:
	_teleporter_entries.clear()
	if _nodes.is_empty():
		return
	var desired_count := clampi(roundi(float(_nodes.size()) / 6.0), 3, 5)
	var distances := _graph_distances(0)
	var ordered: Array[int] = []
	for index in _nodes.size():
		ordered.append(index)
	ordered.sort_custom(func(first: int, second: int) -> bool:
		var first_distance := int(distances.get(first, 0))
		var second_distance := int(distances.get(second, 0))
		return first_distance < second_distance or (first_distance == second_distance and first < second)
	)
	var chosen: Array[int] = [0]
	for slot in range(1, desired_count):
		var position := roundi(float(slot) * float(ordered.size() - 1) / float(desired_count - 1))
		var candidate := ordered[position]
		if not chosen.has(candidate):
			chosen.append(candidate)
	chosen.sort()
	var stage_prefix := String(run_manager.current_stage_id) if not String(run_manager.current_stage_id).is_empty() else "lower_city"
	for order in chosen.size():
		var module_index := chosen[order]
		var teleporter := TELEPORTER_SCRIPT.new() as BiomeTeleporter
		teleporter.name = "BiomeTeleporter%02d" % (order + 1)
		teleporter.teleporter_id = StringName("%s_teleporter_%02d" % [stage_prefix, order + 1])
		teleporter.module_instance_id = _module_instance_id(module_index)
		teleporter.display_name = "SETOR %02d" % (order + 1)
		add_child(teleporter)
		var module_origin := Vector2(_nodes[module_index].grid) * CELL_SIZE
		teleporter.global_position = module_origin + Vector2(CELL_SIZE.x * (0.30 if order % 2 == 0 else 0.70), FLOOR_TOP - 34.0)
		teleporter.arrival_position = teleporter.global_position + Vector2(0, -48)
		_teleporter_entries.append({
			"teleporter_id": teleporter.teleporter_id,
			"module_instance_id": teleporter.module_instance_id,
			"module_index": module_index,
			"display_name": teleporter.display_name,
			"position": teleporter.global_position,
		})


func _graph_distances(start_index: int) -> Dictionary:
	var result := {start_index: 0}
	var queue: Array[int] = [start_index]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor_value: Variant in _nodes[current].neighbors:
			var neighbor := int(neighbor_value)
			if result.has(neighbor):
				continue
			result[neighbor] = int(result[current]) + 1
			queue.append(neighbor)
	return result


func _module_instance_id(index: int) -> StringName:
	return StringName("module_%02d" % index)


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
	_content_entries.append({"kind": &"exit", "content_id": exit_id, "module_instance_id": _module_instance_id(module_index), "module_index": module_index})
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
	_content_entries.append({"kind": &"attribute", "content_id": chest.chest_id, "module_instance_id": _module_instance_id(module_index), "module_index": module_index})


func _spawn_loot(rng: RandomNumberGenerator, run_manager: Node, stage_prefix: String) -> void:
	var candidates: Array = _sockets.loot.duplicate()
	candidates = candidates.filter(func(marker: Marker2D) -> bool:
		var module_index := int(marker.get_meta("module_index"))
		return module_index != 0 and not _exit_module_indices.has(module_index) and _nodes[module_index].role == &"reward" and _is_valid_spawn_socket(marker, 44.0)
	)
	if candidates.size() < 2:
		for fallback_marker in _sockets.loot:
			var fallback_index := int(fallback_marker.get_meta("module_index"))
			if fallback_index != 0 and not _exit_module_indices.has(fallback_index) and _is_valid_spawn_socket(fallback_marker, 36.0) and not candidates.has(fallback_marker):
				candidates.append(fallback_marker)
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
		var loot_id := StringName("%s_loot_%02d" % [stage_prefix, index + 1])
		var event_markers := _trap_event_markers_for_loot(marker)
		var spawn_trap := event_markers.size() >= 2 and rng.randf() <= TRAP_CHEST_CHANCE
		var loot: Node2D
		if spawn_trap:
			var trap := TRAP_CHEST_SCENE.instantiate() as TrapChest
			trap.name = "BiomeLoot%02d" % (index + 1)
			trap.trap_id = loot_id
			for event_marker in event_markers:
				trap.event_spawn_positions.append((event_marker as Marker2D).global_position)
				_reserved_event_marker_ids[(event_marker as Marker2D).get_instance_id()] = true
			loot = trap
			spawned_trap_chest_count += 1
			_trap_event_ids.append(loot_id)
		else:
			var ordinary_loot := LOOT_SCENE.instantiate()
			ordinary_loot.name = "BiomeLoot%02d" % (index + 1)
			ordinary_loot.loot_id = loot_id
			ordinary_loot.amount = 15 + run_manager.extra_enemy_count * 5
			loot = ordinary_loot
		add_child(loot)
		loot.global_position = marker.global_position
		spawned_loot_count += 1
		var module_index := int(marker.get_meta("module_index"))
		(_content_modules.loot as Array).append(module_index)
		_content_entries.append({"kind": &"loot", "content_id": loot_id, "module_instance_id": _module_instance_id(module_index), "module_index": module_index})


func _trap_event_markers_for_loot(loot_marker: Marker2D) -> Array[Marker2D]:
	var module_index := int(loot_marker.get_meta("module_index", -1))
	if module_index < 0 or module_index >= _nodes.size():
		return []
	var definition := _nodes[module_index].definition as BiomeModuleDefinition
	if definition == null or definition.module_id not in [&"corridor", &"open_area", &"upper_lower_passage", &"lower_upper_passage"]:
		return []
	if _nodes[module_index].required_connectors.has(&"up") or _nodes[module_index].required_connectors.has(&"down"):
		return []
	var result: Array[Marker2D] = []
	for marker_value: Variant in _sockets.enemy:
		var marker := marker_value as Marker2D
		if int(marker.get_meta("module_index", -1)) != module_index or not _is_valid_spawn_socket(marker, 66.0):
			continue
		if marker.global_position.distance_to(loot_marker.global_position) < 90.0:
			continue
		result.append(marker)
	result.sort_custom(func(first: Marker2D, second: Marker2D) -> bool: return first.global_position.x < second.global_position.x)
	return result.slice(0, mini(result.size(), 3))


func _spawn_weapon_pickups(rng: RandomNumberGenerator, run_manager: Node, stage_prefix: String) -> void:
	if rng.randf() > SPECIAL_WEAPON_DROP_CHANCE:
		return
	var candidates: Array = _sockets.loot.filter(func(marker: Marker2D) -> bool:
		var module_index := int(marker.get_meta("module_index"))
		return module_index != 0 and not _exit_module_indices.has(module_index) and _is_valid_spawn_socket(marker, 58.0) and not _position_near_teleporter(marker.global_position)
	)
	if candidates.is_empty():
		return
	_shuffle(candidates, rng)
	var marker := candidates[0] as Marker2D
	var pickup := WEAPON_PICKUP_SCRIPT.new() as WeaponPickup
	pickup.pickup_id = StringName("%s_weapon_01" % stage_prefix)
	var weapon_pool: Array[StringName] = [&"breaker_maul", &"arc_emitter"]
	var configured_pool: Array = []
	if run_manager != null:
		configured_pool = run_manager.get("run_weapon_pool") as Array
	if not configured_pool.is_empty():
		weapon_pool.assign(configured_pool)
	pickup.weapon_id = weapon_pool[rng.randi_range(0, weapon_pool.size() - 1)]
	add_child(pickup)
	pickup.global_position = marker.global_position
	var module_index := int(marker.get_meta("module_index"))
	(_content_modules.weapon as Array).append(module_index)
	_content_entries.append({"kind": &"weapon", "content_id": pickup.pickup_id, "module_instance_id": _module_instance_id(module_index), "module_index": module_index})


func _spawn_enemies(rng: RandomNumberGenerator, run_manager: Node, stage_prefix: String) -> void:
	var candidates: Array = _sockets.enemy.duplicate()
	candidates = candidates.filter(func(marker: Marker2D) -> bool:
		var module_index := int(marker.get_meta("module_index"))
		return module_index != 0 and not _exit_module_indices.has(module_index) and not _reserved_event_marker_ids.has(marker.get_instance_id()) and _is_valid_spawn_socket(marker, 48.0) and not _position_near_teleporter(marker.global_position)
	)
	var by_module := {}
	for marker_value: Variant in candidates:
		var marker := marker_value as Marker2D
		var module_index := int(marker.get_meta("module_index"))
		if not by_module.has(module_index):
			by_module[module_index] = []
		(by_module[module_index] as Array).append(marker)
	var module_indices: Array = by_module.keys()
	module_indices.sort()
	var ordered_candidates: Array[Marker2D] = []
	var difficulty: StringName = run_manager.difficulty
	var maximum_gap: int = {&"normal": 2, &"hard": 2, &"pro": 1, &"inferno_pro": 0}.get(difficulty, 2)
	var occupancy: float = {&"normal": 0.48, &"hard": 0.62, &"pro": 0.78, &"inferno_pro": 0.94}.get(difficulty, 0.48)
	var encounter_size: int = {&"normal": 1, &"hard": 2, &"pro": 2, &"inferno_pro": 3}.get(difficulty, 1)
	var chosen_modules: Array[int] = []
	var empty_streak := 0
	for order in module_indices.size():
		var module_index := int(module_indices[order])
		var module_candidates := by_module[module_index] as Array
		_shuffle(module_candidates, rng)
		var forced := empty_streak >= maximum_gap
		var contextual_bonus := 0.16 if _nodes[module_index].role in [&"combat", &"reward"] else 0.0
		if forced or rng.randf() <= occupancy + contextual_bonus:
			chosen_modules.append(module_index)
			empty_streak = 0
		else:
			empty_streak += 1
	for module_index in chosen_modules:
		var module_candidates := by_module[module_index] as Array
		var count := mini(encounter_size, module_candidates.size())
		if difficulty == &"normal" and rng.randf() < 0.55:
			count = 1
		for _spawn_index in count:
			ordered_candidates.append(module_candidates.pop_back())
	# Stage pressure grows gradually without changing the topology.
	var stage_factor := 1.0 + minf(float(run_manager.stage_index) * 0.06, 0.30)
	var pressure_factor: float = {&"normal": 0.90, &"hard": 1.25, &"pro": 1.72, &"inferno_pro": 2.25}.get(difficulty, 0.90)
	var desired_count := maxi(14, ceili(float(module_indices.size()) * pressure_factor * stage_factor))
	var chosen_remaining: Array[Marker2D] = []
	for module_index in chosen_modules:
		chosen_remaining.append_array(by_module[module_index])
	_shuffle(chosen_remaining, rng)
	while ordered_candidates.size() < desired_count and not chosen_remaining.is_empty():
		ordered_candidates.append(chosen_remaining.pop_back())
	var fallback_remaining: Array[Marker2D] = []
	for module_index in module_indices:
		if not chosen_modules.has(int(module_index)):
			fallback_remaining.append_array(by_module[module_index])
	_shuffle(fallback_remaining, rng)
	while ordered_candidates.size() < desired_count and not fallback_remaining.is_empty():
		ordered_candidates.append(fallback_remaining.pop_back())
	# High-pressure encounters may reuse a wide validated socket with a lateral
	# formation offset. This avoids inventing unsafe sockets while lifting the
	# old one-enemy-per-marker ceiling.
	var reinforcement_pool: Array = candidates.duplicate()
	_shuffle(reinforcement_pool, rng)
	var reinforcement_index := 0
	while ordered_candidates.size() < desired_count and not reinforcement_pool.is_empty():
		ordered_candidates.append(reinforcement_pool[reinforcement_index % reinforcement_pool.size()])
		reinforcement_index += 1
	desired_count = mini(desired_count, ordered_candidates.size())
	var ranged_ratio: float = {&"normal": 0.18, &"hard": 0.28, &"pro": 0.38, &"inferno_pro": 0.52}.get(difficulty, 0.18)
	var ranged_count := mini(ceili(desired_count * ranged_ratio), desired_count)
	var heavy_indices := _choose_heavy_spawn_indices(ordered_candidates, ranged_count, run_manager, rng)
	var marker_use_count := {}
	for index in desired_count:
		var enemy: Node
		if heavy_indices.has(index):
			enemy = HEAVY_ENEMY_SCENE.instantiate()
			spawned_heavy_count += 1
		elif index < ranged_count:
			enemy = RANGED_ENEMY_SCENE.instantiate()
			spawned_ranged_count += 1
		else:
			enemy = ENEMY_SCENE.instantiate()
		enemy.name = "LowerCityEnemy%02d" % (index + 1)
		enemy.persistent_id = StringName("%s_enemy_%02d" % [stage_prefix, index + 1])
		if enemy.has_method("is_heavy") and bool(enemy.is_heavy()):
			_heavy_enemy_ids.append(enemy.persistent_id)
		enemy.run_room_id = StringName(stage_prefix)
		add_child(enemy)
		var marker := ordered_candidates[index] as Marker2D
		var marker_key := marker.get_instance_id()
		var use_count := int(marker_use_count.get(marker_key, 0))
		marker_use_count[marker_key] = use_count + 1
		var formation_offset: float = [0.0, -38.0, 38.0][use_count % 3]
		enemy.global_position = marker.global_position + Vector2(formation_offset, 0.0)
		spawned_enemy_count += 1
		var module_index := int(marker.get_meta("module_index"))
		enemy.set_meta("source_module_index", module_index)
		enemy.set_meta("structurally_validated_spawn", true)
		if not (_content_modules.enemy as Array).has(module_index):
			(_content_modules.enemy as Array).append(module_index)


func _choose_heavy_spawn_indices(candidates: Array[Marker2D], ranged_count: int, run_manager: Node, rng: RandomNumberGenerator) -> Dictionary:
	var difficulty: StringName = run_manager.difficulty
	var stage: int = run_manager.stage_index
	var minimum_stage: int = {&"normal": 2, &"hard": 1, &"pro": 1, &"inferno_pro": 0}.get(difficulty, 2)
	if stage < minimum_stage:
		return {}
	var chance: float = {&"normal": 0.18, &"hard": 0.24, &"pro": 0.36, &"inferno_pro": 0.48}.get(difficulty, 0.18)
	chance += minf(stage * 0.03, 0.12)
	var maximum: int = 1 if difficulty in [&"normal", &"hard"] else 2
	var eligible: Array[int] = []
	var used_markers: Dictionary = {}
	for index in range(ranged_count, candidates.size()):
		var marker := candidates[index]
		var marker_id := marker.get_instance_id()
		if used_markers.has(marker_id):
			continue
		used_markers[marker_id] = true
		if _is_valid_heavy_spawn_socket(marker):
			eligible.append(index)
	_shuffle(eligible, rng)
	var result: Dictionary = {}
	for index in eligible:
		if result.size() >= maximum:
			break
		if rng.randf() <= chance:
			result[index] = true
	return result


func _phase8_content_signature() -> String:
	var heavy_ids: Array[String] = []
	for enemy_id in _heavy_enemy_ids:
		heavy_ids.append(String(enemy_id))
	heavy_ids.sort()
	var trap_ids: Array[String] = []
	for event_id in _trap_event_ids:
		trap_ids.append(String(event_id))
	trap_ids.sort()
	return "|heavy:%s|traps:%s" % [",".join(heavy_ids), ",".join(trap_ids)]


func _is_valid_heavy_spawn_socket(marker: Marker2D) -> bool:
	if not _is_valid_spawn_socket(marker, 66.0):
		return false
	var module_index := int(marker.get_meta("module_index", -1))
	if module_index < 0 or module_index >= _nodes.size() or _nodes[module_index].role not in [&"combat", &"reward"]:
		return false
	var definition := _nodes[module_index].definition as BiomeModuleDefinition
	if definition == null or definition.module_id not in [&"corridor", &"open_area", &"upper_lower_passage", &"lower_upper_passage"]:
		return false
	return not _nodes[module_index].required_connectors.has(&"up") and not _nodes[module_index].required_connectors.has(&"down")


func _is_valid_spawn_socket(marker: Marker2D, half_width: float) -> bool:
	var module_index := int(marker.get_meta("module_index", -1))
	if module_index < 0 or module_index >= _nodes.size():
		return false
	var local_position := marker.position
	if local_position.x < SPAWN_EDGE_CLEARANCE + half_width or local_position.x > CELL_SIZE.x - SPAWN_EDGE_CLEARANCE - half_width:
		return false
	var definition := _nodes[module_index].definition as BiomeModuleDefinition
	var supported := absf(local_position.y - (FLOOR_TOP - 45.0)) <= 64.0
	for source_rect in definition.platform_rects:
		if not _platform_is_functional(definition, source_rect, _nodes[module_index].required_connectors.has(&"up") or _nodes[module_index].required_connectors.has(&"down") or definition.route_style in ["upper_lower", "lower_upper"]):
			continue
		var platform := _scaled_platform_rect(source_rect, definition)
		if local_position.x >= platform.position.x + half_width and local_position.x <= platform.end.x - half_width and absf(local_position.y - platform.position.y) <= 58.0:
			supported = true
			break
	if _nodes[module_index].required_connectors.has(&"down") and absf(local_position.x - CELL_SIZE.x * 0.5) < 110.0:
		return false
	return supported and not _position_near_teleporter(marker.global_position)


func _position_near_teleporter(world_position: Vector2) -> bool:
	for entry_value: Variant in _teleporter_entries:
		var entry := entry_value as Dictionary
		if world_position.distance_to(Vector2(entry.position)) < 120.0:
			return true
	return false


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
	var boundary_top := bounds.position.y - OUTER_BOUNDARY_VERTICAL_MARGIN
	var boundary_height := bounds.size.y + OUTER_BOUNDARY_VERTICAL_MARGIN * 2.0
	_add_static_rect(safety, Rect2(bounds.position.x - OUTER_BOUNDARY_THICKNESS, boundary_top, OUTER_BOUNDARY_THICKNESS, boundary_height), Color.TRANSPARENT)
	_add_static_rect(safety, Rect2(bounds.end.x, boundary_top, OUTER_BOUNDARY_THICKNESS, boundary_height), Color.TRANSPARENT)
	var ceiling_y := bounds.position.y - UPPER_BOUND_MARGIN
	_add_static_rect(safety, Rect2(bounds.position.x - OUTER_BOUNDARY_THICKNESS, ceiling_y - OUTER_BOUNDARY_THICKNESS, bounds.size.x + OUTER_BOUNDARY_THICKNESS * 2.0, OUTER_BOUNDARY_THICKNESS), Color.TRANSPARENT)
	var ceiling := safety.get_child(safety.get_child_count() - 1) as StaticBody2D
	ceiling.set_meta("collision_role", &"procedural_upper_bound")
	var ceiling_visual := ceiling.get_child(1) as Polygon2D
	ceiling_visual.color = Color(0.2, 0.8, 1.0, 0.35)
	ceiling_visual.visible = false
	ceiling_visual.add_to_group("procedural_debug_collider")
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
	_content_modules = {"loot": [], "attribute": [], "exit": [], "enemy": [], "weapon": []}
	_content_entries.clear()
	_teleporter_entries.clear()
	_trap_event_ids.clear()
	_heavy_enemy_ids.clear()
	_reserved_event_marker_ids.clear()


func _scale_source_position(value: Vector2) -> Vector2:
	return value * (CELL_SIZE / SOURCE_MODULE_SIZE)


func _scale_source_rect(value: Rect2) -> Rect2:
	var scale_factor := CELL_SIZE / SOURCE_MODULE_SIZE
	return Rect2(value.position * scale_factor, value.size * scale_factor)


func _scaled_platform_rect(source_rect: Rect2, definition: BiomeModuleDefinition) -> Rect2:
	var result: Rect2 = _scale_source_rect(source_rect)
	var maximum_bottom: float = FLOOR_TOP - MINIMUM_TRAVERSAL_CLEARANCE
	if definition != null:
		for lower_source: Rect2 in definition.platform_rects:
			if lower_source.position.y <= source_rect.position.y or not _source_rects_overlap_horizontally(source_rect, lower_source):
				continue
			var lower_platform: Rect2 = _scaled_platform_rect(lower_source, definition)
			maximum_bottom = minf(maximum_bottom, lower_platform.position.y - MINIMUM_TRAVERSAL_CLEARANCE)
	if result.end.y > maximum_bottom:
		result.position.y -= result.end.y - maximum_bottom
	return result


func _platform_clearance_below(platform: Rect2, source_rect: Rect2, definition: BiomeModuleDefinition) -> float:
	var lower_surface: float = FLOOR_TOP
	if definition != null:
		for lower_source: Rect2 in definition.platform_rects:
			if lower_source.position.y <= source_rect.position.y or not _source_rects_overlap_horizontally(source_rect, lower_source):
				continue
			var lower_platform: Rect2 = _scaled_platform_rect(lower_source, definition)
			lower_surface = minf(lower_surface, lower_platform.position.y)
	return lower_surface - platform.end.y


func _source_rects_overlap_horizontally(first: Rect2, second: Rect2) -> bool:
	return minf(first.end.x, second.end.x) - maxf(first.position.x, second.position.x) >= MINIMUM_STACKED_PASSAGE_OVERLAP


func _scaled_socket_position(source_position: Vector2, definition: BiomeModuleDefinition) -> Vector2:
	var result: Vector2 = _scale_source_position(source_position)
	if definition == null:
		return result
	var closest_distance: float = INF
	var platform_shift: float = 0.0
	for source_rect: Rect2 in definition.platform_rects:
		if source_position.x < source_rect.position.x or source_position.x > source_rect.end.x:
			continue
		var vertical_distance: float = source_position.y - source_rect.position.y
		if vertical_distance < -90.0 or vertical_distance > 40.0 or absf(vertical_distance) >= closest_distance:
			continue
		var scaled_original: Rect2 = _scale_source_rect(source_rect)
		var scaled_adjusted: Rect2 = _scaled_platform_rect(source_rect, definition)
		closest_distance = absf(vertical_distance)
		platform_shift = scaled_adjusted.position.y - scaled_original.position.y
	result.y += platform_shift
	return result


func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("enter_downed"):
		body.enter_downed()
	elif body.is_in_group("enemy") and body.has_method("apply_extreme_fall"):
		body.apply_extreme_fall()


func _stable_hash(value: String) -> int:
	var result := 2166136261
	for byte in value.to_utf8_buffer():
		result = int((result ^ byte) * 16777619) & 0x7fffffff
	return result
