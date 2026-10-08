extends SceneTree

## Exercises the actual hub/inventory/attribute/map UI and records current
## render evidence. Physical touchscreen, controller and audio still need QA.
const MAIN_SCENE := preload("res://scene/main.tscn")
var output_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("UI_INTEGRATION_BEGIN")
	output_dir = OS.get_environment("CYBERFIELD_CAPTURE_DIR")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("user://mega_pass_captures")
	assert(DirAccess.make_dir_recursive_absolute(output_dir) == OK)
	root.size = Vector2i(1280, 720)
	var game := MAIN_SCENE.instantiate()
	game.get_node("LocalSettings").settings_path = "user://mega_pass_ui_settings.cfg"
	game.get_node("MetaProgression").save_path = "user://mega_pass_ui_meta.json"
	root.add_child(game)
	await game.start_configured_run(&"solo", &"normal", -1)
	print("UI_INTEGRATION_HUB_READY")
	var player: Node = game.get_players()[0]
	var inventory := game.get_node("InventoryUI")
	var lab := game.get_node("MetaLabUI")
	var attribute := game.get_node("AttributeChoiceUI")
	var map := game.get_node("FullMapLayer/FullMap")

	assert(player.equip_weapon(&"arc_emitter"))
	assert(player.equip_owned_weapon(&"arc_emitter", 1))
	assert(player.active_weapon_slot == 1)
	inventory.open_inventory()
	assert(inventory.overlay.visible)
	assert(inventory._armory_list.get_child_count() >= 2)
	await _capture("mega_pass_inventory")
	inventory._select_slot(0)
	assert(player.active_weapon_slot == 0)
	inventory._select_slot(1)
	assert(player.active_weapon_slot == 1)
	assert(inventory._reload_button.disabled == false)
	var ammo: Dictionary = player.weapon_ammo[&"arc_emitter"]
	ammo["clip"] = int(ammo["clip"]) - 1
	player.weapon_ammo[&"arc_emitter"] = ammo
	inventory._reload_active()
	assert(not inventory.overlay.visible)
	assert(player.weapon_reload_timers.has(&"arc_emitter"))
	player._finish_weapon_reload(&"arc_emitter")
	assert(int(player.weapon_ammo[&"arc_emitter"].clip) == 8)

	inventory.open_inventory()
	inventory._show_inventory_tab(3)
	await _capture("mega_pass_backpack")
	inventory.close_inventory()
	lab.open_terminal(player)
	assert(lab.overlay.visible)
	await _capture("mega_pass_workbench")
	lab.close_terminal()
	var choices: Array[StringName] = [&"intellect", &"health", &"strength"]
	assert(attribute.open_network_for(player, choices))
	await _capture("mega_pass_attributes")
	attribute.cancel_selection()

	root.size = Vector2i(960, 540)
	await process_frame
	inventory.open_inventory()
	await process_frame
	var frame: Control = inventory._inventory_frame
	print("UI_960x540 frame=", frame.size, " minimum=", frame.get_combined_minimum_size())
	await _capture("mega_pass_inventory_compact")
	inventory.close_inventory()
	root.size = Vector2i(1280, 720)
	await process_frame

	await game._begin_run_from_hub(56243)
	await _capture("mega_pass_lower_city")
	var graph: Dictionary = game.current_room.get_map_graph()
	var teleporters: Array = graph.get("teleporters", [])
	if not teleporters.is_empty():
		var first_id := StringName((teleporters[0] as Dictionary).get("teleporter_id", &""))
		map.open_map(first_id)
		if map.visible:
			await _capture("mega_pass_teleporters")
			map.close_map()
		if teleporters.size() > 1:
			# Staged availability is used only for destination-menu UI evidence.
			var second_id := StringName((teleporters[1] as Dictionary).get("teleporter_id", &""))
			var map_state: BiomeMapState = game.get_node("RunManager").get_current_map_state()
			map_state.activate_teleporter(first_id)
			map_state.activate_teleporter(second_id)
			map.open_map(first_id)
			assert(map._destination_buttons.size() >= 1)
			await _capture("mega_pass_teleporters_destinations")
			map.close_map()
	game.queue_free()
	await process_frame
	print("MEGA_PASS_UI_INTEGRATION_TEST_OK")
	quit(0)


func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	assert(not frame.is_empty())
	var file_path := "%s/%s.png" % [output_dir, label]
	assert(frame.save_png(file_path) == OK)
	print("CAPTURE_OK ", file_path, " ", frame.get_size())
