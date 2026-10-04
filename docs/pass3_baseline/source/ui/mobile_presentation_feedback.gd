extends Node
## One cheap visual observer; never reads/writes InputMap or consumes an event.
var _last: Dictionary = {}


func _process(_delta: float) -> void:
	var controls: CanvasLayer = get_parent() as CanvasLayer
	if not controls.visible:
		return
	var buttons: Array = controls.get("action_buttons")
	for button: Node in buttons:
		var held: bool = button.active_touch_index >= 0
		if _last.get(button, null) == held:
			continue
		_last[button] = held
		var visual := button.get_node_or_null("Visual") as Sprite2D
		var icon := button.get_node_or_null("Icon") as Sprite2D
		if visual != null:
			visual.modulate = Color(1.5, 1.5, 1.5) if held else Color.WHITE
		if icon != null:
			icon.modulate = Color(0.55, 1.0, 1.0) if held else Color.WHITE
