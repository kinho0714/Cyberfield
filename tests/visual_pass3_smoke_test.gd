extends SceneTree

const PRESENTATION = preload("res://ui/gameplay_hud_presentation.gd")
const SETTINGS = preload("res://scene/local_settings.gd")
const MAIN = preload("res://scene/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	assert(PRESENTATION.danger_intensity(0.51) == 0.0)
	assert(PRESENTATION.danger_intensity(0.50) > 0.0)
	assert(PRESENTATION.danger_intensity(0.50) < 0.03)
	assert(PRESENTATION.danger_intensity(0.25) > PRESENTATION.danger_intensity(0.40))
	assert(PRESENTATION.danger_intensity(0.0) <= 0.38)
	var settings := SETTINGS.new()
	settings.settings_path = "res://docs/pass3_testdata/settings.cfg"
	var config := ConfigFile.new()
	config.set_value("other", "preserve", 42)
	config.set_value("camera", "zoom", "distant")
	config.set_value("mobile", "control_scale", 1.25)
	config.set_value("audio", "Music", 0.35)
	assert(config.save(settings.settings_path) == OK)
	root.add_child(settings)
	assert(settings.language == "pt_BR")
	assert(TranslationServer.translate("COMMON") == "COMUM")
	settings.set_language("en")
	assert(TranslationServer.translate("JOGAR") == "PLAY")
	assert(TranslationServer.translate("LÂMINA DE SUCATA") == "SCRAP BLADE")
	assert(config.load(settings.settings_path) == OK)
	assert(config.get_value("other", "preserve") == 42)
	assert(config.get_value("ui", "language") == "en")
	var loaded := SETTINGS.new()
	loaded.settings_path = settings.settings_path
	root.add_child(loaded)
	assert(loaded.language == "en")
	assert(loaded.camera_zoom_preference == &"distant")
	assert(is_equal_approx(loaded.touch_control_scale, 1.25))
	assert(is_equal_approx(loaded.get_audio_volume(&"Music"), 0.35))
	loaded.set_language("pt_BR")
	settings.free()
	loaded.free()
	var game := MAIN.instantiate()
	game.get_node("LocalSettings").settings_path = "res://docs/pass3_testdata/main_settings.cfg"
	game.get_node("MetaProgression").save_path = "res://docs/pass3_testdata/meta.json"
	root.add_child(game)
	await process_frame
	await process_frame
	var local: LocalSettings = game.get_node("LocalSettings")
	local.set_language("en")
	assert(TranslationServer.translate("MOCHILA") == "BACKPACK")
	var pause := game.get_node("PauseMenu")
	pause.open_title_settings()
	assert(pause.language_option.item_count == 2)
	assert(pause.language_option.focus_mode != Control.FOCUS_NONE)
	pause._select_category(0)
	var original_emulation := Input.emulate_mouse_from_touch
	pause.language_option.show_popup()
	await process_frame
	assert(pause.language_option.get_popup().visible)
	assert(Input.emulate_mouse_from_touch)
	pause.language_option.get_popup().hide()
	await process_frame
	await process_frame
	assert(Input.emulate_mouse_from_touch == original_emulation)
	assert(pause.language_option.visible)
	pause._select_category(1)
	assert(not pause.language_option.visible)
	pause._select_category(0)
	var resume: Button = pause.main_page.get_node("Continue")
	assert(resume.get_theme_stylebox("focus") is StyleBoxEmpty)
	assert(resume.has_meta("pass3_native_selection"))
	pause._settings_back()
	game.get_node("ModeSelect")._select_mode(&"solo")
	game.get_node("ModeSelect")._select_difficulty(&"normal")
	await create_timer(1.2).timeout
	var inventory := game.get_node("InventoryUI")
	inventory.open_inventory()
	assert(inventory.overlay.visible)
	assert(inventory._tabs.size() == 4)
	assert(inventory._gadget_labels.size() == 2)
	var player: Node = inventory._local_player()
	assert(player != null)
	var hud: Control = game.get_node("RunDebugHUD").official_hud
	var original_health: int = player.health
	player.health = int(player.max_health * 0.51)
	hud.update_state(player, 0, true)
	assert(not hud._vignette.visible and not hud.is_processing())
	player.health = int(player.max_health * 0.45)
	hud.update_state(player, 0, true)
	assert(hud._vignette.visible and hud.is_processing())
	hud.update_state(player, 0, false)
	assert(not hud._vignette.visible and not hud.is_processing())
	player.health = original_health
	var original_slot: int = player.active_weapon_slot
	game.get_node("RunManager").dirty_money = 73
	inventory._show_inventory_tab(3)
	await process_frame
	await process_frame
	assert(inventory._inventory_frame.get_global_rect().end.y <= 720)
	assert(inventory._summary.text.contains("73"))
	assert(inventory._summary.text.contains("No carried items."))
	assert(player.active_weapon_slot == original_slot)
	local.set_language("pt_BR")
	assert(inventory._summary.text.contains("Nenhum item carregado."))
	assert(inventory._selected_tab == 3)
	inventory._show_inventory_tab(0)
	assert(inventory._details.text.contains("COMUM"))
	var run := game.get_node("RunManager")
	var supplied: Array[Dictionary] = [{"id": &"test_only_fixture", "quantity": 2}]
	inventory._backpack.replace_participant_cargo(player.participant_id, supplied)
	supplied[0].quantity = 99
	var cargo: Dictionary = inventory._backpack.snapshot(player.participant_id)
	assert(cargo.items[0].quantity == 2)
	cargo.items[0].quantity = 77
	assert(inventory._backpack.snapshot(player.participant_id).items[0].quantity == 2)
	run.state_changed.emit() # Hub resets operation-only cargo.
	assert(inventory._backpack.snapshot(player.participant_id).items.is_empty())
	var ranged := preload("res://entities/RangedEnemy.tscn").instantiate()
	game.current_room.add_child(ranged)
	ranged.set_physics_process(false)
	ranged.player = player
	ranged.global_position = player.global_position - Vector2(100, 0)
	var muzzle: Node2D = ranged.muzzle
	var target_offset: Vector2 = player.global_position - muzzle.global_position
	ranged._update_aim_line(target_offset.normalized())
	var aim: Line2D = ranged.get_node("AimLine")
	assert(is_equal_approx(aim.points[0].distance_to(aim.points[1]), target_offset.length()))
	assert(ranged.maximum_attack_range == 480.0)
	ranged.queue_free()
	inventory.close_inventory()
	assert(not paused)
	game.queue_free()
	await process_frame
	print("VISUAL_PASS3_SMOKE_TEST_OK")
	quit(0)
