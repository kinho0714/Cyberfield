class_name AccessoryCatalog
extends RefCounted
## Acessórios/habilidades ativas dos DOIS slots exclusivos (gadget_1/gadget_2).
## Separados das armas e dos cyberwares. Cada um tem cargas e recarga por carga.

const SLOT_COUNT := 2

const ACCESSORIES := {
	&"ice_grenade": {"name": "GRANADA CRIOGÊNICA", "short": "GELO", "kind": &"grenade", "color": Color("8fe9ff"),
		"description": "Congela inimigos na área e os deixa lentos depois.",
		"charges": 2, "recharge": 9.0, "radius": 115.0, "damage": 18, "freeze": 1.6, "slow": 0.45, "slow_time": 2.6,
		"throw_speed": Vector2(330.0, -300.0), "craft_cost": 12},
	&"fire_grenade": {"name": "GRANADA INCENDIÁRIA", "short": "FOGO", "kind": &"grenade", "color": Color("ff7a2f"),
		"description": "Explosão e chamas no chão que queimam quem fica na área.",
		"charges": 2, "recharge": 10.0, "radius": 105.0, "damage": 42, "burn_dps": 26.0, "burn_time": 3.0, "zone_time": 3.5,
		"throw_speed": Vector2(330.0, -300.0), "craft_cost": 14},
	&"portable_turret": {"name": "TORRETA PORTÁTIL", "short": "TORRETA", "kind": &"turret", "color": Color("ffd27a"),
		"description": "Dispositivo no chão que localiza e ataca inimigos sozinho.",
		"charges": 1, "recharge": 22.0, "duration": 12.0, "range": 320.0, "fire_interval": 0.45, "damage": 18,
		"projectile_speed": 760.0, "craft_cost": 20},
}

const ORDER: Array[StringName] = [&"ice_grenade", &"fire_grenade", &"portable_turret"]
const ICON_DIR := "res://assets/accessories/%s_icon.png"

static var _icon_cache: Dictionary = {}


static func has_accessory(id: StringName) -> bool:
	return ACCESSORIES.has(id)


static func get_definition(id: StringName) -> Dictionary:
	return ACCESSORIES.get(id, {}) as Dictionary


static func display_name(id: StringName) -> String:
	return String(get_definition(id).get("name", "VAZIO"))


static func craft_cost(id: StringName) -> int:
	return int(get_definition(id).get("craft_cost", 10))


static func icon(id: StringName) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id] as Texture2D
	var path := ICON_DIR % String(id)
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icon_cache[id] = texture
	return texture
