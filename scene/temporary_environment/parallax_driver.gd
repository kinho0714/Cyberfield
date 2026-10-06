extends Node2D
## One coordinator per loaded environment; zero per-sprite processing.
## Continuous FAR/MID layers are redrawn only when camera framing changes.
const PROFILES = preload("res://scene/temporary_environment/parallax_profiles.gd")
const PAINTER = preload("res://scene/temporary_environment/painter.gd")
const ENVIRONMENT_CYCLE = preload("res://scene/temporary_environment/environment_cycle.gd")

var profile_id := "city"
var room_bounds := Rect2()
var _views: Array[Node2D] = []
var _last_camera := Vector2(INF, INF)
var _last_size := Vector2.ZERO
var _last_zoom := Vector2.ZERO
var _background_origin := Vector2(INF, INF)
var _background_window := Rect2()
var _background_far_offset := Vector2.ZERO
var _background_mid_offset := Vector2.ZERO
var _environment_snapshot: Dictionary = {}
var _last_environment_bucket := -1


func _ready() -> void:
	z_index = -30
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_meta("temp_environment_bounds", room_bounds)
	for candidate in get_tree().get_nodes_in_group("temporary_environment_view"):
		if get_parent().is_ancestor_of(candidate):
			_views.append(candidate as Node2D)
	_refresh_environment_snapshot(true)


func _draw() -> void:
	if _background_window.has_area():
		PAINTER.paint_background(self, profile_id, _background_window, _background_far_offset, _background_mid_offset)


func _process(_delta: float) -> void:
	var environment_changed := _refresh_environment_snapshot(false)
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center := camera.get_screen_center_position().round()
	var size := get_viewport_rect().size
	if center == _last_camera and size == _last_size and camera.zoom == _last_zoom and not environment_changed:
		return
	_last_camera = center
	_last_size = size
	_last_zoom = camera.zoom
	if is_inf(_background_origin.x):
		_background_origin = center

	var profile: Dictionary = PROFILES.PROFILES.get(profile_id, PROFILES.PROFILES.city)
	var movement := center - _background_origin
	var next_far_offset := movement * (1.0 - float(profile.far_speed))
	var next_mid_offset := movement * (1.0 - float(profile.mid_speed))
	var half := size * 0.5 / camera.zoom
	var visible_area := Rect2(center - half, half * 2.0).grow(128.0)
	# The camera may show headroom above the generated bounds (especially on
	# Android). Clipping this layer to the room leaves an unpainted sky strip.
	var next_window := visible_area

	var background_changed := next_window != _background_window \
		or next_far_offset != _background_far_offset \
		or next_mid_offset != _background_mid_offset
	_background_window = next_window
	_background_far_offset = next_far_offset
	_background_mid_offset = next_mid_offset
	if background_changed or environment_changed:
		queue_redraw()

	for view in _views:
		if not is_instance_valid(view):
			continue
		view.set_meta("temp_environment_snapshot", _environment_snapshot)
		var anchor := view.global_position + Vector2(420, 240)
		if profile_id == "house":
			anchor = get_parent().global_position + room_bounds.get_center()
		var local_delta := center - anchor
		var far_limit := float(profile.far_limit)
		var mid_limit := float(profile.mid_limit)
		view.set_meta("temp_far_offset", (local_delta * (1.0 - float(profile.far_speed))).clamp(
			Vector2.ONE * -far_limit, Vector2.ONE * far_limit).round())
		view.set_meta("temp_mid_offset", (local_delta * (1.0 - float(profile.mid_speed))).clamp(
			Vector2.ONE * -mid_limit, Vector2.ONE * mid_limit).round())
		var extent := room_bounds.size if profile_id == "house" else Vector2(840, 480)
		if visible_area.intersects(Rect2(view.global_position, extent)) and (background_changed or environment_changed or center != _last_camera):
			view.queue_redraw()


func _refresh_environment_snapshot(force: bool) -> bool:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var elapsed := 0.0
	var stage := 0
	if run_manager != null:
		elapsed = float(run_manager.get("run_elapsed_time"))
		stage = int(run_manager.get("stage_index"))
	var bucket := floori(elapsed * 2.0) + stage * 100000
	if not force and bucket == _last_environment_bucket:
		return false
	_last_environment_bucket = bucket
	_environment_snapshot = ENVIRONMENT_CYCLE.snapshot(elapsed, stage)
	set_meta("temp_environment_snapshot", _environment_snapshot)
	for view in _views:
		if is_instance_valid(view):
			view.set_meta("temp_environment_snapshot", _environment_snapshot)
	return true
