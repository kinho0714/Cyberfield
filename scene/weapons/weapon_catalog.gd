class_name WeaponCatalog
extends RefCounted

const WEAPONS := {
	&"scrap_blade": {"name": "LÂMINA DE SUCATA", "description": "Lâmina leve recuperada da Cidade Baixa.", "type": &"melee", "damage": 40, "cooldown": 0.20, "range": 30.0, "knockback": 1.0, "rarity": &"common"},
	&"breaker_maul": {"name": "MARTELO QUEBRADOR", "description": "Golpes pesados que empurram o alvo.", "type": &"melee", "damage": 58, "cooldown": 0.34, "range": 34.0, "knockback": 1.35, "rarity": &"uncommon"},
	&"arc_saber": {"name": "SABRE ÍON", "description": "Lâmina de energia ágil e de maior alcance.", "type": &"melee", "damage": 45, "cooldown": 0.23, "range": 40.0, "knockback": 0.90, "rarity": &"uncommon"},
	&"arc_emitter": {"name": "EMISSOR DE ARCO", "description": "Disparos concentrados com cadência moderada.", "type": &"ranged", "damage": 34, "cooldown": 0.42, "range": 360.0, "knockback": 0.55, "rarity": &"rare", "magazine": 8, "reserve": 40, "reload_time": 1.65, "projectile_speed": 620.0, "shot_sfx": &"weapon_fire_large"},
	&"pulse_carbine": {"name": "CARABINA PULSO", "description": "Rajadas rápidas com carregador ampliado.", "type": &"ranged", "damage": 25, "cooldown": 0.15, "range": 520.0, "knockback": 0.60, "rarity": &"rare", "magazine": 18, "reserve": 90, "reload_time": 1.4, "projectile_speed": 730.0, "shot_sfx": &"weapon_fire_small"},
}

const TEMPORARY_SPRITES := {
	&"scrap_blade": preload("res://assets/arsenal/sprites/scrap_blade.png"),
	&"breaker_maul": preload("res://assets/arsenal/sprites/breaker_maul.png"),
	&"arc_saber": preload("res://assets/arsenal/sprites/arc_saber.png"),
	&"arc_emitter": preload("res://assets/arsenal/sprites/arc_emitter.png"),
	&"pulse_carbine": preload("res://assets/arsenal/sprites/pulse_carbine.png"),
}


static func get_definition(weapon_id: StringName) -> Dictionary:
	return WEAPONS.get(weapon_id, WEAPONS[&"scrap_blade"]) as Dictionary


static func get_display_name(weapon_id: StringName) -> String:
	if not ContentRegistry.DATA.weapons.has(String(weapon_id)):
		return String(get_definition(weapon_id).get("name", "ARMA"))
	var key := String(ContentRegistry.weapon(weapon_id).get("display_name_key", ""))
	var localized := TranslationServer.translate(key)
	return String(localized) if not key.is_empty() and localized != key else String(get_definition(weapon_id).get("name", "ARMA"))


static func get_visual_texture(weapon_id: StringName, slot: String, fallback: Texture2D = null) -> Texture2D:
	var original := ContentRegistry.texture(ContentRegistry.weapon(weapon_id), slot, null)
	if original != null and not TEMPORARY_SPRITES.has(weapon_id):
		return original
	return TEMPORARY_SPRITES.get(weapon_id, fallback) as Texture2D


static func is_ranged(weapon_id: StringName) -> bool:
	return StringName(get_definition(weapon_id).get("type", &"melee")) == &"ranged"
