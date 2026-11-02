class_name WeaponLootTable
extends RefCounted
## P1-B (02/11/2026): distribuição de armas nas runs, orientada a dados.
##
## Antes: só um pickup avulso por bioma (38%), sorteio uniforme, baús nunca davam armas e o
## bônus de raridade por estágio nunca era aplicado (o id do pickup não tinha número).
##
## Agora cada estágio monta uma SEQUÊNCIA de ofertas (sorteio ponderado sem reposição):
##   índice 0 → pickup avulso do bioma (mesmo gate de 38% do gerador, RNG preservado);
##   índice N → baú `..._loot_NN` (comum ou trap), se o baú sorteou conter arma.
## Pesos = afinidade do bioma × curva de progressão por estágio × antirrepetição entre
## estágios. Tudo determinístico por semente/estágio/id — host e clientes LAN chegam ao
## mesmo resultado sem trocar mensagens, e o RNG da geração do bioma não é consumido.

const SOURCES := {
	&"biome_pickup": {"chance": 1.0, "min_rarity": &"common", "rarity_bonus": 0},
	&"chest": {"chance": 0.30, "min_rarity": &"common", "rarity_bonus": 0},
	&"trap_reward": {"chance": 0.75, "min_rarity": &"uncommon", "rarity_bonus": 1},
	&"boss": {"chance": 1.0, "min_rarity": &"rare", "rarity_bonus": 2},
}

## Identidade de cada bioma por categoria (Cidade Baixa: polícia, gangues, armas de rua;
## Industrial: ferramentas pesadas e escopetas; Laboratório: energia, precisão e lâminas).
const BIOME_AFFINITY := {
	&"lower_city": {&"pistol": 1.6, &"blunt": 1.4, &"shotgun": 1.3, &"semi_auto": 1.1, &"blade": 0.9, &"rifle": 0.5, &"bow": 0.55},
	&"industrial": {&"blunt": 1.45, &"shotgun": 1.35, &"semi_auto": 1.3, &"rifle": 1.0, &"pistol": 0.9, &"blade": 0.75, &"bow": 0.7},
	&"lab": {&"rifle": 1.55, &"bow": 1.45, &"blade": 1.35, &"semi_auto": 1.2, &"pistol": 0.85, &"shotgun": 0.7, &"blunt": 0.6},
}
const HOME_BIOME_BONUS := 1.8
const REPEAT_PENALTY := 0.25


## Tier de progressão (0 início, 1 meio, 2 fim de run). Catálogo pode fixar "tier".
static func weapon_tier(weapon_id: StringName) -> int:
	var data := WeaponCatalog.get_definition(weapon_id)
	if data.has("tier"):
		return clampi(int(data.tier), 0, 2)
	return clampi(RarityTable.index(StringName(data.get("rarity", &"common"))), 0, 2)


static func stage_tier(stage_index: int) -> int:
	return 0 if stage_index <= 0 else (1 if stage_index <= 2 else 2)


static func weight(weapon_id: StringName, biome_kind: StringName, stage_index: int, history: Array = []) -> float:
	if not WeaponCatalog.has_weapon(weapon_id):
		return 0.0
	var category := WeaponCatalog.category(weapon_id)
	var value := float((BIOME_AFFINITY.get(biome_kind, {}) as Dictionary).get(category, 1.0))
	var homes: Array = WeaponCatalog.get_definition(weapon_id).get("biomes", []) as Array
	if homes.has(biome_kind) or homes.has(String(biome_kind)):
		value *= HOME_BIOME_BONUS
	var gap := weapon_tier(weapon_id) - stage_tier(stage_index)
	if gap == 1:
		value *= 0.35
	elif gap >= 2:
		value *= 0.08
	elif gap <= -2:
		value *= 0.7
	if history.has(weapon_id):
		value *= REPEAT_PENALTY
	return value


