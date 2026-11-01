class_name MetaProgression
extends Node

signal profile_changed

const SAVE_VERSION := 4
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
## v4 (01/11/2026): arsenal fabricado (id -> raridade), loadout de partida, cyberwares
## (estoque + instalados por slot) e os dois acessórios ativos. Saves v1-v3 carregam
## com esses campos vazios; nada antigo é descartado.
var armory: Dictionary = {&"scrap_blade": &"common"}
var loadout_weapons: Array[StringName] = [&"scrap_blade", &""]
var cyberwares: Array[Dictionary] = []
var installed_cyberwares: Dictionary = {}
var owned_accessories: Array[StringName] = []
var equipped_accessories: Array[StringName] = [&"", &""]
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
		"armory": _string_dictionary(armory),
		"loadout_weapons": _string_array(loadout_weapons),
		"cyberwares": _serialize_cyberwares(),
		"installed_cyberwares": _string_dictionary(installed_cyberwares),
		"owned_accessories": _string_array(owned_accessories),
		"equipped_accessories": _string_array(equipped_accessories),
	}


func record_run(result: Dictionary) -> int:
	if result.is_empty():
		return 0
	var run_id := _result_id(result)
	if processed_run_ids.has(run_id):
		return 0
	processed_run_ids.append(run_id)
	_record_extracted_models(result)
	_record_found_blueprints(result)
	_record_found_cyberwares(result)
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
	# Protótipos descobríveis aparecem nas runs para que o blueprint possa ser recuperado.
	for weapon_id: StringName in WeaponCatalog.discoverable_ids():
		if not result.has(weapon_id):
			result.append(weapon_id)
	return result if not result.is_empty() else [&"scrap_blade"]


# --- Arsenal: blueprint -> estudo -> fabricação -> loadout -------------------------

func is_blueprint_known(weapon_id: StringName) -> bool:
	return weapon_id == &"scrap_blade" or blueprints.has(weapon_id) or unlocked_weapons.has(weapon_id)


func armory_rarity(weapon_id: StringName) -> StringName:
	return RarityTable.normalize(armory.get(weapon_id, &"common"))


func can_fabricate_weapon(weapon_id: StringName, rarity: StringName) -> bool:
	if not WeaponCatalog.WEAPONS.has(weapon_id) or not is_blueprint_known(weapon_id):
		return false
	if not RarityTable.enabled_tiers().has(rarity):
		return false
	if armory.has(weapon_id) and not RarityTable.is_better(rarity, armory_rarity(weapon_id)):
		return false
	return scrap >= WeaponCatalog.craft_cost(weapon_id, rarity)


func fabricate_weapon(weapon_id: StringName, rarity: StringName) -> bool:
	if not can_fabricate_weapon(weapon_id, rarity):
		return false
	scrap -= WeaponCatalog.craft_cost(weapon_id, rarity)
	armory[weapon_id] = RarityTable.normalize(rarity)
	_commit()
	return true


func set_loadout_weapon(slot: int, weapon_id: StringName) -> bool:
	if slot < 0 or slot > 1:
		return false
	if weapon_id.is_empty():
		if slot == 0 or loadout_weapons[1 - slot].is_empty():
			return false
		loadout_weapons[slot] = &""
		_commit()
		return true
	if not armory.has(weapon_id):
		return false
	var other := loadout_weapons.find(weapon_id)
	if other >= 0 and other != slot:
		loadout_weapons[other] = loadout_weapons[slot]
	loadout_weapons[slot] = weapon_id
	if loadout_weapons[0].is_empty():
		loadout_weapons = [loadout_weapons[1], &""]
	_commit()
	return true


# --- Cyberwares --------------------------------------------------------------------

func find_cyberware(uid: String) -> Dictionary:
	for instance: Dictionary in cyberwares:
		if String(instance.uid) == uid:
			return instance
	return {}


func fabricate_cyberware(line: StringName, rarity: StringName) -> Dictionary:
	var cost := CyberwareCatalog.fabricate_cost(rarity)
	if not CyberwareCatalog.has_line(line) or not RarityTable.enabled_tiers().has(rarity) or scrap < cost:
		return {}
	scrap -= cost
	var instance := CyberwareCatalog.make_instance(line, rarity, 1)
	cyberwares.append(instance)
	_commit()
	return instance


func upgrade_cyberware(uid: String) -> bool:
	var instance := find_cyberware(uid)
	var cost := CyberwareCatalog.upgrade_cost(instance)
	if instance.is_empty() or cost < 0 or scrap < cost:
		return false
	scrap -= cost
	instance["level"] = int(instance.level) + 1
	_commit()
	return true


func install_cyberware(uid: String) -> bool:
	var instance := find_cyberware(uid)
	if instance.is_empty():
		return false
	var slot := CyberwareCatalog.slot_for(StringName(instance.line))
	if String(installed_cyberwares.get(slot, "")) == uid:
		return false
	installed_cyberwares[slot] = uid
	_commit()
	return true


func uninstall_cyberware(slot: StringName) -> bool:
	if not installed_cyberwares.has(slot):
		return false
	installed_cyberwares.erase(slot)
	_commit()
	return true


func is_cyberware_installed(uid: String) -> bool:
	return installed_cyberwares.values().has(uid)


func salvage_cyberware(uid: String) -> int:
	var instance := find_cyberware(uid)
	if instance.is_empty() or is_cyberware_installed(uid):
		return 0
	var value := CyberwareCatalog.salvage_value(instance)
	cyberwares.erase(instance)
	scrap += value
	_commit()
	return value


func get_installed_cyberware_instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: StringName in GameplayProgressionFoundation.CYBERWARE_SLOTS:
		var instance := find_cyberware(String(installed_cyberwares.get(slot, "")))
		if not instance.is_empty():
			result.append(instance.duplicate(true))
	return result


