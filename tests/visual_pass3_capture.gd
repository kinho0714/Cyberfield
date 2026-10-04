extends SceneTree
## Automated render evidence; does not replace physical gameplay/mobile/LAN approval.
var game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scene/main.tscn").instantiate()
	game.get_node("LocalSettings").settings_path = "res://docs/pass3_testdata/capture_settings.cfg"
	game.get_node("MetaProgression").save_path = "res://docs/pass3_testdata/capture_meta.json"
	root.add_child(game)
	game.get_node("LocalSettings").set_language("pt_BR")
	await _capture("menu_pt")
	var pause := game.get_node("PauseMenu")
	game.get_node("ModeSelect")._open_options()
	pause.language_option.grab_focus()
	await _capture("settings_pt")
	game.get_node("LocalSettings").set_language("en")
	await _capture("settings_en")
	pause._settings_back()
	await game.start_configured_run(&"solo", &"normal", -1)
	await _capture("house")
	var inventory := game.get_node("InventoryUI")
	inventory.open_inventory()
	await _capture("equipment_en")
	inventory._show_inventory_tab(3)
	await _capture("backpack_en")
	inventory.close_inventory()
	await game._begin_run_from_hub(56243)
	await _capture("lower_city")
	game.get_players()[0].health = int(game.get_players()[0].max_health * 0.25)
	await _capture("low_hp_25")
	game.queue_free()
	await process_frame
	print("VISUAL_PASS3_CAPTURES_OK")
	quit()


func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	assert(not frame.is_empty())
	assert(frame.save_png("res://docs/pass3_captures/%s.png" % label) == OK)