## Pesos normalizados (0..1) — usados pelo Modo Dev e pelos testes de distribuição.
static func distribution(pool: Array, biome_kind: StringName, stage_index: int, history: Array = []) -> Dictionary:
	var result := {}
	var total := 0.0
	for value: Variant in pool:
		var id := StringName(value)
		var w := weight(id, biome_kind, stage_index, history)
		if w > 0.0:
			result[id] = w
			total += w
	for id: Variant in result:
		result[id] = float(result[id]) / total
	return result


## Sequência de ofertas do estágio: sorteio ponderado sem reposição (sem duplicatas no
## mesmo bioma enquanto houver armas elegíveis), depois recomeça se o pool for pequeno.
static func stage_sequence(run_seed: int, stage_index: int, biome_kind: StringName, pool: Array, history: Array, length: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var eligible: Array[StringName] = []
	for value: Variant in pool:
		var id := StringName(value)
		if WeaponCatalog.has_weapon(id) and id != &"scrap_blade" and not eligible.has(id):
			eligible.append(id)
	if eligible.is_empty():
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("weapon_offers:%d:%d:%s" % [run_seed, stage_index, String(biome_kind)])
	var remaining: Array[StringName] = eligible.duplicate()
	while result.size() < length:
		if remaining.is_empty():
			remaining = eligible.duplicate()
		var total := 0.0
		var weights: Array[float] = []
		for id in remaining:
			var w := maxf(weight(id, biome_kind, stage_index, history), 0.0001)
			weights.append(w)
			total += w
		var pick := rng.randf() * total
		var chosen := remaining.size() - 1
		for i in remaining.size():
			pick -= weights[i]
			if pick <= 0.0:
				chosen = i
				break
		result.append(remaining[chosen])
		remaining.remove_at(chosen)
	return result


## A fonte entrega arma? (determinístico por semente + id do conteúdo)
static func source_rolls_weapon(source: StringName, run_seed: int, content_id: StringName) -> bool:
	var chance := float((SOURCES.get(source, {}) as Dictionary).get("chance", 0.0))
	if chance >= 1.0:
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("weapon_source:%s:%d:%s" % [String(source), run_seed, String(content_id)])
	return rng.randf() < chance


## Raridade da cópia: viés por estágio (o antigo cálculo nunca aplicava) + mínimo da fonte.
static func rarity_for(source: StringName, run_seed: int, content_id: StringName, stage_index: int) -> StringName:
	var data: Dictionary = SOURCES.get(source, {}) as Dictionary
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("weapon_rarity:%s:%d" % [String(content_id), run_seed])
	return RarityTable.roll(rng, maxi(stage_index, 0) / 2 + int(data.get("rarity_bonus", 0)), StringName(data.get("min_rarity", &"common")))


## Índice NN de um id `..._loot_NN` (0 se não houver).
static func loot_index(content_id: StringName) -> int:
	var tail := String(content_id).get_slice("_loot_", 1)
	return int(tail) if tail.is_valid_int() else 0


## Projeto do guardião: arma do pool ainda não conhecida (se houver), para a vitória.
static func boss_blueprint(run_seed: int, pool: Array, known: Array) -> StringName:
	var unknown: Array[StringName] = []
	for value: Variant in pool:
		var id := StringName(value)
		if WeaponCatalog.has_weapon(id) and id != &"scrap_blade" and not known.has(id):
			unknown.append(id)
	if unknown.is_empty():
		return &""
	unknown.sort()
	var sequence := stage_sequence(run_seed, 5, &"lab", unknown, [], 1)
	return sequence[0] if not sequence.is_empty() else &""


## Todas as armas têm caminho de obtenção (descoberta em run ou licença no terminal).
static func unreachable_weapons() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in WeaponCatalog.WEAPONS:
		var discoverable := bool((WeaponCatalog.WEAPONS[id] as Dictionary).get("discoverable", false))
		if id == &"scrap_blade" or discoverable or MetaProgression.PURCHASES.has(id):
			continue
		result.append(id)
	return result
