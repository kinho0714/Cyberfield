extends Node2D

const BOSS_SCENE := preload("res://entities/Enemy.tscn")
const ARENA_BOUNDS := Rect2(0.0, 0.0, 1600.0, 720.0)

var run_manager: Node
var boss_spawned := false


func setup(manager: Node) -> void:
	run_manager = manager
	var boss := BOSS_SCENE.instantiate()
	boss.name = "PrototypeBoss"
	boss.persistent_id = &"stage_06_boss"
	boss.enemy_role = 1
	boss.required_for_completion = true
	boss.visual_scale = 1.65
	boss.move_speed = 118.0
	boss.position = $BossSpawn.position
	$Entities.add_child(boss)
	boss_spawned = true


func _process(_delta: float) -> void:
	if not boss_spawned or run_manager == null or not bool(run_manager.run_active):
		return
	if _has_living_boss():
		return
	boss_spawned = false
	var lan_session := get_tree().get_first_node_in_group("lan_session")
	if lan_session == null or not lan_session.is_network_game() or lan_session.is_host():
		run_manager.finish_run()


func _has_living_boss() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_boss() and enemy.run_room_id == &"boss_stage_06" and not enemy.is_queued_for_deletion():
			return true
	return false


func get_generated_bounds() -> Rect2:
	return ARENA_BOUNDS


func get_start_position() -> Vector2:
	return $Start.global_position
