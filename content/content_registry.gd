class_name ContentRegistry
extends RefCounted
## No autoload, filesystem scan, RNG, save or RPC changes.
const DATA = preload("res://content/catalog.tres")
static var _profiles: Dictionary = {}


static func biome_id(id: StringName) -> StringName:
	return StringName(DATA.aliases.get(String(id), String(id)))


static func biome(id: StringName) -> Dictionary:
	return (DATA.biomes.get(String(biome_id(id)), DATA.biomes["biome_01"]) as Dictionary).duplicate(true)


static func archetype(kind: StringName) -> StringName:
	return &"melee" if kind == &"common" else kind


static func enemy_variant(biome: StringName, kind: StringName, requested: StringName = &"") -> Dictionary:
	var role := String(archetype(kind))
	var entry: Dictionary = DATA.enemy_variants.get(String(requested), {})
	if not entry.is_empty() and entry.get("archetype") == role and entry.get("biome_id") == String(biome_id(biome)):
		return entry.duplicate(true)
	var roster: Dictionary = ContentRegistry.biome(biome).get("enemy_roster", {})
	var id := String(roster.get(role, ""))
	return (DATA.enemy_variants.get(id, {}) as Dictionary).duplicate(true)


static func profile(id: StringName) -> ContentVisualProfile:
	if id.is_empty():
		return null
	if _profiles.has(id):
		return _profiles[id] as ContentVisualProfile
	var path := String(DATA.visual_profiles.get(String(id), ""))
	var result: ContentVisualProfile = null
	if not path.is_empty() and ResourceLoader.exists(path):
		result = load(path) as ContentVisualProfile
	_profiles[id] = result
	return result


static func entry_profile(entry: Dictionary) -> ContentVisualProfile:
	return profile(StringName(entry.get("visual_profile_id", "")))


static func character(id: StringName) -> Dictionary:
	var key := String(id)
	if not key.begins_with("player_"):
		key = "player_" + key
	return (DATA.characters.get(key, DATA.characters["player_jhon"]) as Dictionary).duplicate(true)


static func weapon(id: StringName) -> Dictionary:
	return (DATA.weapons.get(String(id), DATA.weapons["scrap_blade"]) as Dictionary).duplicate(true)


static func hub_stage(id: StringName) -> Dictionary:
	return (DATA.hub_stages.get(String(id), DATA.hub_stages["hub_stage_00"]) as Dictionary).duplicate(true)


static func texture(entry: Dictionary, slot: String, fallback: Texture2D) -> Texture2D:
	# Only one authored fallback level: reserved environments -> current package.
	var base_id := String(entry.get("fallback_biome_id", entry.get("fallback_stage_id", "")))
	if not base_id.is_empty():
		var base: Dictionary = DATA.biomes.get(base_id, DATA.hub_stages.get(base_id, {}))
		var base_visual := entry_profile(base)
		if base_visual != null:
			fallback = base_visual.texture(slot, fallback)
	var visual := entry_profile(entry)
	return visual.texture(slot, fallback) if visual != null else fallback


static func atlas_texture(entry: Dictionary, slot: String, fallback: Texture2D) -> Texture2D:
	var result := texture(entry, slot, fallback)
	# Existing adapters have authored region tables. A changed atlas layout requires
	# a dedicated presentation adapter; don't silently crop another concept sheet.
	return result if result.get_size() == fallback.get_size() else fallback


static func apply_ui_theme(control: Control) -> void:
	var visual := entry_profile(DATA.ui_profiles.get("ui_default", {}))
	if visual == null:
		return
	var candidate := visual.asset("theme") as Theme
	if candidate != null:
		control.theme = candidate


static func ui_texture(slot: String, fallback: Texture2D) -> Texture2D:
	return texture(DATA.ui_profiles.get("ui_default", {}), slot, fallback)
