class_name MetaProgression
extends Node

signal profile_changed

const SAVE_VERSION := 3
const DEFAULT_SAVE_PATH := "user://cyberfield_meta_v1.json"
const CREDIT_RATE := 0.20
const PURCHASES := {
	&"breaker_maul": {"name": "LICENÇA // MARTELO QUEBRADOR", "cost": 120, "kind": &"weapon"},
	&"arc_saber": {"name": "LICENÇA // SABRE ÍON", "cost": 175, "kind": &"weapon"},
	&"arc_emitter": {"name": "LICENÇA // EMISSOR DE ARCO", "cost": 220, "kind": &"weapon"},
	&"pulse_carbine": {"name": "LICENÇA // CARABINA PULSO", "cost": 260, "kind": &"weapon"},
	&"salvage_protocol": {"name": "PROTOCOLO DE RECUPERAÇÃO +10%", "cost": 180, "kind": &"upgrade"},
}

@export var save_path := DEFAULT_SAVE_PATH

var credits := 0
var scrap := 0
var unlocked_weapons: Array[StringName] = [&"scrap_blade", &"breaker_maul"]
var unlocked_upgrades: Array[StringName] = []
var statistics: Dictionary = {}
var processed_run_ids: Array[String] = []
var recovered_models: Array[StringName] = []
var blueprints: Array[StringName] = []
var house_stage := 0
var hub_progression: Dictionary = {
	&"workshop": 0,
	&"infrastructure": 0,
	&"operations": 0,
	&"storage": 0,
	&"spark": 0,
}


func _ready() -> void:
	add_to_group("meta_progression")
	load_profile()


func load_profile() -> void:
	_reset_defaults()
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return
	_apply_save(parsed as Dictionary)


func save_profile() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary(), "\t"))
	return true


func to_dictionary() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"credits": credits,
		"scrap": scrap,
		"unlocked_weapons": unlocked_weapons.duplicate(),
		"unlocked_upgrades": unlocked_upgrades.duplicate(),
		"statistics": statistics.duplicate(true),
		"processed_run_ids": processed_run_ids.duplicate(),
		"recovered_models": recovered_models.duplicate(),
		"blueprints": blueprints.duplicate(),
		"house_stage": house_stage,
		"hub_progression": hub_progression.duplicate(true),
	}


func record_run(result: Dictionary) -> int:
	if result.is_empty():
		return 0
	var run_id := _result_id(result)
	if processed_run_ids.has(run_id):
		return 0
	processed_run_ids.append(run_id)
	_record_extracted_models(result)
	if processed_run_ids.size() > 80:
		processed_run_ids.pop_front()
	var multiplier := 1.10 if unlocked_upgrades.has(&"salvage_protocol") else 1.0
	var reward := maxi(0, floori(float(result.get("money_earned", 0)) * CREDIT_RATE * multiplier))
	var recovered_scrap := maxi(0, int(result.get("scrap_earned", 0)))
	credits += reward
	scrap += recovered_scrap
	statistics.runs = int(statistics.get("runs", 0)) + 1
	var completed := bool(result.get("completed", false))
	statistics.victories = int(statistics.get("victories", 0)) + (1 if completed else 0)
	statistics.deaths = int(statistics.get("deaths", 0)) + (0 if completed else 1)
	statistics.bosses_defeated = int(statistics.get("bosses_defeated", 0)) + (1 if bool(result.get("boss_defeated", false)) else 0)
	statistics.scrap_recovered = int(statistics.get("scrap_recovered", 0)) + recovered_scrap
	statistics.highest_stage = maxi(int(statistics.get("highest_stage", 0)), clampi(int(result.get("stage_index", 0)) + 1, 1, 6))
	var elapsed := float(result.get("elapsed_time", 0.0))
	var best_time := float(statistics.get("best_time", 0.0))
	if completed and elapsed > 0.0 and (best_time <= 0.0 or elapsed < best_time):
		statistics.best_time = elapsed
	save_profile()
	profile_changed.emit()
	return reward


func study_blueprint(model_id: StringName) -> bool:
	if model_id.is_empty() or not recovered_models.has(model_id) or blueprints.has(model_id):
		return false
	blueprints.append(model_id)
	save_profile()
	profile_changed.emit()
	return true


func set_house_stage(value: int) -> bool:
	var next_stage := clampi(value, 0, 3)
	if next_stage == house_stage:
		return false
	house_stage = next_stage
	save_profile()
	profile_changed.emit()
	return true


func set_hub_progression_axis(axis: StringName, level: int) -> bool:
	if not hub_progression.has(axis):
		return false
	var next_level := maxi(level, 0)
	if int(hub_progression[axis]) == next_level:
		return false
	hub_progression[axis] = next_level
	save_profile()
	profile_changed.emit()
	return true


