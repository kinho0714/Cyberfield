class_name LocalSettings
extends Node

signal settings_changed

const SETTINGS_PATH := "user://cyberfield_settings.cfg"
const CAMERA_ZOOM_VALUES := {
	&"close": 1.18,
	&"default": 1.05,
	&"distant": 0.92,
}

@export var settings_path := SETTINGS_PATH

var camera_zoom_preference: StringName = &"default"
var touch_control_scale := 1.0
var debug_hud_visible := false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	camera_zoom_preference = StringName(config.get_value("camera", "zoom", "default"))
	if not CAMERA_ZOOM_VALUES.has(camera_zoom_preference):
		camera_zoom_preference = &"default"
	touch_control_scale = clampf(float(config.get_value("mobile", "control_scale", 1.0)), 0.8, 1.5)
	debug_hud_visible = bool(config.get_value("debug", "hud_visible", false))
	settings_changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("camera", "zoom", String(camera_zoom_preference))
	config.set_value("mobile", "control_scale", touch_control_scale)
	config.set_value("debug", "hud_visible", debug_hud_visible)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save local settings: %d" % error)


func set_camera_zoom_preference(value: StringName) -> void:
	if not CAMERA_ZOOM_VALUES.has(value):
		return
	camera_zoom_preference = value
	save_settings()
	settings_changed.emit()


func get_camera_zoom_base() -> float:
	return float(CAMERA_ZOOM_VALUES.get(camera_zoom_preference, 1.05))


func set_touch_control_scale(value: float) -> void:
	touch_control_scale = clampf(value, 0.8, 1.5)
	save_settings()
	settings_changed.emit()


func set_debug_hud_visible(value: bool) -> void:
	debug_hud_visible = value
	save_settings()
	settings_changed.emit()
