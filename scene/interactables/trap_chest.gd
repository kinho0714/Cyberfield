class_name TrapChest
extends Area2D

const COMMON_SCENE := preload("res://entities/Enemy.tscn")
const RANGED_SCENE := preload("res://entities/RangedEnemy.tscn")
const HEAVY_SCENE := preload("res://entities/HeavyEnemy.tscn")
const CHEST_TEXTURE := preload("res://assets/props/chests/trap_chest.png")
const BiomeLootPlaceholderScript := preload("res://scene/biomes/biome_loot_placeholder.gd")

@export var trap_id: StringName
@export var event_spawn_positions: Array[Vector2] = []
## P1-B: "recompensa melhorada" pode incluir arma (mín. incomum), definida na geração.
@export var reward_weapon_id: StringName = &""
@export var reward_rarity: StringName = &""

var _event_spawned := false

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label
var _chest_sprite: Sprite2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("trap_chest")
	collision_layer = 2
	collision_mask = 1
	visual.visible = false
	_chest_sprite = Sprite2D.new()
	_chest_sprite.name = "TemporaryTrapChestVisual"
	_chest_sprite.texture = CHEST_TEXTURE
	_chest_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chest_sprite.scale = Vector2.ONE  # original chest art, drawn at final size
	_chest_sprite.position = Vector2(0.0, -3.0)
	add_child(_chest_sprite)
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
		_play_audio_event(&"loot_open")
		manager.activate_trap_event(trap_id, manager.get_current_map_state().get_trap_event_enemy_ids(trap_id))
	elif state == BiomeMapState.TRAP_CLEARED:
		_play_audio_event(&"loot_open")
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
			_chest_sprite.modulate = Color(1.0, 0.55, 0.48, 1.0)
			label.text = "EVENTO ATIVO // DERROTE A EMBOSCADA"
			_spawn_event_enemies()
		BiomeMapState.TRAP_CLEARED:
			visual.color = Color(0.2, 0.9, 0.45, 1.0)
			_chest_sprite.modulate = Color(0.62, 1.0, 0.72, 1.0)
			label.text = "[USAR] COLETAR RECOMPENSA MELHORADA"
		BiomeMapState.TRAP_REWARDED:
			BiomeLootPlaceholderScript.spawn_weapon_reward(self, reward_weapon_id, reward_rarity, StringName("%s_weapon" % trap_id))
			queue_free()
		_:
			# It deliberately looks like ordinary loot before activation.
			visual.color = Color(0.72, 0.25, 0.85, 1.0)
			_chest_sprite.modulate = Color.WHITE
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
		# 02/11/2026 (P1-A): posicionar ANTES de entrar na árvore. Antes o `_ready()` do
		# inimigo rodava na origem do pai (y≈0) e o primeiro pouso no ponto da emboscada
		# contava como queda de centenas de px — dano de queda letal ou de ~50% da vida.
		var parent_2d := parent as Node2D
		enemy.position = parent_2d.to_local(event_spawn_positions[index]) if parent_2d != null else event_spawn_positions[index]
		parent.add_child(enemy)
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


func _play_audio_event(event_id: StringName) -> void:
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_event"):
		audio.play_event(event_id)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		label.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		label.visible = get_overlapping_bodies().any(func(candidate: Node) -> bool: return candidate != body and candidate.is_in_group("player"))
