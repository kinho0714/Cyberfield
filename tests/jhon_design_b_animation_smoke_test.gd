extends SceneTree
## Jhon Jhones Design B (02/11/2026) — teste no JOGO REAL: main.tscn → Casa → run.
## Confere importação das folhas, quadros, transparência, pés na colisão, transições,
## ferido/caído/levantar, tiro/mira/recarga por família, golpe, postura de impacto, arma
## na mão e projétil (colisão na altura de sempre, desenho no cano).
##   godot --headless --path . --script res://tests/jhon_design_b_animation_smoke_test.gd
##   xvfb-run godot --path . --script res://tests/jhon_design_b_animation_smoke_test.gd -- <dir>  (capturas)

const SETS := preload("res://entities/character_animation_sets.gd")

var game: Node
var player: CharacterBody2D
var visual: AnimatedSprite2D
var out_dir := ""
var failures: PackedStringArray = []
var seen_states := {}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("JHON_B_CHECK_FAIL " + message)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
		root.size = Vector2i(1560, 720)
	var temp := "user://jhon_b_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(temp)
	game = load("res://scene/main.tscn").instantiate()
	game.get_node("LocalSettings").settings_path = temp.path_join("settings.cfg")
	game.get_node("MetaProgression").save_path = temp.path_join("meta.json")
	root.add_child(game)
	await process_frame
	_test_import()
	await game.start_configured_run(&"solo", &"normal", -1)
	await game._begin_run_from_hub(4242)
	player = game.get_players()[0]
	visual = player.get_node("PlayerCharacterVisual") as AnimatedSprite2D
	player.is_invulnerable = true
	player.invulnerability_timer = 999.0
	for i in 90:
		if player.is_on_floor():
			break
		await physics_frame
	for enemy in root.get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
		enemy.set("network_target_position", Vector2(-9000, -9000))
		enemy.global_position = Vector2(-9000, -9000)
	await _test_locomotion()
	await _test_combat()
	await _test_damage_states()
	print("JHON_B_STATES %s" % JSON.stringify(seen_states.keys()))
	print("JHON_B_REPORT failures=%d %s" % [failures.size(), JSON.stringify(failures)])
	if failures.is_empty():
		print("JHON_DESIGN_B_ANIMATION_SMOKE_TEST_OK")
	quit(0 if failures.is_empty() else 1)


func _test_import() -> void:
	var data: Dictionary = SETS.SETS.get(&"jhon", {})
	_check(not data.is_empty(), "conjunto do Jhon registrado")
	var expected := [&"idle", &"walk", &"run", &"jump", &"fall", &"land", &"dash", &"hurt", &"downed", &"get_up",
		&"aim_pistol", &"aim_rifle", &"aim_bow", &"shoot_pistol", &"shoot_rifle", &"shoot_bow",
		&"reload_pistol", &"melee_ready_impact", &"melee_punch_01"]
	var anims: Dictionary = data.get("anims", {})
	for name: StringName in expected:
		_check(anims.has(name), "animação %s presente" % name)
		if not anims.has(name):
			continue
		var spec: Dictionary = anims[name]
		var texture := load(String(data.dir) + String(spec.file)) as Texture2D
		_check(texture != null, "%s importada" % name)
		if texture == null:
			continue
		_check(int(spec.frames) == 8 and texture.get_width() == 8 * int(data.cell.x) and texture.get_height() == int(data.cell.y), "%s: 8 quadros de %s" % [name, data.cell])
		var image := texture.get_image()
		_check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(image.get_width() - 1, 0).a == 0.0, "%s com fundo transparente" % name)
		var used := image.get_used_rect()
		_check(used.end.y == image.get_height(), "%s: pés na última linha" % name if name != &"jump" and name != &"fall" else "%s ok" % name)
	_check(not anims.has(&"reload_rifle") and (data.get("rejected", []) as Array).has(&"reload_rifle"), "RELOAD_RIFLE inconsistente não integrado")
	_check(not anims.has(&"reload_shotgun") and not anims.has(&"double_jump"), "sem RELOAD_SHOTGUN/DOUBLE_JUMP inventados")


func _state() -> StringName:
	var state: StringName = visual.get_presentation_state()
	seen_states[state] = true
	return state


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _test_locomotion() -> void:
	await create_timer(0.7).timeout
	await _frames(2)
	_check(_state() == &"idle", "parado = idle (%s)" % _state())
	_check(visual.animation == &"b_idle" and is_equal_approx(visual.scale.x, 1.0), "idle usa a folha oficial a 1,0x")
	# pés: última linha opaca do quadro (mundo) ~ base da colisão
	var texture := visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
	var feet_local := texture.get_height() * 0.5
	var feet_world := visual.to_global(Vector2(0, feet_local)).y
	var shape := player.get_node("CollisionShape2D") as CollisionShape2D
	var capsule := shape.shape as CapsuleShape2D
	var collision_bottom := shape.global_position.y + capsule.height * 0.5
	_check(absf(feet_world - collision_bottom) <= 3.0, "pés alinhados à colisão (%.1f vs %.1f)" % [feet_world, collision_bottom])
	await _capture("b_idle")
	Input.action_press(&"right")
	await _frames(12)
	_check(_state() == &"run", "teclado = corrida (%s)" % _state())
	await _capture("b_run")
	Input.action_release(&"right")
	await _frames(20)
	_check(_state() == &"idle", "solta = idle")
	player.velocity.x = 120.0
	_check(visual.get_presentation_state() == &"walk", "velocidade parcial (touch analógico) = walk")
	player.velocity.x = 0.0
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	await _frames(4)
	_check(_state() == &"jump", "subindo = jump (%s)" % _state())
	await _capture("b_jump")
	var landed := false
	var fell := false
	for i in 120:
		await physics_frame
		await process_frame
		var s := _state()
		if s == &"fall":
			fell = true
		if s == &"land":
			landed = true
			break
	_check(fell, "descendo = fall")
	_check(landed, "toque no chão = land")
	await _frames(30)
	player._start_dash()
	await process_frame
	_check(_state() == &"dash", "dash = rolamento oficial")
	await _capture("b_dash")
	await _frames(20)


