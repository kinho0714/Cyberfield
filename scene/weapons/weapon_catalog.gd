class_name WeaponCatalog
extends RefCounted
## Catálogo orientado a dados. Cada arma tem uma CATEGORIA (comportamento) e números base;
## a raridade da instância (RarityTable) multiplica dano/cadência/carregador.
## Nova arma = nova entrada aqui + sprite em assets/arsenal/sprites_v2/<id>.png.
## "rarity" no catálogo é a classe do modelo (legado/descrição); a raridade real de cada
## cópia fica no inventário do jogador e no arsenal do laboratório.

const CATEGORIES := {
	&"blade": {"label": "LÂMINA", "type": &"melee", "swing": &"slash", "color": Color("5fe5f3")},
	&"blunt": {"label": "IMPACTO", "type": &"melee", "swing": &"smash", "color": Color("ffb347")},
	&"pistol": {"label": "PISTOLA", "type": &"ranged", "muzzle": &"small", "color": Color("ffd27a")},
	&"semi_auto": {"label": "SEMIAUTOMÁTICA", "type": &"ranged", "muzzle": &"pulse", "color": Color("8deaff")},
	&"shotgun": {"label": "ESCOPETA", "type": &"ranged", "muzzle": &"wide", "color": Color("ff8a3d")},
	&"rifle": {"label": "RIFLE", "type": &"ranged", "muzzle": &"beam", "color": Color("7dff9c")},
	&"bow": {"label": "ARCO", "type": &"ranged", "muzzle": &"arc", "color": Color("f1b8ff")},
}

