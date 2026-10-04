class_name WeaponCatalog
extends RefCounted

const WEAPONS := {
	&"scrap_blade": {"name": "LÂMINA DE SUCATA", "type": &"melee", "damage": 40, "cooldown": 0.20, "range": 30.0, "knockback": 1.0, "rarity": &"common"},
	&"breaker_maul": {"name": "MARTELO QUEBRADOR", "type": &"melee", "damage": 58, "cooldown": 0.34, "range": 34.0, "knockback": 1.35, "rarity": &"uncommon"},
	&"arc_emitter": {"name": "EMISSOR DE ARCO", "type": &"ranged", "damage": 34, "cooldown": 0.42, "range": 360.0, "knockback": 0.55, "rarity": &"rare"},
}


static func get_definition(weapon_id: StringName) -> Dictionary:
	return WEAPONS.get(weapon_id, WEAPONS[&"scrap_blade"]) as Dictionary


static func get_display_name(weapon_id: StringName) -> String:
	return String(get_definition(weapon_id).get("name", "ARMA"))
