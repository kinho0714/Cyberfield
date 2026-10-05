extends Node2D
## One coordinator per loaded environment; zero per-sprite processing.
## Finite recessed layers: bounded camera compensation, no unbounded PNG scrolling.
const PROFILES = preload("res://scene/temporary_environment/parallax_profiles.gd")
var profile_id := "city"
var room_bounds := Rect2()
var _views: Array[Node2D] = []
var _last_camera := Vector2(INF, INF)
var _last_size := Vector2.ZERO
var _last_zoom := Vector2.ZERO


func _ready() -> void:
	z_index = -30
	for candidate in get_tree().get_nodes_in_group("temporary_environment_view"):
		if get_parent().is_ancestor_of(candidate):
			_views.append(candidate as Node2D)
	# Geometry and the world's transform never change.
	queue_redraw()


func _draw() -> void:
	if room_bounds.has_area():
		draw_rect(room_bounds, Color("13232e"))


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center := camera.get_screen_center_position().round()
	var size := get_viewport_rect().size
	if center == _last_camera and size == _last_size and camera.zoom == _last_zoom:
		return
	_last_camera = center
	_last_size = size
	_last_zoom = camera.zoom
	var half := size * 0.5 / camera.zoom
	var visible_area := Rect2(center - half, half * 2.0).grow(48.0)
	for view in _views:
		if not is_instance_valid(view):
			continue
		var profile: Dictionary = PROFILES.PROFILES.get(profile_id, PROFILES.PROFILES.city)
		var anchor := view.global_position + Vector2(420, 240)
		if profile_id == "house":
			anchor = get_parent().global_position + room_bounds.get_center()
		var delta := center - anchor
		var far_limit := float(profile.far_limit)
		var mid_limit := float(profile.mid_limit)
		view.set_meta("temp_far_offset", (delta * (1.0 - float(profile.far_speed))).clamp(Vector2.ONE * -far_limit, Vector2.ONE * far_limit).round())
		view.set_meta("temp_mid_offset", (delta * (1.0 - float(profile.mid_speed))).clamp(Vector2.ONE * -mid_limit, Vector2.ONE * mid_limit).round())
		var extent := room_bounds.size if profile_id == "house" else Vector2(840, 480)
		if visible_area.intersects(Rect2(view.global_position, extent)):
			view.queue_redraw()
