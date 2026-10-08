extends SceneTree

## Headless contract test for the integrated temporary arsenal and menu controls.
## The phone, physical controllers and real speakers still need manual playtesting.
const PLAYER_SCENE := preload("res://entities/player.tscn")
const MAIN_SCENE := preload("res://scene/main.tscn")
const META_SCRIPT := preload("res://scene/meta_progression.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for weapon_id in [&"scrap_blade", &"breaker_maul", &"arc_saber", &"arc_emitter", &"pulse_carbine"]:
		assert(WeaponCatalog.WEAPONS.has(weapon_id))
		var texture := WeaponCatalog.get_visual_texture(weapon_id, "inventory_icon")
		assert(texture != null and texture.get_width() > 0 and texture.get_height() > 0)
	assert(not WeaponCatalog.is_ranged(&"arc_saber"))
	assert(WeaponCatalog.is_ranged(&"arc_emitter"))

	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	assert(player.owned_weapons == [&"scrap_blade"])
	assert(player.equip_weapon(&"arc_saber"))
	assert(player.equip_weapon(&"arc_emitter"))
	assert(player.owned_weapons.has(&"arc_saber"))
	assert(player.owned_weapons.has(&"arc_emitter"))
	assert(player.equip_owned_weapon(&"arc_saber", 0))
	assert(player.equipped_weapons[0] == &"arc_saber")
	assert(player.unequip_weapon(0))
	assert(player.active_weapon_slot == 1)
	assert(player.equip_owned_weapon(&"arc_emitter", 0))
	assert(player.equipped_weapons[0] == &"arc_emitter")
	assert(player.equipped_weapons[1].is_empty())
	var ammo: Dictionary = player.weapon_ammo[&"arc_emitter"]
	assert(int(ammo.clip) == 8 and int(ammo.reserve) == 40)
	assert(player.get_network_state().has("weapon_ammo"))
	assert(player.get_network_state().has("owned_weapons"))

	player._fire_ranged_weapon(0, WeaponCatalog.get_definition(&"arc_emitter"))
	assert(int(player.weapon_ammo[&"arc_emitter"].clip) == 7)
	assert(get_nodes_in_group(&"enemy_projectile").size() >= 1)
	assert(player.reload_weapon(0))
	assert(not player.reload_weapon(0))
	player._finish_weapon_reload(&"arc_emitter")
	assert(int(player.weapon_ammo[&"arc_emitter"].clip) == 8)
	assert(int(player.weapon_ammo[&"arc_emitter"].reserve) == 39)
	assert(not player.reload_weapon(0))
	player.reset_for_new_run()
	assert(player.owned_weapons == [&"scrap_blade"])
	assert(player.weapon_ammo.is_empty())
	player.free()

	var meta := META_SCRIPT.new()
	meta.save_path = "user://mega_pass_arsenal_%d.json" % Time.get_ticks_usec()
	root.add_child(meta)
	meta.credits = 600
	assert(meta.purchase(&"arc_saber"))
	assert(meta.purchase(&"pulse_carbine"))
	assert(meta.get_run_weapon_pool().has(&"arc_saber"))
	assert(meta.get_run_weapon_pool().has(&"pulse_carbine"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(meta.save_path))
	meta.free()

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var inventory := game.get_node("InventoryUI")
	var lab := game.get_node("MetaLabUI")
	var attribute := game.get_node("AttributeChoiceUI")
	var map := game.get_node("FullMapLayer/FullMap")
	var audio := game.get_node("AudioService")
	assert(inventory._armory_list != null and inventory._equip_slot_buttons.size() == 2)
	assert(inventory._reload_button != null and inventory._unequip_button != null)
	assert(lab._blueprint_heading != null and lab.purchase_buttons.has(&"pulse_carbine"))
	assert(attribute.buttons.size() == 3)
	assert(map._destination_frame != null)
	for id in [&"player_jump", &"enemy_death", &"weapon_fire_small", &"weapon_fire_large", &"weapon_reload", &"loot_open", &"teleport", &"ui_confirm"]:
		assert(audio.event_streams.has(id))
	assert(audio.play_event(&"weapon_reload"))
	assert(not audio.play_event(&"weapon_reload")) # Event-rate limiter.
	game.free()
	await process_frame
	print("MEGA_PASS_ARSENAL_SFX_UI_SMOKE_TEST_OK")
	quit(0)
