class_name WorldCatalog
extends RefCounted
const PATH := "res://content/world/catalog_v1.json"
var data: Dictionary = {}
var error := ""


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		data = parsed
	if not validate():
		error = "invalid_world_catalog"


func validate() -> bool:
	if int(data.get("schema_version", 0)) != 1:
		return false
	for key in ["states", "city_templates", "municipalities", "guard_slots"]:
		if data.get(key) is not Array or data[key].is_empty():
			return false
		var seen: Dictionary = {}
		for entry: Variant in data[key]:
			if entry is not Dictionary or not safe_id(String(entry.get("id", ""))) or seen.has(entry.id):
				return false
			seen[entry.id] = true
	var eligible := 0
	for state: Dictionary in data.states:
		eligible += 1 if bool(state.get("eligible_guard", false)) else 0
	return eligible >= data.guard_slots.size()


static func safe_id(id: String) -> bool:
	if id.is_empty() or id.length() > 96:
		return false
	for character in id:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true


func municipality_for_biome(kind: String) -> String:
	for entry: Dictionary in data.get("municipalities", []):
		if String(entry.biome_kind) == kind:
			return String(entry.id)
	return ""


func municipality(id: String) -> Dictionary:
	for entry: Dictionary in data.get("municipalities", []):
		if String(entry.id) == id:
			return entry.duplicate(true)
	return {}
