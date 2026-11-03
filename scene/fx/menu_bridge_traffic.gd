extends Node2D
## Main menu: light traffic on the elevated bridge of the painted master (Alpha 0.5.0).
## Lives inside AnimatedMenuBackground/Composition, so it shares the cover transform and
## the parallax drift; coordinates are master pixels (1664x936). One node, a handful of
## draw_rect calls per frame, no textures or shaders (the menu is the FPS-sensitive screen
## on Android). VisualQuality: MINIMAL = off, REDUCED = half the cars.

const DECK_LEFT := Vector2(826.0, 711.0)    # where the deck leaves the buildings
const DECK_RIGHT := Vector2(1664.0, 737.0)  # right edge of the master
const HEAD := Color(1.0, 0.93, 0.78)
const TAIL := Color(1.0, 0.18, 0.28)
const BODY := Color(0.10, 0.09, 0.16)
const ROOF := Color(0.35, 0.85, 1.0)
# Lane: [offset above deck, direction, speed px/s, car count, scale, brightness]
const LANES := [[3.0, 1.0, 62.0, 4, 1.3, 1.0], [6.0, -1.0, 44.0, 3, 1.0, 0.8]]

var _cars: Array[Dictionary] = []


func _ready() -> void:
	name = "BridgeTraffic"
	var profile := VisualQuality.profile()
	visible = profile != VisualQuality.MINIMAL
	set_process(visible)
	var span := DECK_RIGHT.x - DECK_LEFT.x
	for lane: Array in LANES:
		var count := int(lane[3]) if profile == VisualQuality.FULL else maxi(1, int(lane[3]) / 2)
		for index in count:
			# Evenly staggered, with a fixed jitter so the lanes never move in lockstep.
			var progress := fposmod((float(index) + 0.37 * float(lane[1])) / float(count), 1.0)
			_cars.append({"lane": lane, "x": DECK_LEFT.x + span * progress,
				"length": 12.0 + float((index * 5) % 7), "speed": float(lane[2]) * (0.85 + 0.1 * float(index % 3))})


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var span := DECK_RIGHT.x - DECK_LEFT.x
	for car in _cars:
		var lane: Array = car.lane
		car.x = DECK_LEFT.x + fposmod(float(car.x) - DECK_LEFT.x + float(lane[1]) * float(car.speed) * delta, span)
	queue_redraw()


func _draw() -> void:
	for car in _cars:
		var lane: Array = car.lane
		var direction := float(lane[1])
		var scale_factor := float(lane[4])
		var length := float(car.length) * scale_factor
		var x := float(car.x)
		var t := (x - DECK_LEFT.x) / (DECK_RIGHT.x - DECK_LEFT.x)
		var y := lerpf(DECK_LEFT.y, DECK_RIGHT.y, t) - float(lane[0])
		# Fade in/out at both ends of the visible deck.
		var edge := clampf(minf(x - DECK_LEFT.x, DECK_RIGHT.x - x) / 40.0, 0.0, 1.0)
		var light := float(lane[5]) * edge
		var height := 3.0 * scale_factor
		var body := Rect2(x - length * 0.5, y - height, length, height)
		draw_rect(body, Color(BODY, 0.9 * edge))
		draw_rect(Rect2(body.position.x + length * 0.2, y - height - 1.5 * scale_factor, length * 0.55, 1.5 * scale_factor), Color(BODY, 0.9 * edge))
		draw_rect(Rect2(body.position.x + length * 0.25, y - height - 2.0 * scale_factor, length * 0.45, 0.8), Color(ROOF, 0.55 * light))
		var front := body.end.x - 3.0 if direction > 0.0 else body.position.x
		var back := body.position.x if direction > 0.0 else body.end.x - 3.0
		for spot: Array in [[front, HEAD], [back, TAIL]]:
			var at := float(spot[0])
			draw_rect(Rect2(at - 2.0, y - height - 1.5, 7.0, 5.0), Color(spot[1], 0.18 * light))
			draw_rect(Rect2(at, y - height + 0.5, 3.0, 2.0), Color(spot[1], light))
		# Headlight throw on the deck ahead of the car.
		var beam_x := body.end.x if direction > 0.0 else body.position.x - 14.0 * scale_factor
		draw_rect(Rect2(beam_x, y - 1.5, 14.0 * scale_factor, 1.5), Color(HEAD, 0.3 * light))
