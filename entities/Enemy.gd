extends CharacterBody2D

enum EnemyRole { NORMAL, BOSS, ELITE }

@export var persistent_id: StringName
@export var required_for_completion := true
@export var enemy_role: EnemyRole = EnemyRole.NORMAL
@export var move_speed := 100.0
@export var attack_horizontal_range := 28.0
@export var attack_vertical_range := 42.0
@export var attack_windup := 0.22
@export var attack_recovery := 0.30
@export var attack_cooldown := 0.45
@export var attack_damage := 1
@export_range(0.5, 4.0, 0.1) var visual_scale := 1.0
@export var patrol_radius := -1.0
@export_range(0.35, 0.50, 0.01) var patrol_speed_ratio := 0.42
@export_range(0.1, 2.0, 0.05) var patrol_pause_min := 0.40
@export_range(0.1, 2.0, 0.05) var patrol_pause_max := 1.20
@export_range(16.0, 80.0, 1.0) var separation_distance := 30.0

var run_room_id: StringName

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_label: Label = $HealthLabel
@onready var attack_shape_cast: ShapeCast2D = $AttackShapeCast
@onready var wall_check: RayCast2D = $WallCheck
@onready var floor_check: RayCast2D = $FloorCheck

const GRAVITY = 980.0

const KNOCKBACK_FORCE = 260.0
const KNOCKBACK_UP = -100.0
const KNOCKBACK_DURATION = 0.18
const TARGET_DETECTION_RANGE := 100.0
const TARGET_SWITCH_MARGIN := 20.0

var player: CharacterBody2D = null
var max_health := 7
var health := 7
var is_hurt = false
var is_attacking = false

var knockback_timer = 0.0
var attack_cooldown_timer := 0.0
var attack_generation := 0
var patrol_origin := Vector2.ZERO
var patrol_direction := 1.0
var patrol_pause_timer := 0.0
var patrol_rng := RandomNumberGenerator.new()


func _ready() -> void:
	attack_shape_cast.enabled = true
	anim.scale = Vector2.ONE * visual_scale
	$CollisionShape2D.scale = Vector2.ONE * visual_scale
	if is_elite():
		anim.modulate = Color(1.0, 0.35, 0.15, 1.0)
	if patrol_radius < 0.0:
		patrol_radius = 120.0 if is_boss() else 96.0 if is_elite() else 80.0
	patrol_origin = global_position
	patrol_rng.seed = _stable_hash(String(persistent_id))
	patrol_direction = -1.0 if patrol_rng.randi_range(0, 1) == 0 else 1.0
	patrol_pause_timer = _next_patrol_pause()
	_update_health_label()


func configure_health(value: int) -> void:
	max_health = maxi(value, 1)
	health = max_health
	_update_health_label()


func is_boss() -> bool:
	return enemy_role == EnemyRole.BOSS


func is_elite() -> bool:
	return enemy_role == EnemyRole.ELITE


func configure_elite() -> void:
	enemy_role = EnemyRole.ELITE
	move_speed *= 1.15
	visual_scale = 1.2


func _update_health_label() -> void:
	if is_instance_valid(health_label):
		health_label.text = "HP: %d/%d" % [health, max_health]


func _physics_process(delta: float) -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var room_manager := get_tree().get_first_node_in_group("room_manager")

	if (run_manager and not run_manager.run_active) or (room_manager and room_manager.is_transitioning):
		velocity = Vector2.ZERO
		return

	# Add gravity.
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0:
		velocity.y = 0

	# Knockback timer.
	if knockback_timer > 0:
		knockback_timer -= delta

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)

	_select_active_player()

	if player:
		var direction: float = sign(
			player.global_position.x - global_position.x
		)

		var offset := player.global_position - global_position

		# Face player.
		if direction > 0:
			anim.flip_h = false
			attack_shape_cast.target_position.x = 30.0

		elif direction < 0:
			anim.flip_h = true
			attack_shape_cast.target_position.x = -30.0

		# AI cannot overwrite horizontal velocity during knockback.
		if knockback_timer <= 0 and not is_hurt:
			var in_attack_range: bool = (
				abs(offset.x) <= attack_horizontal_range
				and abs(offset.y) <= attack_vertical_range
			)

			if not in_attack_range and not is_attacking:
				velocity.x = _safe_horizontal_velocity(direction, move_speed)

				anim.play("walk")

			else:
				velocity.x = 0

				if not is_attacking and attack_cooldown_timer <= 0.0:
					attack()

			# Prevent a stable player-on-enemy stack without frame-by-frame damage.
			if not is_attacking and abs(offset.x) < 18.0 and offset.y < 0.0 and offset.y > -34.0:
				velocity.x = _safe_horizontal_velocity(-direction, move_speed * 0.45)

	else:
		if knockback_timer <= 0 and not is_hurt and not is_attacking:
			_update_patrol(delta)

	move_and_slide()
	if health <= 0:
		velocity = Vector2.ZERO