const WEAPONS := {
	# --- corpo a corpo ---
	&"scrap_blade": {"name": "LÂMINA DE SUCATA", "description": "Lâmina leve recuperada da Cidade Baixa.", "category": &"blade", "type": &"melee", "damage": 40, "cooldown": 0.20, "range": 30.0, "knockback": 1.0, "rarity": &"common", "craft_cost": 0},
	&"breaker_maul": {"name": "MARTELO QUEBRADOR", "description": "Golpes pesados que empurram o alvo.", "category": &"blunt", "type": &"melee", "damage": 58, "cooldown": 0.34, "range": 34.0, "knockback": 1.35, "rarity": &"uncommon", "craft_cost": 14},
	&"arc_saber": {"name": "SABRE ÍON", "description": "Lâmina de energia ágil e de maior alcance.", "category": &"blade", "type": &"melee", "damage": 45, "cooldown": 0.23, "range": 40.0, "knockback": 0.90, "rarity": &"uncommon", "craft_cost": 16},
	&"baseball_bat": {"name": "BASTÃO DE BEISEBOL", "description": "Taco reforçado com fita e pregos. Arremessa inimigos longe.", "category": &"blunt", "type": &"melee", "damage": 48, "cooldown": 0.28, "range": 34.0, "knockback": 1.6, "rarity": &"common", "craft_cost": 8, "discoverable": true},
	&"iron_pipe": {"name": "CANO DE FERRO", "description": "Cano hidráulico: alcance longo e golpes constantes.", "category": &"blunt", "type": &"melee", "damage": 42, "cooldown": 0.24, "range": 42.0, "knockback": 1.2, "rarity": &"common", "craft_cost": 6, "discoverable": true},
	# --- pistolas ---
	&"scrap_pistol": {"name": "PISTOLA IMPROVISADA", "description": "Cano soldado e gatilho de mola. Barata e imprecisa.", "category": &"pistol", "type": &"ranged", "damage": 22, "cooldown": 0.30, "range": 330.0, "knockback": 0.45, "rarity": &"common", "magazine": 8, "reserve": 48, "reload_time": 1.3, "projectile_speed": 640.0, "spread": 4.0, "projectile": &"scrap_round", "shot_sfx": &"weapon_fire_small", "craft_cost": 8, "discoverable": true},
	&"corp_pistol": {"name": "PISTOLA CORPORATIVA", "description": "Modelo de segurança da Arcádia: precisa e de recarga rápida.", "category": &"pistol", "type": &"ranged", "damage": 28, "cooldown": 0.24, "range": 420.0, "knockback": 0.50, "rarity": &"uncommon", "magazine": 12, "reserve": 60, "reload_time": 1.0, "projectile_speed": 780.0, "spread": 1.5, "projectile": &"corp_round", "shot_sfx": &"weapon_fire_small", "craft_cost": 14, "discoverable": true},
	# --- semiautomática ---
	&"pulse_carbine": {"name": "CARABINA PULSO", "description": "Carabina leve semiautomática: rajadas rápidas com carregador ampliado.", "category": &"semi_auto", "type": &"ranged", "damage": 25, "cooldown": 0.15, "range": 520.0, "knockback": 0.60, "rarity": &"rare", "magazine": 18, "reserve": 90, "reload_time": 1.4, "projectile_speed": 730.0, "spread": 3.5, "projectile": &"pulse_bolt", "shot_sfx": &"weapon_fire_small", "craft_cost": 18},
	# --- escopeta ---
	&"scrap_shotgun": {"name": "ESCOPETA DE SUCATA", "description": "Seis chumbos em leque. Devastadora de perto.", "category": &"shotgun", "type": &"ranged", "damage": 14, "pellets": 6, "cooldown": 0.75, "range": 210.0, "knockback": 1.6, "rarity": &"common", "magazine": 4, "reserve": 24, "reload_time": 1.9, "projectile_speed": 560.0, "spread": 18.0, "projectile": &"pellet", "shot_sfx": &"weapon_fire_large", "craft_cost": 12, "discoverable": true},
	# --- rifle ---
	&"pulse_rifle": {"name": "RIFLE DE PULSO", "description": "Feixe concentrado que atravessa até três alvos.", "category": &"rifle", "type": &"ranged", "damage": 70, "pierce": 2, "cooldown": 0.85, "range": 720.0, "knockback": 0.9, "rarity": &"rare", "magazine": 5, "reserve": 25, "reload_time": 2.0, "projectile_speed": 1080.0, "spread": 0.0, "projectile": &"rifle_beam", "shot_sfx": &"weapon_fire_large", "craft_cost": 22, "discoverable": true},
	# --- arcos cyberpunk ---
	&"arc_emitter": {"name": "EMISSOR DE ARCO", "description": "Arco de bobina: flecha de plasma em parábola que perfura um alvo.", "category": &"bow", "type": &"ranged", "damage": 34, "pierce": 1, "gravity": 260.0, "cooldown": 0.42, "range": 360.0, "knockback": 0.55, "rarity": &"rare", "magazine": 8, "reserve": 40, "reload_time": 1.65, "projectile_speed": 620.0, "spread": 0.0, "projectile": &"arc_arrow", "shot_sfx": &"weapon_fire_large", "craft_cost": 16},
	&"neon_longbow": {"name": "ARCO NEON", "description": "Arco longo de fibra óptica: flechas rápidas que atravessam dois alvos.", "category": &"bow", "type": &"ranged", "damage": 52, "pierce": 2, "gravity": 170.0, "cooldown": 0.62, "range": 560.0, "knockback": 0.7, "rarity": &"rare", "magazine": 6, "reserve": 30, "reload_time": 1.5, "projectile_speed": 840.0, "spread": 0.0, "projectile": &"neon_arrow", "shot_sfx": &"weapon_fire_large", "craft_cost": 20, "discoverable": true},
}

const TEMPORARY_SPRITES := {
	&"scrap_blade": preload("res://assets/arsenal/sprites/scrap_blade.png"),
	&"breaker_maul": preload("res://assets/arsenal/sprites/breaker_maul.png"),
	&"arc_saber": preload("res://assets/arsenal/sprites/arc_saber.png"),
	&"arc_emitter": preload("res://assets/arsenal/sprites/arc_emitter.png"),
	&"pulse_carbine": preload("res://assets/arsenal/sprites/pulse_carbine.png"),
}
## Arte original gerada por tools/visual/arsenal_art.py.
const ORIGINAL_SPRITE_DIR := "res://assets/arsenal/sprites_v2/%s.png"

