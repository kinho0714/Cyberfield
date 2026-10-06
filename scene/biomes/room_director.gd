class_name RoomDirector
extends RefCounted

const INTENT_TRAVERSAL: StringName = &"traversal"
const INTENT_COMBAT: StringName = &"combat"
const INTENT_VERTICAL: StringName = &"vertical_traversal"
const INTENT_TRANSITION: StringName = &"transition"
const INTENT_BREATHING: StringName = &"breathing"
const INTENT_REWARD: StringName = &"reward"
const INTENT_ROUTE_CHANGE: StringName = &"route_change"
const INTENT_SPECIAL: StringName = &"special_encounter"

var history_window := 5
var horizontal_bias := 0.75
var direction_repeat_penalty := 0.58
var vertical_repeat_penalty := 0.42
var soft_elevation_limit := 3
var direction_history: Array[Vector2i] = []
var intent_history: Array[StringName] = []
var module_history: Array[StringName] = []


func configure(rules: Dictionary) -> void:
	history_window = clampi(int(rules.get("history_window", 5)), 3, 10)
	horizontal_bias = clampf(float(rules.get("horizontal_bias", 0.75)), 0.0, 3.0)
	direction_repeat_penalty = clampf(float(rules.get("direction_repeat_penalty", 0.58)), 0.15, 0.95)
	vertical_repeat_penalty = clampf(float(rules.get("vertical_repeat_penalty", 0.42)), 0.10, 0.95)
	soft_elevation_limit = clampi(int(rules.get("soft_elevation_limit", 3)), 1, 8)
	reset()


func reset() -> void:
	direction_history.clear()
	intent_history.clear()
	module_history.clear()


func choose_direction(candidates: Array[Vector2i], current: Vector2i, occupied: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	if candidates.is_empty():
		return Vector2i.ZERO
	var weights: Array[float] = []
	var total := 0.0
	for direction in candidates:
		var weight := _direction_weight(direction, current, occupied)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll := rng.randf() * total
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()


func note_direction(direction: Vector2i) -> void:
	direction_history.append(direction)
	while direction_history.size() > history_window:
		direction_history.pop_front()


func choose_intent(candidates: Array[StringName], rng: RandomNumberGenerator) -> StringName:
	if candidates.is_empty():
		return INTENT_TRAVERSAL
	var weights: Array[float] = []
	var total := 0.0
	for intent in candidates:
		var weight := _intent_weight(intent)
		weights.append(weight)
		total += weight
	var roll := rng.randf() * maxf(total, 0.001)
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()


func note_intent(intent: StringName) -> void:
	intent_history.append(intent)
	while intent_history.size() > history_window:
		intent_history.pop_front()


func choose_module(candidates: Array[BiomeModuleDefinition], intent: StringName, rng: RandomNumberGenerator) -> BiomeModuleDefinition:
	if candidates.is_empty():
		return null
	var weights: Array[float] = []
	var total := 0.0
	for definition in candidates:
		var weight := _module_weight(definition, intent)
		weights.append(weight)
		total += weight
	var roll := rng.randf() * maxf(total, 0.001)
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()


func note_module(module_id: StringName) -> void:
	module_history.append(module_id)
	while module_history.size() > history_window:
		module_history.pop_front()


func get_debug_snapshot() -> Dictionary:
	return {
		"directions": direction_history.duplicate(),
		"intents": intent_history.duplicate(),
		"modules": module_history.duplicate(),
	}


func _direction_weight(direction: Vector2i, current: Vector2i, occupied: Dictionary) -> float:
	var next := current + direction
	if next.x < 0 or occupied.has(_grid_key(next)):
		return 0.0
	var weight := 1.0
	if direction.x != 0:
		weight *= 1.0 + horizontal_bias
		weight *= 1.25 if direction.x > 0 else 0.62
	else:
		weight *= 0.78

	var same_direction := 0
	var same_vertical_direction := 0
	var recent_vertical_delta := 0
	for recent in direction_history:
		recent_vertical_delta += recent.y
		if recent == direction:
			same_direction += 1
		if direction.y != 0 and recent.y == direction.y:
			same_vertical_direction += 1
	if same_direction > 0:
		weight *= pow(direction_repeat_penalty, same_direction)
	if same_vertical_direction > 0:
		weight *= pow(vertical_repeat_penalty, same_vertical_direction)

	if recent_vertical_delta >= 2:
		if direction.y > 0:
			weight *= 0.30
		elif direction.y < 0:
			weight *= 1.85
		else:
			weight *= 1.35
	elif recent_vertical_delta <= -2:
		if direction.y < 0:
			weight *= 0.30
		elif direction.y > 0:
			weight *= 1.85
		else:
			weight *= 1.35

	var elevation_overflow := absi(next.y) - soft_elevation_limit
	if elevation_overflow > 0:
		weight *= pow(0.48, elevation_overflow)
	return maxf(weight, 0.001)


func _intent_weight(intent: StringName) -> float:
	var weight := 1.0
	match intent:
		INTENT_TRAVERSAL:
			weight = 1.35
		INTENT_COMBAT:
			weight = 1.05
		INTENT_VERTICAL:
			weight = 1.0
		INTENT_TRANSITION:
			weight = 0.9
		INTENT_BREATHING:
			weight = 0.72
		INTENT_REWARD:
			weight = 1.15
		INTENT_ROUTE_CHANGE:
			weight = 1.0
		INTENT_SPECIAL:
			weight = 0.55
	var repeat_count := 0
	for recent in intent_history:
		if recent == intent:
			repeat_count += 1
	if repeat_count > 0:
		weight *= pow(0.52, repeat_count)
	if intent == INTENT_BREATHING:
		var recent_combat := 0
		for recent in intent_history:
			if recent == INTENT_COMBAT:
				recent_combat += 1
		weight *= 1.0 + float(recent_combat) * 0.45
	return maxf(weight, 0.05)


func _module_weight(definition: BiomeModuleDefinition, intent: StringName) -> float:
	var weight := 1.0
	var repeat_count := 0
	for recent in module_history:
		if recent == definition.module_id:
			repeat_count += 1
	if repeat_count > 0:
		weight *= pow(0.34, repeat_count)

	var id := definition.module_id
	match intent:
		INTENT_BREATHING:
			if id in [&"corridor", &"open_area"]:
				weight *= 1.65
		INTENT_COMBAT:
			if id in [&"open_area", &"fork_up", &"fork_down"]:
				weight *= 1.35
		INTENT_VERTICAL:
			if id in [&"rise", &"descent", &"vertical_shaft"]:
				weight *= 1.55
			if definition.route_style in ["upper_lower", "lower_upper"]:
				weight *= 1.40
		INTENT_ROUTE_CHANGE:
			if id in [&"fork_up", &"fork_down", &"vertical_shaft"]:
				weight *= 1.45
		INTENT_REWARD:
			if id in [&"open_area", &"corridor"]:
				weight *= 1.25
	return maxf(weight, 0.05)


func _grid_key(grid: Vector2i) -> String:
	return "%d:%d" % [grid.x, grid.y]
