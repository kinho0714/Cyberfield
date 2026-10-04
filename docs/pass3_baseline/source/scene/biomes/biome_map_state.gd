class_name BiomeMapState
extends RefCounted

signal changed

const TRAP_UNOPENED := &"unopened"
const TRAP_ACTIVE := &"active"
const TRAP_CLEARED := &"cleared"
const TRAP_REWARDED := &"rewarded"

var stage_id: StringName
var discovered_module_ids: Dictionary = {}
var discovered_connections: Dictionary = {}
var discovered_exit_ids: Dictionary = {}
var discovered_loot_ids: Dictionary = {}
var collected_loot_ids: Dictionary = {}
var discovered_attribute_ids: Dictionary = {}
var collected_attribute_ids: Dictionary = {}
var discovered_weapon_ids: Dictionary = {}
var collected_weapon_ids: Dictionary = {}
var discovered_bandage_ids: Dictionary = {}
var collected_bandage_ids: Dictionary = {}
var discovered_teleporter_ids: Dictionary = {}
var active_teleporter_ids: Dictionary = {}
var trap_event_states: Dictionary = {}


func _init(value: StringName = &"") -> void:
	stage_id = value


func discover_module(module_id: StringName, neighbors: Array[StringName] = []) -> bool:
	var did_change := _insert(discovered_module_ids, module_id)
	for neighbor_id in neighbors:
		if discovered_module_ids.has(neighbor_id):
			did_change = _insert(discovered_connections, connection_id(module_id, neighbor_id)) or did_change
	if did_change:
		changed.emit()
	return did_change


func discover_content(kind: StringName, content_id: StringName) -> bool:
	var target := _dictionary_for_kind(kind, false)
	if target == null or not _insert(target, content_id):
		return false
	changed.emit()
	return true


func collect_content(kind: StringName, content_id: StringName) -> bool:
	var target := _dictionary_for_kind(kind, true)
	if target == null or not _insert(target, content_id):
		return false
	changed.emit()
	return true


func activate_teleporter(teleporter_id: StringName) -> bool:
	var did_change := _insert(discovered_teleporter_ids, teleporter_id)
	did_change = _insert(active_teleporter_ids, teleporter_id) or did_change
	if did_change:
		changed.emit()
	return did_change


func register_trap_event(trap_id: StringName, enemy_ids: Array[StringName]) -> bool:
	if trap_id.is_empty() or trap_event_states.has(trap_id):
		return false
	var serialized_ids: Array[String] = []
	for enemy_id in enemy_ids:
		serialized_ids.append(String(enemy_id))
	trap_event_states[trap_id] = {"state": String(TRAP_UNOPENED), "enemy_ids": serialized_ids}
	changed.emit()
	return true


func get_trap_event_state(trap_id: StringName) -> StringName:
	var event: Dictionary = trap_event_states.get(trap_id, {}) as Dictionary
	return StringName(event.get("state", TRAP_UNOPENED))