func get_hub_progression_snapshot() -> Dictionary:
	return {
		"house_stage": house_stage,
		"scrap": scrap,
		"recovered_model_count": recovered_models.size(),
		"blueprint_count": blueprints.size(),
		"axes": hub_progression.duplicate(true),
	}


func purchase(item_id: StringName) -> bool:
	if not PURCHASES.has(item_id) or is_unlocked(item_id):
		return false
	var definition: Dictionary = PURCHASES[item_id]
	var cost := int(definition.get("cost", 0))
	if credits < cost:
		return false
	credits -= cost
	if StringName(definition.get("kind", &"")) == &"weapon":
		unlocked_weapons.append(item_id)
	else:
		unlocked_upgrades.append(item_id)
	save_profile()
	profile_changed.emit()
	return true


func is_unlocked(item_id: StringName) -> bool:
	return unlocked_weapons.has(item_id) or unlocked_upgrades.has(item_id)


func get_run_weapon_pool() -> Array[StringName]:
	var result: Array[StringName] = []
	for weapon_id: StringName in unlocked_weapons:
		if weapon_id != &"scrap_blade" and WeaponCatalog.WEAPONS.has(weapon_id):
			result.append(weapon_id)
	return result if not result.is_empty() else [&"scrap_blade"]


func _apply_save(data: Dictionary) -> void:
	credits = maxi(0, int(data.get("credits", data.get("money", 0))))
	scrap = maxi(0, int(data.get("scrap", 0)))
	for value: Variant in _as_array(data.get("unlocked_weapons", [&"scrap_blade"])):
		var weapon_id := StringName(value)
		if WeaponCatalog.WEAPONS.has(weapon_id) and not unlocked_weapons.has(weapon_id):
			unlocked_weapons.append(weapon_id)
	for value: Variant in _as_array(data.get("unlocked_upgrades", [])):
		var upgrade_id := StringName(value)
		if PURCHASES.has(upgrade_id) and not unlocked_upgrades.has(upgrade_id):
			unlocked_upgrades.append(upgrade_id)
	var stored_stats: Variant = data.get("statistics", {})
	if stored_stats is Dictionary:
		for key: Variant in stored_stats:
			statistics[key] = stored_stats[key]
	for value: Variant in _as_array(data.get("processed_run_ids", [])):
		var run_id := String(value)
		if not run_id.is_empty() and not processed_run_ids.has(run_id):
			processed_run_ids.append(run_id)
	for value: Variant in _as_array(data.get("recovered_models", [])):
		var model_id := StringName(value)
		if WeaponCatalog.WEAPONS.has(model_id) and not recovered_models.has(model_id):
			recovered_models.append(model_id)
	for value: Variant in _as_array(data.get("blueprints", [])):
		var blueprint_id := StringName(value)
		if WeaponCatalog.WEAPONS.has(blueprint_id) and not blueprints.has(blueprint_id):
			blueprints.append(blueprint_id)
	house_stage = clampi(int(data.get("house_stage", 0)), 0, 3)
	var stored_hub: Variant = data.get("hub_progression", {})
	if stored_hub is Dictionary:
		for axis: StringName in hub_progression.keys():
			hub_progression[axis] = maxi(int((stored_hub as Dictionary).get(axis, (stored_hub as Dictionary).get(String(axis), 0))), 0)


func _reset_defaults() -> void:
	credits = 0
	scrap = 0
	unlocked_weapons = [&"scrap_blade", &"breaker_maul"]
	unlocked_upgrades.clear()
	statistics = {"runs": 0, "victories": 0, "deaths": 0, "bosses_defeated": 0, "best_time": 0.0, "highest_stage": 0, "scrap_recovered": 0}
	processed_run_ids.clear()
	recovered_models.clear()
	blueprints.clear()
	house_stage = 0
	hub_progression = {&"workshop": 0, &"infrastructure": 0, &"operations": 0, &"storage": 0, &"spark": 0}


func _record_extracted_models(result: Dictionary) -> void:
	if not bool(result.get("completed", false)):
		return
	var found: Variant = result.get("weapons_found", {})
	if found is not Dictionary:
		return
	for participant_value: Variant in (found as Dictionary).values():
		for weapon_value: Variant in _as_array(participant_value):
			var model_id := StringName(weapon_value)
			if WeaponCatalog.WEAPONS.has(model_id) and not recovered_models.has(model_id):
				recovered_models.append(model_id)


func _result_id(result: Dictionary) -> String:
	var explicit_id := String(result.get("run_id", ""))
	if not explicit_id.is_empty():
		return explicit_id
	return "legacy:%d" % hash(JSON.stringify(result))


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value as Array
	if value is PackedStringArray:
		return Array(value)
	if value == null:
		return []
	return [value]
