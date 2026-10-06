extends Node2D
## Legacy lab: replaces pure visual groups; reads existing collision shapes only.
const PAINTER = preload("res://scene/temporary_environment/painter.gd")


func _draw() -> void:
	PAINTER.paint(self, "legacy_lab")
	var geometry := get_parent().get_node_or_null("Geometry")
	if geometry == null:
		return
	for body in geometry.get_children():
		if body is StaticBody2D:
			for child in body.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D:
					var size: Vector2 = child.shape.size
					PAINTER.surface(self, Rect2(body.position + child.position - size * 0.5, size),
						"wall" if size.y > size.x else "floor", "lab")
