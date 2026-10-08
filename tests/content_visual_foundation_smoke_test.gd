extends SceneTree

const FIXTURE = "res://tests/fixtures/content_visual_profile.tres"
const LEGACY = preload("res://assets/ui/gameplay_hud/assets/shared/hud/hp_fill.png")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: Resource = ContentRegistry.DATA
	assert(ContentRegistry.biome_id(&"lower_city") == &"biome_01")
	assert(ContentRegistry.biome(&"missing").id == "biome_01")
	assert(ContentRegistry.DATA.biomes.size() == 6)
	var id_pattern := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	var ids := {}
	for biome_key in ContentRegistry.DATA.biomes:
		var entry := ContentRegistry.biome(StringName(biome_key))
		assert(entry.id == biome_key and entry.display_name_key != entry.id)
		assert(id_pattern.search(entry.id) != null)
		for kind in [&"common", &"ranged", &"heavy"]:
			var variant := ContentRegistry.enemy_variant(StringName(biome_key), kind)
			assert(variant.biome_id == biome_key)
			assert(variant.archetype == String(ContentRegistry.archetype(kind)))
			assert(not ids.has(variant.id))
			assert(id_pattern.search(variant.id) != null and variant.display_name_key != variant.id)
			ids[variant.id] = true
			assert(ContentRegistry.enemy_variant(StringName(biome_key), kind, &"missing") == variant)
			assert(ContentRegistry.entry_profile(variant) == null)
	assert(ids.size() == 18)
	assert(ContentRegistry.enemy_variant(&"biome_02", &"ranged", &"enemy_b01_melee_01").id == "enemy_b02_ranged_01")
	assert(ContentRegistry.enemy_variant(&"lower_city", &"common").id == "enemy_b01_melee_01")
	var copy := ContentRegistry.biome(&"biome_01")
	copy.enemy_roster.melee = "changed"
	assert(ContentRegistry.biome(&"biome_01").enemy_roster.melee == "enemy_b01_melee_01")
	assert(ContentRegistry.texture(copy, "missing", LEGACY) == LEGACY)
	assert(ContentRegistry.hub_stage(&"missing").id == "hub_stage_00")
	assert(ContentRegistry.character(&"jhon").id == "player_jhon")
	assert(WeaponCatalog.get_visual_texture(&"scrap_blade", "world", LEGACY) == LEGACY)
	assert(WeaponCatalog.get_visual_texture(&"missing", "world", LEGACY) == LEGACY)
	var profile := load(FIXTURE) as ContentVisualProfile
	assert(profile.texture("missing", LEGACY) == LEGACY)
	assert(profile.texture("wrong_type", LEGACY) == LEGACY)
	assert(profile.alignment(&"idle", Vector2.ZERO) == Vector2(3, 4))
	var empty := ContentVisualProfile.new()
	var frames := SpriteFrames.new()
	assert(empty.merge_frames(frames) == frames)
	# One real profile adopted, absent/broken/mismatched animations preserved.
	catalog.visual_profiles["enemy_b01_melee_01"] = FIXTURE
	catalog.visual_profiles["scrap_blade"] = FIXTURE
	catalog.visual_profiles["hub_stage_00"] = FIXTURE
	for id in ["enemy_b01_melee_01", "scrap_blade", "hub_stage_00"]:
		ContentRegistry._profiles.erase(StringName(id))
	var enemy := load("res://entities/Enemy.tscn").instantiate() as Node2D
	root.add_child(enemy)
	var visual := enemy.get_node("EnemyCharacterVisual") as EnemyCharacterVisual
	assert(visual.sprite_frames.get_frame_texture(&"idle", 0).resource_path.ends_with("heal_icon.png"))
	assert(is_equal_approx(visual.sprite_frames.get_animation_speed(&"idle"), 4.0))
	assert(visual.sprite_frames.get_animation_loop(&"idle"))
	assert(visual.sprite_frames.get_frame_count(&"air") == 4)
	assert(visual.sprite_frames.get_frame_texture(&"hurt", 0) != null)
	assert(visual.sprite_frames.has_animation(&"walk"))
	var merged := profile.merge_frames(visual.sprite_frames)
	assert(merged != visual.sprite_frames)
	assert(ContentRegistry.atlas_texture(ContentRegistry.hub_stage(&"hub_stage_00"), "world", LEGACY) == LEGACY)
	assert(ContentRegistry.texture(ContentRegistry.hub_stage(&"hub_stage_03"), "world", LEGACY) != LEGACY)
	var pickup := WeaponPickup.new()
	pickup.weapon_id = &"scrap_blade"
	var world := pickup._build_temporary_weapon_visual()
	assert(world is Sprite2D and world.offset == Vector2(2, 5))
	world.free()
	pickup.free()
	assert(WeaponCatalog.WEAPONS[&"scrap_blade"].damage == 40)
	assert(ContentRegistry.DATA.biomes["biome_01"].definition_path.ends_with("lower_city.tres"))
	enemy.free()
	var boss := load("res://entities/Enemy.tscn").instantiate() as Node2D
	boss.enemy_role = 1
	root.add_child(boss)
	var boss_skin := boss.get_node("EnemyCharacterVisual") as EnemyCharacterVisual
	# The existing boss must not acquire the biome melee identity implicitly.
	assert(boss_skin.sprite_frames.get_frame_texture(&"idle", 0) is AtlasTexture)
	boss.free()
	catalog.visual_profiles["player_jhon"] = FIXTURE
	catalog.visual_profiles["ui_default"] = FIXTURE
	ContentRegistry._profiles.erase(&"player_jhon")
	ContentRegistry._profiles.erase(&"ui_default")
	var player := load("res://entities/player.tscn").instantiate() as Node2D
	root.add_child(player)
	var player_skin := player.get_node("PlayerCharacterVisual") as PlayerCharacterVisual
	assert(player_skin.sprite_frames.get_frame_count(&"idle") == 4)
	assert(player_skin.get_content_portrait(LEGACY) != LEGACY)
	player.free()
	var panel := Control.new()
	ContentRegistry.apply_ui_theme(panel)
	assert(panel.theme != null and panel.theme.default_font_size == 27)
	panel.free()
	for id in ["enemy_b01_melee_01", "scrap_blade", "hub_stage_00", "player_jhon", "ui_default"]:
		catalog.visual_profiles[id] = ""
		ContentRegistry._profiles.erase(StringName(id))
	for path in ["res://entities/Enemy.tscn", "res://entities/RangedEnemy.tscn", "res://entities/HeavyEnemy.tscn"]:
		var current := load(path).instantiate() as Node2D
		root.add_child(current)
		var skin := current.get_node("EnemyCharacterVisual") as EnemyCharacterVisual
		assert(skin.sprite_frames.get_frame_count(&"idle") == 4)
		assert(skin.sprite_frames.get_frame_texture(&"idle", 0) != null)
		current.free()
	assert(load("res://scene/biomes/lower_city/lower_city.tres").biome_id == &"lower_city")
	assert(_test_generated_context())
	print("CONTENT_VISUAL_FOUNDATION_SMOKE_TEST_OK")
	quit(0)