func get_trap_event_enemy_ids(trap_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var event: Dictionary = trap_event_states.get(trap_id, {}) as Dictionary
	for value: Variant in event.get("enemy_ids", []):
		result.append(StringName(value))
	return result


func transition_trap_event(trap_id: StringName, next_state: StringName) -> bool:
	if not trap_event_states.has(trap_id):
		return false
	var event: Dictionary = trap_event_states[trap_id]
	var current_state := StringName(event.get("state", TRAP_UNOPENED))
	var valid_transition := (
		current_state == TRAP_UNOPENED and next_state == TRAP_ACTIVE
		or current_state == TRAP_ACTIVE and next_state == TRAP_CLEARED
		or current_state == TRAP_CLEARED and next_state == TRAP_REWARDED
	)
	if not valid_transition:
		return false
	event.state = String(next_state)
	trap_event_states[trap_id] = event
	changed.emit()
	return true


func to_dictionary() -> Dictionary:
	return {
		"stage_id": String(stage_id),
		"discovered_module_ids": _sorted_strings(discovered_module_ids),
		"discovered_connections": _sorted_strings(discovered_connections),
		"discovered_exit_ids": _sorted_strings(discovered_exit_ids),
		"discovered_loot_ids": _sorted_strings(discovered_loot_ids),
		"collected_loot_ids": _sorted_strings(collected_loot_ids),
		"discovered_attribute_ids": _sorted_strings(discovered_attribute_ids),
		"collected_attribute_ids": _sorted_strings(collected_attribute_ids),
		"discovered_weapon_ids": _sorted_strings(discovered_weapon_ids),
		"collected_weapon_ids": _sorted_strings(collected_weapon_ids),
		"discovered_bandage_ids": _sorted_strings(discovered_bandage_ids),
		"collected_bandage_ids": _sorted_strings(collected_bandage_ids),
		"discovered_teleporter_ids": _sorted_strings(discovered_teleporter_ids),
		"active_teleporter_ids": _sorted_strings(active_teleporter_ids),
		"trap_event_states": _serialized_trap_events(),
	}


func apply_dictionary(value: Dictionary) -> void:
	stage_id = StringName(value.get("stage_id", stage_id))
	_apply_array(discovered_module_ids, value.get("discovered_module_ids", []))
	_apply_array(discovered_connections, value.get("discovered_connections", []))
	_apply_array(discovered_exit_ids, value.get("discovered_exit_ids", []))
	_apply_array(discovered_loot_ids, value.get("discovered_loot_ids", []))
	_apply_array(collected_loot_ids, value.get("collected_loot_ids", []))
	_apply_array(discovered_attribute_ids, value.get("discovered_attribute_ids", []))
	_apply_array(collected_attribute_ids, value.get("collected_attribute_ids", []))
	_apply_array(discovered_weapon_ids, value.get("discovered_weapon_ids", []))
	_apply_array(collected_weapon_ids, value.get("collected_weapon_ids", []))
	_apply_array(discovered_bandage_ids, value.get("discovered_bandage_ids", []))
	_apply_array(collected_bandage_ids, value.get("collected_bandage_ids", []))
	_apply_array(discovered_teleporter_ids, value.get("discovered_teleporter_ids", []))
	_apply_array(active_teleporter_ids, value.get("active_teleporter_ids", []))
	_apply_trap_events(value.get("trap_event_states", []))
	changed.emit()


static func connection_id(first: StringName, second: StringName) -> StringName:
	var ordered := [String(first), String(second)]
	ordered.sort()
	return StringName("%s::%s" % ordered)


func _dictionary_for_kind(kind: StringName, collected: bool) -> Dictionary:
	match kind:
		&"exit": return discovered_exit_ids
		&"loot": return collected_loot_ids if collected else discovered_loot_ids
		&"attribute": return collected_attribute_ids if collected else discovered_attribute_ids
		&"weapon": return collected_weapon_ids if collected else discovered_weapon_ids
		&"bandage": return collected_bandage_ids if collected else discovered_bandage_ids
		&"teleporter": return active_teleporter_ids if collected else discovered_teleporter_ids
	return {}


func _insert(target: Dictionary, key: StringName) -> bool:
	if key.is_empty() or target.has(key):
		return false
	target[key] = true
	return true


func _sorted_strings(target: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in target.keys():
		result.append(String(key))
	result.sort()
	return result


func _apply_array(target: Dictionary, values: Variant) -> void:
	target.clear()
	if values is Array:
		for value: Variant in values:
			target[StringName(value)] = true


func _serialized_trap_events() -> Array[Dictionary]:
	var ids: Array[String] = []
	for trap_id: Variant in trap_event_states.keys():
		ids.append(String(trap_id))
	ids.sort()
	var result: Array[Dictionary] = []
	for trap_id in ids:
		var event: Dictionary = trap_event_states[StringName(trap_id)]
		result.append({
			"trap_id": trap_id,
			"state": String(event.get("state", TRAP_UNOPENED)),
			"enemy_ids": (event.get("enemy_ids", []) as Array).duplicate(),
		})
	return result


func _apply_trap_events(values: Variant) -> void:
	trap_event_states.clear()
	if not values is Array:
		return
	for value: Variant in values:
		var event := value as Dictionary
		var trap_id := StringName(event.get("trap_id", &""))
		if trap_id.is_empty():
			continue
		trap_event_states[trap_id] = {
			"state": String(event.get("state", TRAP_UNOPENED)),
			"enemy_ids": (event.get("enemy_ids", []) as Array).duplicate(),
		}
