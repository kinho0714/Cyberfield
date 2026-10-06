extends RefCounted
## Aspect-aware WORLD framing; no viewport/UI/input mutation and no extra zoom.
const BASE_ASPECT := 16.0 / 9.0
const WIDE_ASPECT := 19.5 / 9.0
const FOOT_SCREEN_FRACTION := 0.78


static func enabled(is_android: bool, size: Vector2) -> bool:
	return is_android and size.y > 0.0 and size.x / size.y > BASE_ASPECT + 0.01


static func target_y(mean_y: float, support_y: float, size: Vector2, zoom: float) -> float:
	var strength := clampf((size.x / size.y - BASE_ASPECT) / (WIDE_ASPECT - BASE_ASPECT), 0.0, 1.0)
	var framed := support_y - (FOOT_SCREEN_FRACTION - 0.5) * size.y / zoom
	return lerpf(mean_y, framed, strength)


static func apply(target: Vector2, players: Array, size: Vector2, zoom: float, bounds: Rect2) -> Vector2:
	var support_y := target.y + 24.0
	var grounded := 0
	var support_sum := 0.0
	var lowest := -INF
	var highest := INF
	for player in players:
		lowest = maxf(lowest, player.global_position.y)
		highest = minf(highest, player.global_position.y)
		if player is CharacterBody2D and player.is_on_floor():
			for index in player.get_slide_collision_count():
				var contact: KinematicCollision2D = player.get_slide_collision(index)
				if contact.get_normal().y < -0.7:
					support_sum += contact.get_position().y
					grounded += 1
					break
	if grounded > 0:
		support_y = support_sum / float(grounded)
	var half := size * 0.5 / zoom
	target.y = target_y(target.y, support_y, size, zoom)
	# Retain vertical space for every co-op participant; if it cannot fit, keep their mean.
	if lowest - highest + 192.0 < half.y * 2.0:
		target.y = clampf(target.y, lowest - half.y + 96.0, highest + half.y - 96.0)
	else:
		target.y = (lowest + highest) * 0.5
	var lower := bounds.position + half
	var upper := bounds.end - half
	target.x = clampf(target.x, lower.x, upper.x) if lower.x <= upper.x else bounds.get_center().x
	target.y = clampf(target.y, lower.y, upper.y) if lower.y <= upper.y else bounds.get_center().y
	return target
