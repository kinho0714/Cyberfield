extends CharacterBody2D

@export var speed := 420.0
@export var damage := CombatStats.RANGED_PROJECTILE_BASE_DAMAGE
@export var maximum_lifetime := 3.0
@export_enum("ranged", "heavy") var projectile_type := "ranged"

@onready var projectile_visual := $ProjectileVisual as ProjectileVisual

var direction := Vector2.RIGHT
var shooter: Node = null
var lifetime := 0.0
var spent := false
var network_id := 0
var network_visual_only := false
var target_group: StringName = &"player"
## Arsenal do jogador (01/11/2026): arco em parábola, perfuração e empurrão por arma.
var gravity_accel := 0.0
var pierce_left := 0
var knockback_multiplier := 1.0
var player_visual_id: StringName = &""
## Chumbo visual criado pelo host: também avisa os clientes quando some.
var network_host_visual := false


func _ready() -> void:
	add_to_group("enemy_projectile")
	if is_instance_valid(shooter) and shooter is PhysicsBody2D:
		add_collision_exception_with(shooter)
	var ignored_group := &"enemy" if target_group == &"player" else &"player"
	for body in get_tree().get_nodes_in_group(ignored_group):
		if body is PhysicsBody2D:
			add_collision_exception_with(body)


func setup(origin: Vector2, shot_direction: Vector2, source: Node, shot_speed: float, shot_damage: int, intended_target: StringName = &"player") -> void:
	global_position = origin
	direction = shot_direction.normalized()
	shooter = source
	speed = shot_speed
	damage = shot_damage
	target_group = intended_target
	if is_inside_tree():
		_refresh_collision_exceptions()
	rotation = direction.angle()
	if is_inside_tree() and source is PhysicsBody2D:
		add_collision_exception_with(source)


func _refresh_collision_exceptions() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is PhysicsBody2D:
			if target_group == &"enemy": remove_collision_exception_with(enemy)
			else: add_collision_exception_with(enemy)
	for player in get_tree().get_nodes_in_group("player"):
		if player is PhysicsBody2D:
			if target_group == &"player": remove_collision_exception_with(player)
			else: add_collision_exception_with(player)
	if shooter is PhysicsBody2D:
		add_collision_exception_with(shooter)


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
	if gravity_accel != 0.0:
		var arc_velocity := direction * speed + Vector2(0.0, gravity_accel * delta)
		speed = arc_velocity.length()
		direction = arc_velocity / maxf(speed, 0.001)
		rotation = direction.angle()
	if network_visual_only:
		global_position += direction * speed * delta
		return
	var collision := move_and_collide(direction * speed * delta)
	if collision == null:
		return
	var collider := collision.get_collider()
	if collider is Node and collider.is_in_group(target_group) and (target_group != &"player" or not collider.is_downed):
		var knockback_direction := signf(direction.x)
		if target_group == &"enemy":
			collider.take_damage(damage, knockback_direction, knockback_multiplier)
			if pierce_left > 0 and collider is PhysicsBody2D:
				pierce_left -= 1
				add_collision_exception_with(collider)
				if projectile_visual != null and projectile_visual.has_method("show_pierce"):
					projectile_visual.show_pierce()
				return
		else:
			collider.take_damage(damage, knockback_direction)
	_begin_impact(global_position)


## Troca a arte inimiga pela arte do projétil do jogador (também usada pelos clientes LAN).
func apply_player_visual(visual_id: StringName) -> void:
	player_visual_id = visual_id
	var replacement := PlayerProjectileVisual.new()
	replacement.visual_id = visual_id
	replacement.name = "PlayerProjectileVisual"
	replacement.z_index = 4
	var old := get_node_or_null("ProjectileVisual")
	if old != null:
		old.queue_free()
	add_child(replacement)
	projectile_visual = replacement
	if gravity_accel == 0.0:
		gravity_accel = PlayerProjectileVisual.gravity_for(visual_id)


func _begin_impact(impact_position: Vector2) -> void:
	if spent:
		return
	spent = true
	global_position = impact_position
	if target_group == &"enemy" and not network_visual_only:
		var audio := get_tree().get_first_node_in_group("audio_service")
		if audio != null:
			audio.play_event(&"weapon_impact")
	$CollisionShape2D.set_deferred("disabled", true)
	if projectile_visual != null:
		projectile_visual.show_impact()
	if not network_visual_only and network_id > 0:
		var lan_session := get_tree().get_first_node_in_group("lan_session")
		if lan_session != null:
			lan_session.replicate_projectile_impact(network_id, impact_position, StringName(projectile_type))
	var impact_duration := projectile_visual.get_impact_duration() if projectile_visual != null else 0.0
	if impact_duration > 0.0:
		await get_tree().create_timer(impact_duration).timeout
	_despawn_networked()


func show_network_impact(impact_position: Vector2) -> void:
	if spent:
		return
	spent = true
	global_position = impact_position
	$CollisionShape2D.set_deferred("disabled", true)
	if projectile_visual != null:
		projectile_visual.show_impact()


func _despawn_networked() -> void:
	if is_queued_for_deletion():
		return
	if (not network_visual_only or network_host_visual) and network_id > 0:
		var lan_session := get_tree().get_first_node_in_group("lan_session")
		if lan_session != null:
			lan_session.replicate_projectile_despawn(network_id)
	queue_free()
