extends SceneTree
## Run separately with Godot --headless --path . --script res://tests/menu_pass6_audio_smoke_test.gd

const SETTINGS_SCRIPT = preload("res://scene/local_settings.gd")
const TEST_PATH := "user://pass6_audio_test.cfg"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	var settings: LocalSettings = SETTINGS_SCRIPT.new()
	settings.settings_path = TEST_PATH
	root.add_child(settings)
	for bus: StringName in LocalSettings.AUDIO_BUSES:
		assert(is_equal_approx(settings.get_audio_volume(bus), 1.0))
		assert(AudioServer.get_bus_index(bus) >= 0)
	var bus_count: int = AudioServer.bus_count
	settings.set_camera_zoom_preference(&"distant")
	settings.set_touch_control_scale(1.2)
	settings.set_audio_volume(&"Master", 0.5)
	settings.set_audio_volume(&"Music", 0.0)
	settings.set_audio_volume(&"Ambience", 0.65)
	settings.set_audio_volume(&"SFX", 0.25)
	settings.set_audio_volume(&"Dialogue", 1.0)
	var second: LocalSettings = SETTINGS_SCRIPT.new()
	second.settings_path = TEST_PATH
	root.add_child(second)
	assert(AudioServer.bus_count == bus_count)
	assert(second.camera_zoom_preference == &"distant")
	assert(is_equal_approx(second.touch_control_scale, 1.2))
	for index in LocalSettings.AUDIO_BUSES.size():
		var bus: StringName = LocalSettings.AUDIO_BUSES[index]
		var expected: float = [0.5, 0.0, 0.65, 0.25, 1.0][index]
		var bus_index: int = AudioServer.get_bus_index(bus)
		assert(is_equal_approx(second.get_audio_volume(bus), expected))
		assert(AudioServer.is_bus_mute(bus_index) == (expected == 0.0))
		if expected > 0.0:
			assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), expected))
		if bus != &"Master":
			assert(AudioServer.get_bus_send(bus_index) == &"Master")
	settings.free()
	second.free()
	DirAccess.remove_absolute(TEST_PATH)
	print("PASS6_AUDIO_SMOKE_TEST_PASSED")
	quit(0)
