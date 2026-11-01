class_name CyberwareCatalog
extends RefCounted
## Seis linhas de cyberware, independentes de armas e acessórios.
## Instância = {"uid", "line", "rarity", "level"}. Raridade multiplica a força do efeito;
## nível (1..MAX_LEVEL) é a melhoria feita na bancada. São conceitos separados.
## Slots vêm de GameplayProgressionFoundation.CYBERWARE_SLOTS (um implante por slot).

const MAX_LEVEL := 3
const FABRICATE_BASE_COST := 10
const UPGRADE_BASE_COST := 6

const LINES := {
	&"strength": {"name": "MIOMOTORES DE FORÇA", "short": "FORÇA", "slot": &"arms", "color": Color("ff6a3d"),
		"description": "Empurrão, impacto do mergulho e golpes corpo a corpo mais rápidos.",
		"per_level": {"knockback": 0.12, "slam_damage": 0.15, "melee_haste": 0.04}},
	&"speed": {"name": "PERNAS CINÉTICAS", "short": "VELOCIDADE", "slot": &"legs", "color": Color("43f2b0"),
		"description": "Atuadores nas pernas: corrida mais rápida.",
		"per_level": {"move_speed": 0.06}},
	&"dash": {"name": "PROPULSOR DE DASH", "short": "DASH", "slot": &"legs", "color": Color("39dff2"),
		"description": "Dash mais longo, mais veloz e com mais invulnerabilidade.",
		"per_level": {"dash_duration": 0.16, "dash_speed": 0.05, "dash_iframes": 0.30}},
	&"physical": {"name": "SERVO-IMPACTO", "short": "DANO FÍSICO", "slot": &"arms", "color": Color("ff2a6d"),
		"description": "Dano físico: armas brancas, mergulho, pistolas e escopetas.",
		"per_level": {"physical_damage": 0.08}},
	&"intellect": {"name": "COPROCESSADOR TÁTICO", "short": "INTELECTO", "slot": &"head_neural", "color": Color("c46bff"),
		"description": "Intelecto aplicado às armas: dano à distância, recarga e precisão.",
		"per_level": {"ranged_damage": 0.07, "reload_speed": 0.08, "accuracy": 0.12}},
	&"health": {"name": "BIOMONITOR VITAL", "short": "SAÚDE", "slot": &"torso", "color": Color("7dff9c"),
		"description": "Vida máxima e eficiência das poções de cura.",
		"per_level": {"max_hp": 0.06, "heal_efficiency": 0.12}},
}

const LINE_ORDER: Array[StringName] = [&"strength", &"speed", &"dash", &"physical", &"intellect", &"health"]
const SLOT_LABELS := {&"head_neural": "NEURAL", &"arms": "BRAÇOS", &"torso": "TORSO", &"legs": "PERNAS"}
const ICON_DIR := "res://assets/cyberware/icons/%s.png"

static var _icon_cache: Dictionary = {}


static func has_line(line: StringName) -> bool:
	return LINES.has(line)


static func line_data(line: StringName) -> Dictionary:
	return LINES.get(line, LINES[&"strength"]) as Dictionary


static func slot_for(line: StringName) -> StringName:
	return StringName(line_data(line).slot)


static func make_instance(line: StringName, rarity: StringName, level: int = 1, uid: String = "") -> Dictionary:
	if uid.is_empty():
		uid = "cw_%s_%d_%d" % [String(line), Time.get_ticks_usec(), randi() % 100000]
	return {"uid": uid, "line": line, "rarity": RarityTable.normalize(rarity), "level": clampi(level, 1, MAX_LEVEL)}


static func normalize_instance(value: Variant) -> Dictionary:
	if value is not Dictionary:
		return {}
	var data := value as Dictionary
	var line := StringName(str(data.get("line", "")))
	var uid := String(data.get("uid", ""))
	if not LINES.has(line) or uid.is_empty():
		return {}
	return {"uid": uid, "line": line, "rarity": RarityTable.normalize(data.get("rarity", "common")), "level": clampi(int(data.get("level", 1)), 1, MAX_LEVEL)}


static func effects(instance: Dictionary) -> Dictionary:
	var line := StringName(instance.get("line", &""))
	if not LINES.has(line):
		return {}
	var scale := float(clampi(int(instance.get("level", 1)), 1, MAX_LEVEL)) * RarityTable.stat(StringName(instance.get("rarity", &"common")), "effect")
	var result := {}
	var per_level: Dictionary = line_data(line).per_level
	for key: String in per_level:
		result[key] = float(per_level[key]) * scale
	return result


static func compute_modifiers(instances: Array) -> Dictionary:
	var total := {}
	for value: Variant in instances:
		var instance := normalize_instance(value)
		var single := effects(instance)
		for key: String in single:
			total[key] = float(total.get(key, 0.0)) + float(single[key])
	return total


static func fabricate_cost(rarity: StringName) -> int:
	return roundi(FABRICATE_BASE_COST * RarityTable.stat(rarity, "craft_cost"))


static func upgrade_cost(instance: Dictionary) -> int:
	var level := int(instance.get("level", 1))
	if level >= MAX_LEVEL:
		return -1
	return roundi(UPGRADE_BASE_COST * level * RarityTable.stat(StringName(instance.get("rarity", &"common")), "craft_cost"))


static func salvage_value(instance: Dictionary) -> int:
	return int(RarityTable.stat(StringName(instance.get("rarity", &"common")), "salvage", 4.0)) * int(instance.get("level", 1))


static func display_name(instance: Dictionary) -> String:
	var line := StringName(instance.get("line", &""))
	return "%s MK%d" % [String(line_data(line).name), int(instance.get("level", 1))]


static func describe(instance: Dictionary) -> String:
	var parts: PackedStringArray = []
	var single := effects(instance)
	for key: String in single:
		parts.append("%s +%d%%" % [_effect_label(key), roundi(float(single[key]) * 100.0)])
	return ", ".join(parts)


static func _effect_label(key: String) -> String:
	return {"knockback": "EMPURRÃO", "slam_damage": "MERGULHO", "melee_haste": "CADÊNCIA C/C",
		"move_speed": "VELOCIDADE", "dash_duration": "DURAÇÃO DASH", "dash_speed": "VEL. DASH",
		"dash_iframes": "INVULN. DASH", "physical_damage": "DANO FÍSICO", "ranged_damage": "DANO À DIST.",
		"reload_speed": "RECARGA", "accuracy": "PRECISÃO", "max_hp": "VIDA MÁX.", "heal_efficiency": "CURA"}.get(key, key.to_upper())


static func icon(line: StringName) -> Texture2D:
	if _icon_cache.has(line):
		return _icon_cache[line] as Texture2D
	var path := ICON_DIR % String(line)
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icon_cache[line] = texture
	return texture