# --- Acessórios ativos (2 slots) -----------------------------------------------------

func fabricate_accessory(accessory_id: StringName) -> bool:
	var cost := AccessoryCatalog.craft_cost(accessory_id)
	if not AccessoryCatalog.has_accessory(accessory_id) or owned_accessories.has(accessory_id) or scrap < cost:
		return false
	scrap -= cost
	owned_accessories.append(accessory_id)
	if equipped_accessories.has(&""):
		equipped_accessories[equipped_accessories.find(&"")] = accessory_id
	_commit()
	return true


func equip_accessory(slot: int, accessory_id: StringName) -> bool:
	if slot < 0 or slot >= AccessoryCatalog.SLOT_COUNT:
		return false
	if not accessory_id.is_empty() and not owned_accessories.has(accessory_id):
		return false
	var other := equipped_accessories.find(accessory_id) if not accessory_id.is_empty() else -1
	if other >= 0 and other != slot:
		equipped_accessories[other] = equipped_accessories[slot]
	equipped_accessories[slot] = accessory_id
	_commit()
	return true


## Pacote aplicado ao jogador ao entrar no hub/começar uma run.
func get_run_loadout() -> Dictionary:
	var weapons: Array = []
	for weapon_id: StringName in loadout_weapons:
		if not weapon_id.is_empty() and armory.has(weapon_id):
			weapons.append([weapon_id, armory_rarity(weapon_id)])
	if weapons.is_empty():
		weapons.append([&"scrap_blade", &"common"])
	return {"weapons": weapons, "cyberwares": get_installed_cyberware_instances(), "accessories": equipped_accessories.duplicate()}


func _commit() -> void:
	save_profile()
	profile_changed.emit()


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
	_apply_equipment_save(data)
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
	armory = {&"scrap_blade": &"common"}
	loadout_weapons = [&"scrap_blade", &""]
	cyberwares.clear()
	installed_cyberwares.clear()
	owned_accessories.clear()
	equipped_accessories = [&"", &""]
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


## Blueprints viajam pelo link de dados do Jhon: valem mesmo em derrota.
func _record_found_blueprints(result: Dictionary) -> void:
	for value: Variant in _as_array(result.get("blueprints_found", [])):
		var model_id := StringName(value)
		if WeaponCatalog.WEAPONS.has(model_id) and not recovered_models.has(model_id) and not is_blueprint_known(model_id):
			recovered_models.append(model_id)


## Cyberware achado: extraído em vitória; em derrota vira sucata reaproveitável.
func _record_found_cyberwares(result: Dictionary) -> void:
	var completed := bool(result.get("completed", false))
	for value: Variant in _as_array(result.get("cyberwares_found", [])):
		var instance := CyberwareCatalog.normalize_instance(value)
		if instance.is_empty() or not find_cyberware(String(instance.uid)).is_empty():
			continue
		if completed:
			cyberwares.append(instance)
		else:
			scrap += CyberwareCatalog.salvage_value(instance)


func _apply_equipment_save(data: Dictionary) -> void:
	var stored_armory: Variant = data.get("armory", {})
	if stored_armory is Dictionary:
		for key: Variant in stored_armory:
			var weapon_id := StringName(str(key))
			if WeaponCatalog.WEAPONS.has(weapon_id):
				armory[weapon_id] = RarityTable.normalize((stored_armory as Dictionary)[key])
	var stored_loadout := _as_array(data.get("loadout_weapons", []))
	if stored_loadout.size() == 2:
		var parsed: Array[StringName] = []
		for value: Variant in stored_loadout:
			var weapon_id := StringName(str(value))
			parsed.append(weapon_id if armory.has(weapon_id) and not parsed.has(weapon_id) else &"")
		if not parsed[0].is_empty():
			loadout_weapons = parsed
	for value: Variant in _as_array(data.get("cyberwares", [])):
		var instance := CyberwareCatalog.normalize_instance(value)
		if not instance.is_empty() and find_cyberware(String(instance.uid)).is_empty():
			cyberwares.append(instance)
	var stored_installed: Variant = data.get("installed_cyberwares", {})
	if stored_installed is Dictionary:
		for key: Variant in stored_installed:
			var slot := StringName(str(key))
			var uid := String((stored_installed as Dictionary)[key])
			var instance := find_cyberware(uid)
			if GameplayProgressionFoundation.is_supported_cyberware_slot(slot) and not instance.is_empty() and CyberwareCatalog.slot_for(StringName(instance.line)) == slot:
				installed_cyberwares[slot] = uid
	for value: Variant in _as_array(data.get("owned_accessories", [])):
		var accessory_id := StringName(str(value))
		if AccessoryCatalog.has_accessory(accessory_id) and not owned_accessories.has(accessory_id):
			owned_accessories.append(accessory_id)
	var stored_equipped := _as_array(data.get("equipped_accessories", []))
	for slot in mini(stored_equipped.size(), AccessoryCatalog.SLOT_COUNT):
		var accessory_id := StringName(str(stored_equipped[slot]))
		if owned_accessories.has(accessory_id) and not equipped_accessories.has(accessory_id):
			equipped_accessories[slot] = accessory_id


func _serialize_cyberwares() -> Array:
	var result: Array = []
	for instance: Dictionary in cyberwares:
		result.append({"uid": String(instance.uid), "line": String(instance.line), "rarity": String(instance.rarity), "level": int(instance.level)})
	return result


func _string_dictionary(source: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in source:
		result[String(key)] = String(source[key])
	return result


func _string_array(source: Array) -> Array:
	var result: Array = []
	for value: Variant in source:
		result.append(String(value))
	return result


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