static var _sprite_cache: Dictionary = {}


static func get_definition(weapon_id: StringName) -> Dictionary:
	return WEAPONS.get(weapon_id, WEAPONS[&"scrap_blade"]) as Dictionary


static func has_weapon(weapon_id: StringName) -> bool:
	return WEAPONS.has(weapon_id)


static func category(weapon_id: StringName) -> StringName:
	return StringName(get_definition(weapon_id).get("category", &"blade"))


static func category_label(weapon_id: StringName) -> String:
	return String((CATEGORIES.get(category(weapon_id), {}) as Dictionary).get("label", "ARMA"))


static func category_color(weapon_id: StringName) -> Color:
	return (CATEGORIES.get(category(weapon_id), {"color": Color.WHITE}) as Dictionary).get("color", Color.WHITE) as Color


## Números efetivos de uma cópia com raridade. Base intacta para raridade comum.
static func stats_for(weapon_id: StringName, rarity: StringName = &"common") -> Dictionary:
	var data := get_definition(weapon_id).duplicate(true)
	var tier := RarityTable.normalize(rarity)
	data["instance_rarity"] = tier
	data["damage"] = maxi(1, roundi(float(data.get("damage", 40)) * RarityTable.stat(tier, "damage")))
	data["cooldown"] = float(data.get("cooldown", 0.2)) * RarityTable.stat(tier, "cooldown")
	if data.has("magazine"):
		data["magazine"] = maxi(1, roundi(float(data.magazine) * RarityTable.stat(tier, "magazine")))
		data["reserve"] = maxi(0, roundi(float(data.get("reserve", 0)) * RarityTable.stat(tier, "magazine")))
	return data


static func craft_cost(weapon_id: StringName, rarity: StringName) -> int:
	return roundi(float(get_definition(weapon_id).get("craft_cost", 10)) * RarityTable.stat(rarity, "craft_cost"))


static func discoverable_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in WEAPONS:
		if bool((WEAPONS[id] as Dictionary).get("discoverable", false)):
			result.append(id)
	return result


static func get_display_name(weapon_id: StringName) -> String:
	if not ContentRegistry.DATA.weapons.has(String(weapon_id)):
		return String(get_definition(weapon_id).get("name", "ARMA"))
	var key := String(ContentRegistry.weapon(weapon_id).get("display_name_key", ""))
	var localized := TranslationServer.translate(key)
	return String(localized) if not key.is_empty() and localized != key else String(get_definition(weapon_id).get("name", "ARMA"))


static func get_visual_texture(weapon_id: StringName, slot: String, fallback: Texture2D = null) -> Texture2D:
	if not WEAPONS.has(weapon_id):
		return fallback
	if not TEMPORARY_SPRITES.has(weapon_id):
		var original_sprite := original_sprite(weapon_id)
		if original_sprite != null:
			return original_sprite
	var original := ContentRegistry.texture(ContentRegistry.weapon(weapon_id), slot, null)
	if original != null and not TEMPORARY_SPRITES.has(weapon_id):
		return original
	return TEMPORARY_SPRITES.get(weapon_id, fallback) as Texture2D


static func original_sprite(weapon_id: StringName) -> Texture2D:
	if _sprite_cache.has(weapon_id):
		return _sprite_cache[weapon_id] as Texture2D
	var path := ORIGINAL_SPRITE_DIR % String(weapon_id)
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_sprite_cache[weapon_id] = texture
	return texture


static func is_ranged(weapon_id: StringName) -> bool:
	return StringName(get_definition(weapon_id).get("type", &"melee")) == &"ranged"