func _equip(weapon_id: StringName) -> void:
	player.equip_weapon(weapon_id, 0, &"common")
	player.active_weapon_slot = 0
	player.weapon_cooldowns.fill(0.0)
	player.is_attacking = false
	await _frames(4)


func _test_combat() -> void:
	for spec in [[&"corp_pistol", &"pistol"], [&"pulse_rifle", &"rifle"], [&"neon_longbow", &"bow"], [&"scrap_shotgun", &"rifle"]]:
		await _equip(spec[0])
		player.anim.flip_h = false
		player.attack(0)
		await process_frame
		_check(_state() == StringName("shoot_" + String(spec[1])), "%s dispara com shoot_%s (%s)" % [spec[0], spec[1], _state()])
		var held := visual.get_node_or_null("HeldWeapon") as Sprite2D
		_check(held != null and held.visible, "%s empunhada (sprite separado)" % spec[0])
		var muzzle: Vector2 = visual.muzzle_global_position()
		_check(muzzle != Vector2.INF and muzzle.y < player.global_position.y - 10.0, "%s: cano na altura da mão" % spec[0])
		var shot: Node2D = null
		for node in player.get_parent().get_children():
			if node.get("player_visual_id") != null and StringName(node.get("player_visual_id")) != &"" and not node.is_queued_for_deletion():
				shot = node
		if shot != null and not bool(shot.get("network_visual_only")):
			_check(absf(shot.global_position.y - (player.global_position.y - 8.0)) <= 6.0, "%s: colisão do projétil na altura de sempre" % spec[0])
			var drawn := shot.get_node_or_null("PlayerProjectileVisual") as Node2D
			_check(drawn != null and absf(drawn.global_position.y - muzzle.y) <= 8.0, "%s: projétil desenhado saindo do cano" % spec[0])
		await _capture("b_shoot_%s" % spec[1])
		await create_timer(0.4).timeout
		_check(_state() == StringName("aim_" + String(spec[1])), "%s: mira após o tiro (%s)" % [spec[0], _state()])
		await _capture("b_aim_%s" % spec[1])
		await create_timer(0.7).timeout
		_check(_state() == &"idle", "%s: volta ao idle" % spec[0])
	await _equip(&"corp_pistol")
	var ammo: Dictionary = player.weapon_ammo[&"corp_pistol"]
	ammo["clip"] = 1
	player.weapon_ammo[&"corp_pistol"] = ammo
	_check(player.reload_weapon(0), "recarga da pistola inicia")
	await _frames(6)
	_check(_state() == &"reload_pistol", "recarga da pistola animada (%s)" % _state())
	var first := visual.frame
	await create_timer(0.6).timeout
	_check(visual.frame > first, "quadros da recarga acompanham o tempo de recarga")
	await _capture("b_reload_pistol")
	await create_timer(1.0).timeout
	await _equip(&"scrap_shotgun")
	var shell: Dictionary = player.weapon_ammo[&"scrap_shotgun"]
	shell["clip"] = 0
	player.weapon_ammo[&"scrap_shotgun"] = shell
	player.reload_weapon(0)
	await _frames(6)
	_check(not String(_state()).begins_with("reload_"), "escopeta sem RELOAD aprovado não inventa animação")
	await create_timer(2.2).timeout
	await _equip(&"baseball_bat")
	await _frames(20)
	_check(_state() == &"melee_ready_impact", "arma de impacto: postura preparatória (%s)" % _state())
	await _capture("b_ready_impact")
	player.combo_end_recovery_timer = 0.0
	player.attack(0)
	await process_frame
	_check(_state() == &"melee_punch_01", "golpe corpo a corpo usa MELEE_PUNCH_01 (%s)" % _state())
	await _capture("b_strike")
	await create_timer(0.6).timeout
	await _equip(&"scrap_blade")


func _test_damage_states() -> void:
	player.is_invulnerable = false
	player.invulnerability_timer = 0.0
	player.dash_invulnerability_timer = 0.0
	player.take_damage(1, 0.0)
	await process_frame
	await process_frame
	_check(_state() == &"hurt", "dano = hurt (%s)" % _state())
	await _capture("b_hurt")
	await create_timer(0.5).timeout
	player.enter_downed()
	await _frames(40)
	_check(_state() == &"downed" and visual.animation == &"b_downed", "caído = downed oficial")
	await _capture("b_downed")
	player.revive()
	await process_frame
	await process_frame
	_check(_state() == &"get_up", "revivido = get_up (%s)" % _state())
	await _capture("b_get_up")
	await create_timer(0.7).timeout
	_check(_state() == &"idle", "após levantar = idle")
	# estados sem folha aprovada continuam com a animação anterior
	_check(visual.sprite_frames.has_animation(&"revive") and visual.sprite_frames.has_animation(&"wall_slide"), "revive/parede preservados")


func _capture(label: String) -> void:
	if out_dir.is_empty():
		return
	game.gameplay_camera.global_position = player.global_position
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var xf := root.get_viewport().get_canvas_transform()
	var at: Vector2 = xf * player.global_position
	var region := Rect2i(Vector2i(at) - Vector2i(110, 120), Vector2i(220, 160)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	image.get_region(region).save_png(out_dir.path_join(label + ".png"))
