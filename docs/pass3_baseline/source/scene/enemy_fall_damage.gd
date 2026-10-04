class_name EnemyFallDamage
extends RefCounted

const SAFE_DISTANCE := 150.0
const LETHAL_DISTANCE := 760.0


static func calculate(fall_distance: float, maximum_health: int, resistance: float = 1.0) -> int:
	if fall_distance <= SAFE_DISTANCE:
		return 0
	var effective_distance := SAFE_DISTANCE + (fall_distance - SAFE_DISTANCE) / maxf(resistance, 0.1)
	var severity := clampf((effective_distance - SAFE_DISTANCE) / (LETHAL_DISTANCE - SAFE_DISTANCE), 0.0, 1.0)
	if severity >= 1.0:
		return maxi(maximum_health, 1)
	return maxi(1, ceili(maximum_health * lerpf(0.20, 0.95, severity)))
