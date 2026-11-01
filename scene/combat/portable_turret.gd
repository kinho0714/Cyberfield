class_name PortableTurret
extends Node2D
## Torreta portátil: assenta no chão, procura o inimigo vivo mais próximo com linha de
## visada e dispara projéteis do jogador até a bateria acabar.

const PROJECTILE_SCENE := preload("res://entities/ranged_projectile.tscn")
const BASE_SHEET := "res://assets/accessories/portable_turret_world.png"
const WORLD_MASK := 1

var data: Dictionary = {}
var owner_player: Node2D
var _life := 0.0
var _fire_timer := 0.3
var _target: Node2D
var _sprite: AnimatedSprite2D
var _beam: Line2D
var _battery: Line2D


func setup(from: Node2D, at: Vector2) -> void:
	owner_player = from
	data = AccessoryCatalog.get_definition(&"portable_turret")
	set_meta(&"deploy_at", at)


func _ready() -> void:
	add_to_group("player_gadget")
	add_to_group("portable_turret")
	z_index = 5
	if ResourceLoader.exists(BASE_SHEET):
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = VisualSpriteFactory.build_sprite_frames({
			&"idle": {"texture": load(BASE_SHEET), "frames": 4, "fps": 6.0, "loop": true}})
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.scale = Vector2(1.5, 1.5)
		_sprite.position = Vector2(0, -18)
		add_child(_sprite)
		_sprite.play(&"idle")
	_beam = Line2D.new()
	_beam.width = 1.0
	_beam.default_color = Color(1.0, 0.82, 0.48, 0.45)
	_beam.visible = false
	add_child(_beam)
	_battery = Line2D.new()
	_battery.width = 2.0
	_battery.default_color = Color("ffd27a")
	add_child(_battery)
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _snap_to_floor() -> void:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -8), global_position + Vector2(0, 220), WORLD_MASK, _actor_rids())
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position


func _physics_process(delta: float) -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if (run_manager != null and not run_manager.run_active) or (room_manager != null and room_manager.is_transitioning):
		queue_free()
		return
	_life += delta
	var duration := float(data.get("duration", 12.0))
	var remaining := clampf(1.0 - _life / duration, 0.0, 1.0)
	_battery.points = PackedVector2Array([Vector2(-12, 4), Vector2(-12 + 24.0 * remaining, 4)])
	if _life >= duration:
		set_physics_process(false)
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.3)
		fade.tween_callback(queue_free)
		return
	_fire_timer -= delta
	if not _valid_target(_target):
		_target = _find_target()
	_beam.visible = _target != null
	if _target == null:
		return
	var muzzle := global_position + Vector2(0, -24)
	var aim := (_target.global_position + Vector2(0, -26)) - muzzle
	if _sprite != null:
		_sprite.flip_h = aim.x < 0.0
	_beam.points = PackedVector2Array([Vector2(0, -24), Vector2(0, -24) + aim])
	if _fire_timer <= 0.0:
		_fire_timer = float(data.get("fire_interval", 0.45))
		_fire(muzzle, aim.normalized())


func _valid_target(candidate: Node2D) -> bool:
	return candidate != null and is_instance_valid(candidate) and EnemyStatus.is_alive(candidate) \
		and candidate.global_position.distance_to(global_position) <= float(data.get("range", 300.0)) and _has_line_of_sight(candidate)


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node2D):
			continue
		var distance := (enemy as Node2D).global_position.distance_to(global_position)
		if distance < best_distance and _valid_target(enemy):
			best = enemy
			best_distance = distance
	return best


func _has_line_of_sight(enemy: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -24), enemy.global_position + Vector2(0, -24), WORLD_MASK, _actor_rids())
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Linha de visada e apoio no chão consideram só o cenário (atores ficam na mesma camada).
func _actor_rids() -> Array[RID]:
	var result: Array[RID] = []
	for group: StringName in [&"player", &"enemy"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is CollisionObject2D:
				result.append((node as CollisionObject2D).get_rid())
	return result


func _fire(origin: Vector2, direction: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var projectile := PROJECTILE_SCENE.instantiate()
	parent.add_child(projectile)
	var speed := float(data.get("projectile_speed", 760.0))
	var damage := int(data.get("damage", 18))
	projectile.maximum_lifetime = float(data.get("range", 300.0)) * 1.2 / speed
	projectile.setup(origin, direction, owner_player, speed, damage, &"enemy")
	projectile.apply_player_visual(&"turret_round")
	var lan_session := get_tree().get_first_node_in_group("lan_session")
	if lan_session != null and lan_session.has_method("replicate_projectile_spawn"):
		projectile.network_id = lan_session.replicate_projectile_spawn(origin, direction, speed, damage, &"enemy", &"p_turret_round")
	WeaponFx.muzzle(self, origin, direction, &"small", Color("ffd27a"))
