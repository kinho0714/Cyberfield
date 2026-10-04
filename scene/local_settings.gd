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
var language := "pt_BR"
const LOCALIZATION = preload("res://ui/localization.gd")
const AUDIO_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Dialogue"]
var audio_volumes: Dictionary = {&"Master": 1.0, &"Music": 1.0, &"SFX": 1.0, &"Dialogue": 1.0}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	# Missing settings use defaults, including applying audio on first startup.
	config.load(settings_path)
	camera_zoom_preference = StringName(config.get_value("camera", "zoom", "default"))
	if not CAMERA_ZOOM_VALUES.has(camera_zoom_preference):
		camera_zoom_preference = &"default"
	touch_control_scale = clampf(float(config.get_value("mobile", "control_scale", 1.0)), 0.8, 1.5)
	debug_hud_visible = bool(config.get_value("debug", "hud_visible", false))
	language = String(config.get_value("ui", "language", "pt_BR"))
	if language not in ["pt_BR", "en"]:
		language = "pt_BR"
	LOCALIZATION.initialize(language)
	for bus: StringName in AUDIO_BUSES:
		var saved: Variant = config.get_value("audio", String(bus), 1.0)
		var volume: float = float(saved) if saved is float or saved is int else 1.0
		audio_volumes[bus] = clampf(volume, 0.0, 1.0) if is_finite(volume) else 1.0
		_apply_audio_bus(bus)
	settings_changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	for bus: StringName in AUDIO_BUSES:
		config.set_value("audio", String(bus), audio_volumes[bus])
	config.set_value("camera", "zoom", String(camera_zoom_preference))
	config.set_value("mobile", "control_scale", touch_control_scale)
	config.set_value("debug", "hud_visible", debug_hud_visible)
	config.set_value("ui", "language", language)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save local settings: %d" % error)


func set_camera_zoom_preference(value: StringName) -> void:
	if not CAMERA_ZOOM_VALUES.has(value):
		return
	camera_zoom_preference = value
	save_settings()
	settings_changed.emit()


func set_language(value: String) -> void:
	if value not in ["pt_BR", "en"] or value == language:
		return
	language = value
	TranslationServer.set_locale(language)
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


func set_audio_volume(bus: StringName, value: float) -> void:
	if not AUDIO_BUSES.has(bus) or not is_finite(value):
		return
	audio_volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_audio_bus(bus)
	save_settings()
	settings_changed.emit()


func get_audio_volume(bus: StringName) -> float:
	return float(audio_volumes.get(bus, 1.0))


func _apply_audio_bus(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")
	var volume: float = get_audio_volume(bus)
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
