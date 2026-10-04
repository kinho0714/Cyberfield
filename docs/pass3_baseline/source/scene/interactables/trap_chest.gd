class_name TrapChest
extends Area2D

const COMMON_SCENE := preload("res://entities/Enemy.tscn")
const RANGED_SCENE := preload("res://entities/RangedEnemy.tscn")
const HEAVY_SCENE := preload("res://entities/HeavyEnemy.tscn")

@export var trap_id: StringName
@export var event_spawn_positions: Array[Vector2] = []

var _event_spawned := false

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("trap_chest")
	collision_layer = 2
	collision_mask = 1
	label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var manager := _run_manager()
	if manager == null:
		return
	var composition: Array[StringName] = manager.get_trap_event_composition(trap_id, event_spawn_positions.size())
	manager.get_current_map_state().register_trap_event(trap_id, _event_enemy_ids(composition.size()))
	manager.state_changed.connect(_refresh)
	_refresh()


func interact(interactor: Node2D = null) -> void:
	if interactor == null or bool(interactor.get("is_downed")) or global_position.distance_to(interactor.global_position) > 96.0:
		return
	var manager := _run_manager()
	if manager == null:
		return
	var lan_session := get_tree().get_first_node_in_group("lan_session")
	# The existing reliable interaction pulse makes the host-side P2 interact.
	# A client replica must never transition or reward the event itself.
	if lan_session != null and lan_session.is_client():
		return
	var state: StringName = StringName(manager.get_current_map_state().get_trap_event_state(trap_id))
	if state == BiomeMapState.TRAP_UNOPENED:
		manager.activate_trap_event(trap_id, manager.get_current_map_state().get_trap_event_enemy_ids(trap_id))
	elif state == BiomeMapState.TRAP_CLEARED:
		manager.claim_trap_event_reward(trap_id)


func _refresh() -> void:
	if not is_node_ready():
		return
	var manager := _run_manager()
	if manager == null:
		return
	var state: StringName = StringName(manager.get_current_map_state().get_trap_event_state(trap_id))
	match state:
		BiomeMapState.TRAP_ACTIVE:
			visual.color = Color(0.9, 0.24, 0.18, 1.0)
			label.text = "EVENTO ATIVO // DERROTE A EMBOSCADA"
			_spawn_event_enemies()
		BiomeMapState.TRAP_CLEARED:
			visual.color = Color(0.2, 0.9, 0.45, 1.0)
			label.text = "[USAR] COLETAR RECOMPENSA MELHORADA"
		BiomeMapState.TRAP_REWARDED:
			queue_free()
		_:
			# It deliberately looks like ordinary loot before activation.
			visual.color = Color(0.72, 0.25, 0.85, 1.0)
			label.text = "[USAR] LOOT"


func _spawn_event_enemies() -> void:
	if _event_spawned:
		return
	_event_spawned = true
	var manager := _run_manager()
	var parent := get_parent()
	if manager == null or parent == null:
		return
	var composition: Array[StringName] = manager.get_trap_event_composition(trap_id, event_spawn_positions.size())
	var enemy_ids: Array[StringName] = manager.get_current_map_state().get_trap_event_enemy_ids(trap_id)
	var room_id: StringName = manager.get_current_room_id()
	var lan_session := get_tree().get_first_node_in_group("lan_session")
	for index in mini(composition.size(), enemy_ids.size()):
		if manager.is_enemy_dead(room_id, enemy_ids[index]):
			continue
		var enemy: Node
		match composition[index]:
			&"heavy": enemy = HEAVY_SCENE.instantiate()
			&"ranged": enemy = RANGED_SCENE.instantiate()
			_: enemy = COMMON_SCENE.instantiate()
		enemy.name = String(enemy_ids[index]).to_pascal_case()
		enemy.persistent_id = enemy_ids[index]
		enemy.required_for_completion = true
		parent.add_child(enemy)
		enemy.global_position = event_spawn_positions[index]
		manager.register_trap_event_enemy(enemy, trap_id)
		if lan_session != null and lan_session.is_client():
			enemy.network_target_position = enemy.global_position
			enemy.set_physics_process(false)


func _event_enemy_ids(count: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for index in mini(maxi(count, 0), event_spawn_positions.size()):
		result.append(StringName("%s_event_%02d" % [trap_id, index + 1]))
	return result


func _run_manager() -> Node:
	return get_tree().get_first_node_in_group("run_manager")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		label.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		label.visible = get_overlapping_bodies().any(func(candidate: Node) -> bool: return candidate != body and candidate.is_in_group("player"))