func _update_patrol(delta: float) -> void:
	var origin_offset := patrol_origin.x - global_position.x
	if absf(origin_offset) > patrol_radius:
		patrol_direction = signf(origin_offset)
		patrol_pause_timer = 0.0
	elif patrol_pause_timer > 0.0:
		patrol_pause_timer = maxf(patrol_pause_timer - delta, 0.0)
		velocity.x = 0.0
		anim.play("idle")
		return
	var next_offset := global_position.x + patrol_direction * 4.0 - patrol_origin.x
	if absf(next_offset) > patrol_radius or not _can_move_horizontally(patrol_direction):
		patrol_direction *= -1.0
		patrol_pause_timer = _next_patrol_pause()
		velocity.x = 0.0
		anim.play("idle")
		return
	velocity.x = _safe_horizontal_velocity(patrol_direction, move_speed * patrol_speed_ratio)
	anim.flip_h = velocity.x < 0.0
	anim.play("walk")


func _safe_horizontal_velocity(direction: float, speed: float) -> float:
	if direction == 0.0 or not _can_move_horizontally(direction):
		return 0.0
	var adjusted_direction := direction
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not is_instance_valid(other) or not other is Node2D:
			continue
		var offset: Vector2 = global_position - other.global_position
		if absf(offset.y) <= 28.0 and absf(offset.x) < separation_distance and absf(offset.x) > 0.01:
			var away := signf(offset.x)
			if away == direction and _can_move_horizontally(away):
				adjusted_direction += away * 0.2
	return signf(adjusted_direction) * speed


func _can_move_horizontally(direction: float) -> bool:
	wall_check.target_position = Vector2(direction * 22.0, 0.0)
	wall_check.force_raycast_update()
	floor_check.position.x = direction * 15.0
	floor_check.force_raycast_update()
	return not wall_check.is_colliding() and floor_check.is_colliding()


func _next_patrol_pause() -> float:
	return patrol_rng.randf_range(minf(patrol_pause_min, patrol_pause_max), maxf(patrol_pause_min, patrol_pause_max))


func _stable_hash(value: String) -> int:
	var result := 2166136261
	for byte in value.to_utf8_buffer():
		result = int((result ^ byte) * 16777619) & 0x7fffffff
	return result


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and _is_valid_target(body):
		_select_active_player()


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null

		if is_attacking:
			is_attacking = false
			anim.play("idle")


func _select_active_player() -> void:
	var nearest: CharacterBody2D = null
	var nearest_distance := INF

	for candidate in get_tree().get_nodes_in_group("player"):
		if not _is_valid_target(candidate):
			continue

		var distance := global_position.distance_to(candidate.global_position)

		if distance <= TARGET_DETECTION_RANGE and distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance

	if _is_valid_target(player):
		var current_distance := global_position.distance_to(player.global_position)

		if current_distance <= TARGET_DETECTION_RANGE and current_distance <= nearest_distance + TARGET_SWITCH_MARGIN:
			return

	player = nearest


func _is_valid_target(candidate: Node) -> bool:
	return (
		is_instance_valid(candidate)
		and candidate.is_in_group("player")
		and not candidate.is_downed
		and candidate.visible
	)


func attack() -> void:
	if not player:
		return

	if is_attacking:
		return

	if is_hurt or knockback_timer > 0.0 or attack_cooldown_timer > 0.0:
		return

	is_attacking = true
	velocity.x = 0.0
	attack_generation += 1
	var this_attack := attack_generation

	anim.play("attack")

	await get_tree().create_timer(attack_windup).timeout

	if not _is_valid_target(player) or is_hurt or knockback_timer > 0.0 or this_attack != attack_generation:
		is_attacking = false
		attack_cooldown_timer = attack_cooldown
		return

	var offset := player.global_position - global_position
	attack_shape_cast.target_position = Vector2(
		clamp(offset.x, -attack_horizontal_range, attack_horizontal_range),
		clamp(offset.y, -attack_vertical_range, attack_vertical_range)
	)

	attack_shape_cast.force_shapecast_update()

	if attack_shape_cast.is_colliding():
		for i in attack_shape_cast.get_collision_count():
			var body = attack_shape_cast.get_collider(i)

			if body.is_in_group("player") and not body.is_downed:
				var knockback_direction = sign(
					body.global_position.x - global_position.x
				)

				body.take_damage(attack_damage, knockback_direction)
				break
			elif body is PhysicsBody2D:
				break

	await get_tree().create_timer(attack_recovery).timeout

	if this_attack == attack_generation:
		is_attacking = false
		attack_cooldown_timer = attack_cooldown


func take_damage(amount: int, knockback_direction: float = 0.0, knockback_multiplier: float = 1.0) -> void:
	if is_hurt:
		return

	health = maxi(health - amount, 0)
	attack_generation += 1
	is_attacking = false
	attack_cooldown_timer = maxf(attack_cooldown_timer, attack_cooldown)
	_update_health_label()

	print("Enemy health: ", health)

	if knockback_direction != 0.0:
		velocity.x = knockback_direction * KNOCKBACK_FORCE * knockback_multiplier
		velocity.y = KNOCKBACK_UP * knockback_multiplier
		knockback_timer = KNOCKBACK_DURATION

	is_hurt = true
	anim.modulate = Color(1, 1, 1, 0.5)

	await get_tree().create_timer(0.1).timeout

	anim.modulate = Color(1, 1, 1, 1)

	is_hurt = false

	if health <= 0:
		var run_manager := get_tree().get_first_node_in_group("run_manager")

		if run_manager:
			if run_manager.has_method("handle_enemy_drop"):
				run_manager.handle_enemy_drop(run_room_id, persistent_id, enemy_role, global_position)
			run_manager.register_enemy_death(run_room_id, persistent_id)

		queue_free()
