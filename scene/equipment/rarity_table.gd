class_name RarityTable
extends RefCounted
## Raridade de instância (arma/cyberware). Conceito separado do NÍVEL de melhoria.
## Tiers superiores já estão descritos aqui (épico/lendário) mas ficam fora do loot
## até `enabled` virar true: nenhuma outra parte do código precisa ser reescrita.

const ORDER: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]

const TIERS := {
	&"common": {"label": "COMUM", "color": Color("b8c4cc"), "damage": 1.00, "cooldown": 1.00, "magazine": 1.00, "effect": 1.00, "craft_cost": 1.0, "salvage": 4, "weight": 70.0, "enabled": true},
	&"uncommon": {"label": "INCOMUM", "color": Color("43f2b0"), "damage": 1.15, "cooldown": 0.95, "magazine": 1.15, "effect": 1.35, "craft_cost": 2.0, "salvage": 9, "weight": 24.0, "enabled": true},
	&"rare": {"label": "RARO", "color": Color("5aa8ff"), "damage": 1.32, "cooldown": 0.90, "magazine": 1.30, "effect": 1.75, "craft_cost": 3.5, "salvage": 16, "weight": 6.0, "enabled": true},
	&"epic": {"label": "ÉPICO", "color": Color("c46bff"), "damage": 1.50, "cooldown": 0.86, "magazine": 1.45, "effect": 2.2, "craft_cost": 6.0, "salvage": 28, "weight": 0.0, "enabled": false},
	&"legendary": {"label": "LENDÁRIO", "color": Color("ffb347"), "damage": 1.75, "cooldown": 0.82, "magazine": 1.60, "effect": 2.8, "craft_cost": 10.0, "salvage": 45, "weight": 0.0, "enabled": false},
}


static func normalize(rarity: Variant) -> StringName:
	var id := StringName(str(rarity)) if rarity != null else &"common"
	return id if TIERS.has(id) else &"common"


static func index(rarity: StringName) -> int:
	return maxi(ORDER.find(normalize(rarity)), 0)


static func is_better(candidate: StringName, current: StringName) -> bool:
	return index(candidate) > index(current)


static func enabled_tiers() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in ORDER:
		if bool((TIERS[id] as Dictionary).get("enabled", false)):
			result.append(id)
	return result


static func stat(rarity: StringName, key: String, fallback: float = 1.0) -> float:
	return float((TIERS.get(normalize(rarity), {}) as Dictionary).get(key, fallback))


static func label(rarity: StringName) -> String:
	return String((TIERS[normalize(rarity)] as Dictionary).label)


static func color(rarity: StringName) -> Color:
	return (TIERS[normalize(rarity)] as Dictionary).color as Color


## Sorteio com viés de estágio: estágios avançados empurram o peso para cima.
static func roll(rng: RandomNumberGenerator, stage_bonus: int = 0, minimum: StringName = &"common") -> StringName:
	var tiers := enabled_tiers()
	var total := 0.0
	var weights: Array[float] = []
	for id: StringName in tiers:
		var weight := float((TIERS[id] as Dictionary).weight)
		if index(id) < index(minimum):
			weight = 0.0
		elif index(id) > 0:
			weight *= 1.0 + 0.35 * float(maxi(stage_bonus, 0))
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return normalize(minimum)
	var pick := rng.randf() * total
	for i in tiers.size():
		pick -= weights[i]
		if pick <= 0.0:
			return tiers[i]
	return tiers[tiers.size() - 1]
