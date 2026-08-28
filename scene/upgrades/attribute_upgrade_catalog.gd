class_name AttributeUpgradeCatalog
extends RefCounted

const DEFINITIONS := {
	&"health_capacity": {"category": &"health", "name": "CAPACIDADE", "effect": "+HP máximo", "key": &"max_health", "magnitude": 1.0},
	&"health_recovery": {"category": &"health", "name": "RECUPERAÇÃO", "effect": "+8% de cura por dose", "key": &"healing", "magnitude": 0.08},
	&"health_resilience": {"category": &"health", "name": "RESILIÊNCIA", "effect": "-6% de dano recebido", "key": &"resistance", "magnitude": 0.06},
	&"strength_power": {"category": &"strength", "name": "POTÊNCIA", "effect": "+16% de dano melee", "key": &"melee_damage", "magnitude": 0.16},
	&"strength_impact": {"category": &"strength", "name": "IMPACTO", "effect": "+20% de knockback", "key": &"knockback", "magnitude": 0.20},
	&"strength_slam": {"category": &"strength", "name": "QUEDA PESADA", "effect": "+20% de dano do slam", "key": &"slam_damage", "magnitude": 0.20},
	&"intellect_climber": {"category": &"intellect", "name": "ESCALADOR", "effect": "+0,5 s de escalada", "key": &"climb_stamina", "magnitude": 0.5},
	&"intellect_dash": {"category": &"intellect", "name": "CIRCUITO ÁGIL", "effect": "+8% de duração do dash", "key": &"dash_duration", "magnitude": 0.08},
	&"intellect_tech": {"category": &"intellect", "name": "AMPLIFICADOR", "effect": "+12% de dano tecnológico", "key": &"tech_damage", "magnitude": 0.12},
}

const CATEGORY_LABELS := {&"health": "SAÚDE", &"strength": "FORÇA", &"intellect": "INTELECTO"}


static func get_definition(upgrade_id: StringName) -> Dictionary:
	return DEFINITIONS.get(upgrade_id, {}) as Dictionary


static func get_category(upgrade_id: StringName) -> StringName:
	return StringName(get_definition(upgrade_id).get("category", upgrade_id))


static func get_ids_for_category(category: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for id_value: Variant in DEFINITIONS.keys():
		var upgrade_id := StringName(id_value)
		if get_category(upgrade_id) == category:
			result.append(upgrade_id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result
