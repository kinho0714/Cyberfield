extends CanvasLayer

@onready var run_manager: Node = get_parent().get_node("RunManager")


func _ready() -> void:
	# Keep this development overlay out of desktop builds that have no touch input.
	visible = false
	run_manager.state_changed.connect(_refresh_visibility)
	_refresh_visibility()


func _refresh_visibility() -> void:
	visible = _touchscreen_is_available() and run_manager.run_active


func _touchscreen_is_available() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
