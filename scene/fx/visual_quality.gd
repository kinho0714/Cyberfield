class_name VisualQuality
extends RefCounted
## Visual effects profile (30/10/2026). One switch for every optional effect:
## FULL = everything, REDUCED = no shake/flicker and a third of the particles,
## MINIMAL = sprite hit flash only. Stored apart from LocalSettings on purpose.

const PATH := "user://visual_quality.cfg"
const FULL: StringName = &"full"
const REDUCED: StringName = &"reduced"
const MINIMAL: StringName = &"minimal"
const PROFILES: Array[StringName] = [FULL, REDUCED, MINIMAL]
const LABELS := {&"full": "COMPLETO", &"reduced": "REDUZIDO", &"minimal": "MÍNIMO"}

static var _profile: StringName = &""


static func profile() -> StringName:
	if _profile.is_empty():
		_profile = FULL
		var config := ConfigFile.new()
		if config.load(PATH) == OK:
			var stored := StringName(String(config.get_value("effects", "profile", "full")))
			if PROFILES.has(stored):
				_profile = stored
	return _profile


static func set_profile(value: StringName) -> void:
	if not PROFILES.has(value):
		return
	_profile = value
	var config := ConfigFile.new()
	config.set_value("effects", "profile", String(value))
	config.save(PATH)


static func particle_scale() -> float:
	return {&"full": 1.0, &"reduced": 0.34, &"minimal": 0.0}.get(profile(), 1.0)


static func allows_shake() -> bool:
	return profile() == FULL


static func allows_flicker() -> bool:
	return profile() == FULL


static func flash_strength() -> float:
	return 1.0 if profile() == FULL else 0.5