func _test_generated_context() -> bool:
	var manager := load("res://scene/run_manager.gd").new() as Node
	root.add_child(manager)
	manager.configure_run(&"solo", &"inferno_pro")
	manager.prepare_new_run(101)
	var legacy := load("res://scene/biomes/lower_city/lower_city_biome.tscn").instantiate() as BiomeGenerator
	assert(legacy.generate(101, manager))
	root.add_child(legacy)
	var report := legacy.get_generation_report()
	assert(report.enemy_count > 0 and report.ranged_enemy_count > 0)
	for child in legacy.get_children():
		var skin := child.get_node_or_null("EnemyCharacterVisual") as EnemyCharacterVisual
		if skin != null:
			assert(skin.content_biome_id == &"biome_01")
	var repeated := load("res://scene/biomes/lower_city/lower_city_biome.tscn").instantiate() as BiomeGenerator
	assert(repeated.generate(101, manager))
	assert(repeated.get_generation_report().signature == report.signature)
	repeated.free()
	var future := load("res://scene/biomes/lower_city/lower_city_biome.tscn").instantiate() as BiomeGenerator
	future.biome_definition = future.biome_definition.duplicate() as BiomeDefinition
	future.biome_definition.biome_id = &"biome_02"
	assert(future.generate(101, manager))
	root.add_child(future)
	# Original generator intentionally includes the authored biome ID in its seed.
	for child in future.get_children():
		var skin := child.get_node_or_null("EnemyCharacterVisual") as EnemyCharacterVisual
		if skin != null:
			assert(skin.content_biome_id == &"biome_02")
	assert(future.get_generation_report().enemy_count > 0)
	var presentation_count := 0
	for node in future.find_children("*", "Node2D", true, false):
		if node.get_script() == load("res://scene/biomes/lower_city/lower_city_presentation.gd"):
			assert(node.content_biome_id == &"biome_02")
			presentation_count += 1
	# The temporary district renderer is deliberately detached from every run.
	assert(presentation_count == 0)
	legacy.free()
	future.free()
	manager.free()
	return true
