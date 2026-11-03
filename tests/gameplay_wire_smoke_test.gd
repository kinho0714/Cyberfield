extends SceneTree
const WIRE := preload("res://scene/network/gameplay_wire.gd")
var failures := 0
func _initialize() -> void:
	var source: Dictionary = {"position": Vector2(3, 4), "aim": PackedVector2Array([Vector2(0, 1), Vector2(2, 3)]), "empty_aim": PackedVector2Array(), "nested": [{"direction": Vector2.LEFT}], "id": &"fixture"}
	var encoded: Variant = JSON.parse_string(JSON.stringify(WIRE.encode(source)))
	var decoded: Dictionary = WIRE.decode(encoded)
	if decoded.position != source.position or decoded.aim != source.aim or decoded.empty_aim != source.empty_aim or decoded.nested[0].direction != Vector2.LEFT:
		failures += 1
		push_error("wire typed-vector roundtrip")
	if WIRE.decode({"_pv2": ["invalid"]}) != PackedVector2Array():
		failures += 1
	print("GAMEPLAY_WIRE_REPORT failures=", failures)
	quit(failures)
