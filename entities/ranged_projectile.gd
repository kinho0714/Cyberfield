extends CharacterBody2D

@export var speed := 420.0
@export var damage := CombatStats.RANGED_PROJECTILE_BASE_DAMAGE
@export var maximum_lifetime := 3.0

var direction := Vector2.RIGHT
var shooter: Node = null
var lifetime := 0.0
var spent := false
var network_id := 0
var network_visual_only := false


func _ready() -> void:
	add_to_group("enemy_projectile")
	if is_instance_valid(shooter) and shooter is PhysicsBody2D:
		add_collision_exception_with(shooter)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is PhysicsBody2D:
			add_collision_exception_with(enemy)


func setup(origin: Vector2, shot_direction: Vector2, source: Node, shot_speed: float, shot_damage: int) -> void:
	global_position = origin
	direction = shot_direction.normalized()
	shooter = source
	speed = shot_speed
	damage = shot_damage
	rotation = direction.angle()
	if is_inside_tree() and source is PhysicsBody2D:
		add_collision_exception_with(source)


func _physics_process(delta: float) -> void:
	if spent:
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if (run_manager and not run_manager.run_active) or (room_manager and room_manager.is_transitioning):
		_despawn_networked()
		return
	lifetime += delta
	if lifetime >= maximum_lifetime:
		_despawn_networked()
		return
	if network_visual_only:
		global_position += direction * speed * delta
		return
	var collision := move_and_collide(direction * speed * delta)
	if collision == null:
		return
	spent = true
	var collider := collision.get_collider()
	if collider is Node and collider.is_in_group("player") and not collider.is_downed:
		var knockback_direction := signf(direction.x)
		collider.take_damage(damage, knockback_direction)
	_despawn_networked()


func _despawn_networked() -> void:
	if is_queued_for_deletion():
		return
	if not network_visual_only and network_id > 0:
		var lan_session := get_tree().get_first_node_in_group("lan_session")
		if lan_session != null:
			lan_session.replicate_projectile_despawn(network_id)
	queue_free()
