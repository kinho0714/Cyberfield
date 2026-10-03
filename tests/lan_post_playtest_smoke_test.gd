extends SceneTree

class ProjectileRoom extends Node2D:
	var current_room: Node2D
	var is_transitioning := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_host_revive()
	var player_scene: PackedScene = load("res://entities/player.tscn")
	# Participant-independent: repeat with each side as local predicted reviver.
	for participant: StringName in [&"player_1", &"player_2", &"player_3", &"player_4"]:
		var player: CharacterBody2D = player_scene.instantiate()
		player.participant_id = participant
		root.add_child(player)
		player.network_prediction_only = true
		player.set_process(false)
		player.set_physics_process(false)
		player.global_position = Vector2(900, 300)
		player.network_has_pending_snap = true
		var state: Dictionary = player.get_network_state()
		state.position = Vector2(200, 300)
		state.velocity = Vector2.ZERO
		state.is_downed = true
		state.health = 0
		player.apply_network_state(state, true, 1)
		assert(player.global_position == state.position)
		assert(not player.network_has_pending_snap)
		player._physics_process(0.1)
		assert(player.global_position == state.position)
		var visual: PlayerCharacterVisual = player.get_node("PlayerCharacterVisual")
		assert(visual.get_presentation_state() == &"downed")
		state.is_downed = false
		state.health = 5
		state.position = Vector2(220, 300)
		state.is_reviving = true
		player.apply_network_state(state, true, 1)
		assert(player.global_position == state.position)
		assert(visual.get_presentation_state() == &"revive")
		state.position = Vector2(999, 999)
		player.apply_network_state(state, true, 0)
		assert(player.global_position == Vector2(220, 300))
		state.position = Vector2(225, 300)
		state.is_reviving = false
		player.apply_network_state(state, true, 1)
		assert(player.global_position == Vector2(220, 300)) # healthy small-error prediction
		player.network_prediction_only = false
		player.network_remote_replica = true
		for animation_name: StringName in [&"idle", &"walk", &"air", &"attack", &"dash", &"ground_slam", &"hurt", &"downed", &"revive", &"wall_slide", &"wall_climb"]:
			state.presentation_state = animation_name
			state.presentation_frame = 1
			player.apply_network_state(state, false, 1)
			visual._update_presentation()
			assert(visual.animation == animation_name)
		player.free()
	for path: String in ["res://entities/Enemy.tscn", "res://entities/RangedEnemy.tscn", "res://entities/HeavyEnemy.tscn"]:
		var scene: PackedScene = load(path)
		var enemy: CharacterBody2D = scene.instantiate()
		root.add_child(enemy)
		enemy.set_physics_process(false)
		var snapshot: Dictionary = enemy.get_network_state()
		snapshot.health = maxi(enemy.health - 1, 1)
		snapshot.presentation_state = &"attack"
		snapshot.aim_visible = true
		snapshot.aim_points = PackedVector2Array([Vector2(40, -70), Vector2(200, -70)])
		enemy.apply_network_state(snapshot)
		assert(enemy.get_visual_state() == &"attack")
		var bar: ProgressBar = enemy.get_node("HealthBar")
		var sprite: AnimatedSprite2D = enemy.get_node("EnemyCharacterVisual")
		assert(bar.visible and bar.value == snapshot.health and bar.max_value == enemy.max_health)
		assert(bar.z_index > sprite.z_index)
		assert(bar.position.y + bar.size.y < sprite.position.y)
		if enemy.has_node("AimLine"):
			assert(enemy.get_node("AimLine").visible)
			assert(enemy.get_node("AimLine").points == snapshot.aim_points)
			snapshot.aim_visible = false
			enemy.apply_network_state(snapshot)
			assert(not enemy.get_node("AimLine").visible)
		enemy._process(3.0)
		assert(not bar.visible)
		enemy.free()
	# Exercise the actual client RPC handlers locally (transport is a physical test).
	var room: ProjectileRoom = ProjectileRoom.new()
	root.add_child(room)
	room.current_room = room
	room.add_to_group("room_manager")
	var session: LanSession = LanSession.new()
	root.add_child(session)
	session.set_process(false)
	session.role = LanSession.Role.CLIENT
	for index in 2:
		var kind: String = "ranged" if index == 0 else "heavy"
		var projectile_id: int = 50 + index
		session._spawn_network_projectile(projectile_id, Vector2(100, 100), Vector2.RIGHT, 300.0, 1, "player", kind)
		var projectile: CharacterBody2D = session._client_projectiles[projectile_id]
		assert(projectile.network_visual_only)
		projectile._physics_process(0.1)
		assert(projectile.global_position.is_equal_approx(Vector2(130, 100)))
		session._impact_network_projectile(projectile_id, Vector2(140, 100), kind)
		assert(projectile.spent)
		assert(projectile.get_node("ProjectileVisual").animation == &"impact")
		projectile._physics_process(0.1)
		assert(projectile.global_position == Vector2(140, 100))
		session._despawn_network_projectile(projectile_id)
		assert(not session._client_projectiles.has(projectile_id))
		assert(projectile.is_queued_for_deletion())
	session.queue_free()
	room.queue_free()
	await process_frame
	print("LAN_POST_PLAYTEST_SMOKE_TEST_OK")
	quit()


func _test_host_revive() -> void:
	var scene: PackedScene = load("res://entities/player.tscn")
	for index in 2:
		var reviver: CharacterBody2D = scene.instantiate()
		var victim: CharacterBody2D = scene.instantiate()
		reviver.participant_id = &"player_1" if index == 0 else &"player_2"
		victim.participant_id = &"player_2" if index == 0 else &"player_1"
		root.add_child(reviver)
		root.add_child(victim)
		for actor: CharacterBody2D in [reviver, victim]:
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.global_position = Vector2(300, 300)
		victim.enter_downed()
		reviver._revive_target = victim
		assert(reviver.get_network_state().is_reviving)
		assert(reviver.get_network_state().presentation_state == &"revive")
		victim.receive_revive_progress(reviver, victim.revive_duration * 0.5)
		assert(victim.is_downed)
		assert(victim.get_network_state().presentation_state == &"downed")
		victim.receive_revive_progress(reviver, victim.revive_duration)
		assert(not victim.is_downed and victim.health > 0)
		assert(victim.global_position == Vector2(300, 300))
		assert(victim.velocity == Vector2.ZERO)
		assert(not reviver.get_network_state().is_reviving)
		reviver.free()
		victim.free()
