class_name CombatStats
extends RefCounted

const PLAYER_BASE_MAX_HP := 1000
const PLAYER_BASE_MELEE_DAMAGE := 40
const PLAYER_BASE_SLAM_DAMAGE := 80
const PLAYER_HEAL_RATIO := 0.25

const COMMON_ENEMY_BASE_HP := 240
const RANGED_ENEMY_BASE_HP := 200
const BOSS_BASE_HP := 1800
const COMMON_ENEMY_BASE_DAMAGE := 50
const RANGED_MELEE_BASE_DAMAGE := 50
const RANGED_PROJECTILE_BASE_DAMAGE := 100

const HEALTH_FIRST_LEVEL_BONUS := 0.20
const HEALTH_DIMINISHING_STEP := 0.18
const STRENGTH_DAMAGE_PER_LEVEL := 0.16

const DIFFICULTY_HP_MULTIPLIERS := {
	&"normal": 1.0,
	&"hard": 1.43,
	&"pro": 2.14,
	&"inferno_pro": 2.86,
}
const DIFFICULTY_DAMAGE_MULTIPLIERS := {
	&"normal": 1.0,
	&"hard": 1.15,
	&"pro": 1.30,
	&"inferno_pro": 1.50,
}


static func player_max_hp(health_level: int) -> int:
	var accumulated_bonus := 0.0
	for level_index in maxi(health_level, 0):
		accumulated_bonus += HEALTH_FIRST_LEVEL_BONUS / (1.0 + HEALTH_DIMINISHING_STEP * float(level_index))
	return maxi(1, roundi(PLAYER_BASE_MAX_HP * (1.0 + accumulated_bonus)))


static func player_melee_damage(strength_level: int) -> int:
	return maxi(1, roundi(PLAYER_BASE_MELEE_DAMAGE * (1.0 + STRENGTH_DAMAGE_PER_LEVEL * maxi(strength_level, 0))))


static func player_slam_damage(strength_level: int) -> int:
	return maxi(1, roundi(PLAYER_BASE_SLAM_DAMAGE * (1.0 + STRENGTH_DAMAGE_PER_LEVEL * maxi(strength_level, 0))))


static func heal_amount(max_hp: int) -> int:
	return maxi(1, roundi(max_hp * PLAYER_HEAL_RATIO))


static func difficulty_hp_multiplier(difficulty: StringName) -> float:
	return float(DIFFICULTY_HP_MULTIPLIERS.get(difficulty, 1.0))


static func difficulty_damage_multiplier(difficulty: StringName) -> float:
	return float(DIFFICULTY_DAMAGE_MULTIPLIERS.get(difficulty, 1.0))


static func scaled_health(base_hp: int, difficulty: StringName, elite_multiplier: float = 1.0) -> int:
	return maxi(1, roundi(base_hp * difficulty_hp_multiplier(difficulty) * elite_multiplier))


static func scaled_damage(base_damage: int, difficulty: StringName) -> int:
	return maxi(1, roundi(base_damage * difficulty_damage_multiplier(difficulty)))
