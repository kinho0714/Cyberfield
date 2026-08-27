extends CharacterBody2D

@export var speed := 420.0
@export var damage := 2
@export var maximum_lifetime := 3.0

var direction := Vector2.RIGHT
var shooter: Node = null
var lifetime := 0.0
var spent := false


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
		queue_free()
		return
	lifetime += delta
	if lifetime >= maximum_lifetime:
		queue_free()
		return
	var collision := move_and_collide(direction * speed * delta)
	if collision == null:
		return
	spent = true
	var collider := collision.get_collider()
	if collider is Node and collider.is_in_group("player") and not collider.is_downed:
		var knockback_direction := signf(direction.x)
		collider.take_damage(damage, knockback_direction)
	queue_free()
