class_name TempPixelVisual
extends Node2D

@export_enum("player", "common", "ranged", "heavy", "boss") var character_kind: String = "common"
@export var source_visual_path: NodePath

var _time := 0.0


func _ready() -> void:
	z_index = 2
	var source := get_node_or_null(source_visual_path) as CanvasItem
	if source != null:
		source.visible = false
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var source := get_node_or_null(source_visual_path) as CanvasItem
	if source != null:
		modulate = source.modulate
	queue_redraw()


func set_character_kind(value: StringName) -> void:
	character_kind = String(value)
	queue_redraw()


func _draw() -> void:
	var body: Node = get_parent()
	var velocity := Vector2.ZERO
	var velocity_value: Variant = body.get("velocity") if body != null else null
	if velocity_value is Vector2:
		velocity = velocity_value
	var moving: bool = absf(velocity.x) > 12.0
	var attacking: bool = bool(body.get("is_attacking")) if body != null and body.get("is_attacking") != null else false
	var health: int = int(body.get("health")) if body != null and body.get("health") != null else 1
	var bob: float = 1.0 if moving and int(_time * 10.0) % 2 == 0 else 0.0
	if health <= 0:
		_draw_death()
		return
	match character_kind:
		"player": _draw_player(bob, attacking)
		"ranged": _draw_ranged(bob, attacking)
		"heavy": _draw_heavy(bob, attacking, false)
		"boss": _draw_heavy(bob, attacking, true)
		_: _draw_common(bob, attacking)


func _draw_player(bob: float, attacking: bool) -> void:
	var cyan := Color("38e7ff")
	var navy := Color("102b48")
	var skin := Color("d7f3f1")
	_pixel(Rect2(-8, -17 + bob, 16, 20), navy)
	_pixel(Rect2(-6, -15 + bob, 12, 7), skin)
	_pixel(Rect2(2, -13 + bob, 5, 3), cyan)
	_pixel(Rect2(-10, 3 + bob, 8, 12), Color("185f79"))
	_pixel(Rect2(2, 3 + bob, 8, 12), Color("185f79"))
	_pixel(Rect2(-12, -6 + bob, 4, 13), cyan)
	_pixel(Rect2(8, -6 + bob, 4, 13), cyan)
	if attacking:
		_pixel(Rect2(11, -5 + bob, 19, 4), Color("f5dd58"))
		_pixel(Rect2(26, -7 + bob, 4, 8), Color.WHITE)


func _draw_common(bob: float, attacking: bool) -> void:
	var red := Color("ff496c")
	var dark := Color("35152d")
	_pixel(Rect2(-11, -18 + bob, 22, 25), dark)
	_pixel(Rect2(-8, -14 + bob, 16, 8), Color("79304d"))
	_pixel(Rect2(-7, -12 + bob, 5, 3), red)
	_pixel(Rect2(3, -12 + bob, 5, 3), red)
	_pixel(Rect2(-11, 7 + bob, 8, 12), Color("66243d"))
	_pixel(Rect2(3, 7 + bob, 8, 12), Color("66243d"))
	_pixel(Rect2(-15, -5 + bob, 5, 14), red)
	if attacking:
		_pixel(Rect2(10, -2 + bob, 17, 6), Color("ff9b52"))


func _draw_ranged(bob: float, attacking: bool) -> void:
	var violet := Color("d84dff")
	var dark := Color("2c1648")
	_pixel(Rect2(-10, -18 + bob, 20, 26), dark)
	_pixel(Rect2(-7, -15 + bob, 14, 7), violet)
	_pixel(Rect2(1, -13 + bob, 6, 3), Color("ffd3ff"))
	_pixel(Rect2(-9, 8 + bob, 7, 11), Color("5d287e"))
	_pixel(Rect2(2, 8 + bob, 7, 11), Color("5d287e"))
	_pixel(Rect2(7, -4 + bob, 23, 7), Color("8c3fb4"))
	_pixel(Rect2(27, -2 + bob, 5, 3), Color("ff78dc") if attacking else violet)


func _draw_heavy(bob: float, attacking: bool, boss: bool) -> void:
	var armor := Color("e37b38") if not boss else Color("ff315c")
	var core := Color("ffd35a") if not boss else Color("ffb0c1")
	var width := 40.0 if boss else 34.0
	var height := 43.0 if boss else 37.0
	_pixel(Rect2(-width * 0.5, -height * 0.55 + bob, width, height), Color("301c2b"))
	_pixel(Rect2(-width * 0.38, -height * 0.42 + bob, width * 0.76, 12), armor)
	_pixel(Rect2(-7, -height * 0.34 + bob, 14, 5), core)
	_pixel(Rect2(-width * 0.56, -8 + bob, 8, 24), armor)
	_pixel(Rect2(width * 0.34, -8 + bob, 8, 24), armor)
	_pixel(Rect2(-width * 0.36, height * 0.45 + bob, 11, 13), Color("71362f"))
	_pixel(Rect2(width * 0.36 - 11, height * 0.45 + bob, 11, 13), Color("71362f"))
	if attacking:
		_pixel(Rect2(width * 0.48, -3 + bob, 20, 9), core)


func _draw_death() -> void:
	_pixel(Rect2(-16, 10, 32, 6), Color("4a3950"))
	_pixel(Rect2(-8, 4, 17, 5), Color("8c607d"))


func _pixel(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color, true)
