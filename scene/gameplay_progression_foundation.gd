class_name GameplayProgressionFoundation
extends RefCounted

const AFFINITY_PER_POINT := 0.03
const HYBRID_EQUAL_BASE := 0.04
const HYBRID_EQUAL_PER_POINT := 0.02
const HYBRID_MIXED_BONUS := 0.04
const OPERATION_ATTRIBUTE_IDS: Array[StringName] = [&"f", &"s", &"i"]

const LOADOUT_LIMITS := {
	&"melee": 1,
	&"ranged": 1,
	&"gadgets": 2,
}

const WEAPON_QUALITY_ORDER: Array[StringName] = [
	&"inferior",
	&"common",
	&"good",
	&"very_good",
	&"excellent",
	&"rare",
	&"epic",
	&"superior",
]
const MAX_NORMAL_WEAPON_BUFFS := 2
const FUTURE_SPECIAL_QUALITY: StringName = &"adaptive"

const CYBERWARE_SLOTS: Array[StringName] = [
	&"head_neural",
	&"arms",
	&"torso",
	&"legs",
]


static func affinity_bonus(points: int) -> float:
	return float(maxi(points, 0)) * AFFINITY_PER_POINT


static func hybrid_bonus(first_points: int, second_points: int) -> float:
	var first := maxi(first_points, 0)
	var second := maxi(second_points, 0)
	if first == 0 and second == 0:
		return 0.0
	if first == second and first > 0:
		return HYBRID_EQUAL_BASE + HYBRID_EQUAL_PER_POINT * float(first)
	return HYBRID_MIXED_BONUS


static func quality_index(quality: StringName) -> int:
	return WEAPON_QUALITY_ORDER.find(quality)


static func is_supported_quality(quality: StringName) -> bool:
	return WEAPON_QUALITY_ORDER.has(quality)


static func loadout_limit(category: StringName) -> int:
	return int(LOADOUT_LIMITS.get(category, 0))


static func is_supported_cyberware_slot(slot: StringName) -> bool:
	return CYBERWARE_SLOTS.has(slot)
