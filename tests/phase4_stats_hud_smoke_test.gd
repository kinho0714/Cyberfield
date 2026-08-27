extends SceneTree

const PLAYER_SCENE := preload("res://entities/player.tscn")
const ENEMY_SCENE := preload("res://entities/Enemy.tscn")
const RANGED_SCENE := preload("res://entities/RangedEnemy.tscn")
const RUN_MANAGER_SCRIPT := preload("res://scene/run_manager.gd")
const LOWER_CITY := preload("res://scene/biomes/lower_city/lower_city.tres")
const MAIN_SCENE := preload("res://scene/main.tscn")

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_central_stats()
	await _test_player_stats()
	_test_enemy_difficulty_stats()
	_test_upper_lower_modules()
	await _test_hud_contract()
	if failures.is_empty():
		print("PHASE4_STATS_HUD_SMOKE_TEST_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_central_stats() -> void:
	_check(CombatStats.PLAYER_BASE_MAX_HP == 1000, "Player base HP must be 1000")
	_check(CombatStats.player_melee_damage(0) == 40, "base melee damage must be centralized")
	_check(CombatStats.player_slam_damage(0) == 80, "base slam damage must be centralized")
	_check(CombatStats.heal_amount(1000) == 250, "healing must restore 25% max HP")
	_check(CombatStats.player_max_hp(1) == 1200, "first Health level must grant 20% base HP")
	_check(CombatStats.player_max_hp(3) - CombatStats.player_max_hp(2) < CombatStats.player_max_hp(2) - CombatStats.player_max_hp(1), "Health gains must diminish")


func _test_player_stats() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	_check(player.health == 1000 and player.max_health == 1000, "Player must spawn at full scalable HP")
	await player.take_damage(100)
	_check(player.health == 900, "Player must take scaled damage")
	player.add_attribute(&"health")
	_check(player.max_health == 1200 and player.health == 1100, "Health choice must preserve missing HP")
	player.add_attribute(&"strength")
	_check(player.get_melee_damage() == 46, "Strength must apply controlled linear scaling")
	player.health = 600
	player.is_healing = true
	player._complete_heal()
	_check(player.health == 900 and player.heal_doses == 3, "one potion must heal 25% max HP and consume one dose")
	var replica := PLAYER_SCENE.instantiate()
	root.add_child(replica)
	replica.apply_network_state(player.get_network_state())
	_check(replica.health == player.health and replica.max_health == player.max_health and replica.strength == player.strength, "network state must replicate scalable individual stats")
	player.health = 50
	await player.take_damage(50)
	_check(player.is_downed and player.health == 0, "zero HP must preserve incapacitation")
	player.revive()
	_check(not player.is_downed and player.health == 480, "revive must restore 40% of scaled max HP")
	player.reset_for_new_run()
	_check(player.health == 1000 and player.max_health == 1000 and player.strength == 0, "new run must reset temporary stats")
	replica.free()
	player.free()


func _test_enemy_difficulty_stats() -> void:
	var manager := RUN_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.configure_run(&"solo", &"pro")
	var common := ENEMY_SCENE.instantiate()
	var ranged := RANGED_SCENE.instantiate()
	root.add_child(common)
	root.add_child(ranged)
	manager._configure_enemy_stats(common)
	manager._configure_enemy_stats(ranged)
	_check(common.max_health == 514 and common.attack_damage == 65, "Pro common enemy scaling must be centralized")
	_check(ranged.max_health == 428 and ranged.projectile_damage == 130, "Pro ranged scaling must be centralized")
	common.free()
	ranged.free()
	manager.free()


func _test_upper_lower_modules() -> void:
	var route_styles: Dictionary = {}
	for definition in LOWER_CITY.get_module_definitions():
		route_styles[definition.route_style] = true
	_check(route_styles.has("upper_lower"), "Lower City must include an upper/lower passage")
	_check(route_styles.has("lower_upper"), "Lower City must include a lower/upper passage")


func _test_hud_contract() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var hud := main.get_node("RunDebugHUD")
	_check(hud.get_node_or_null("GameplayHUD/PlayerPanel/Margin/VBox/Health") is ProgressBar, "gameplay HUD must have a Player health bar")
	_check(hud.get_node_or_null("GameplayHUD/PartnerPanel/VBox/Health") is ProgressBar, "Coop HUD must have a compact partner health bar")
	_check(hud.get_node_or_null("GameplayHUD/BossPanel/VBox/Health") is ProgressBar, "Stage 6 must have a dedicated boss health bar")
	var common := ENEMY_SCENE.instantiate()
	_check(common.get_node_or_null("HealthBar") is ProgressBar and not common.get_node("HealthBar").visible, "normal enemy health must be contextual, not a permanent Label")
	common.free()
	main.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
