extends CharacterBody2D

enum State { IDLE, REPOSITION, AIM, SHOOT, RECOVERY, MELEE_WINDUP, MELEE_IMPACT, MELEE_RECOVERY, HURT, DEAD }
enum EnemyRole { NORMAL, BOSS, ELITE }

const PROJECTILE_SCENE := preload("res://entities/ranged_projectile.tscn")
const GRAVITY := 980.0
const KNOCKBACK_FORCE := 260.0
const KNOCKBACK_UP := -100.0
const KNOCKBACK_DURATION := 0.18

@export var persistent_id: StringName
@export var required_for_completion := true
@export var enemy_role: EnemyRole = EnemyRole.NORMAL
@export var move_speed := 90.0
@export var melee_distance := 72.0
@export var ranged_distance := 88.0
@export var maximum_attack_range := 480.0
@export var aim_windup := 0.50
@export var aim_lock_before_shot := 0.12
@export var attack_recovery := 0.35
@export var attack_cooldown := 1.20
@export var cancelled_attack_cooldown := 0.35
@export var projectile_speed := 420.0
@export var projectile_damage := 2
@export var melee_horizontal_range := 42.0
@export var melee_vertical_range := 42.0
@export var melee_windup := 0.12
@export var melee_recovery := 0.15
@export var melee_cooldown := 0.20
@export var interrupted_attack_cooldown := 0.10
@export var melee_damage := 1
@export var target_switch_margin := 20.0
@export var patrol_radius := 64.0
@export_range(0.35, 0.50, 0.01) var patrol_speed_ratio := 0.42
@export var patrol_pause_min := 0.40
@export var patrol_pause_max := 1.20
@export var target_detection_range := 560.0
@export var separation_distance := 30.0

var run_room_id: StringName
var player: CharacterBody2D = null
var max_health := 7
var health := 7
var is_hurt := false
var is_attacking := false
var knockback_timer := 0.0
var attack_cooldown_timer := 0.0
var melee_cooldown_timer := 0.0
var state := State.IDLE
var state_timer := 0.0
var locked_direction := Vector2.RIGHT
var aim_locked := false
var shot_spawned := false
var combat_choice: StringName = &"melee"
var patrol_origin := Vector2.ZERO
var patrol_direction := 1.0
var patrol_pause_timer := 0.0
var patrol_rng := RandomNumberGenerator.new()

@onready var health_label: Label = $HealthLabel
@onready var visual: Node2D = $Visual
@onready var aim_line: Line2D = $AimLine
@onready var muzzle: Marker2D = $Visual/Muzzle
@onready var wall_check: RayCast2D = $WallCheck
@onready var floor_check: RayCast2D = $FloorCheck
@onready var melee_shape_cast: ShapeCast2D = $MeleeShapeCast


func _ready() -> void:
	patrol_origin = global_position
	patrol_rng.seed = _stable_hash(String(persistent_id))
	patrol_direction = -1.0 if patrol_rng.randi_range(0, 1) == 0 else 1.0
	patrol_pause_timer = _next_patrol_pause()
	aim_line.visible = false
	melee_shape_cast.enabled = false
	_update_health_label()


func configure_health(value: int) -> void:
	max_health = maxi(value, 1)
	health = max_health
	_update_health_label()


func is_boss() -> bool:
	return false


func is_elite() -> bool:
	return false


func get_ai_debug_text() -> String:
	var target_name: String = String(player.name) if _is_valid_target(player) else "none"
	return "%s state=%s target=%s" % [persistent_id, State.keys()[state], target_name]


func _physics_process(delta: float) -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if (run_manager and not run_manager.run_active) or (room_manager and room_manager.is_transitioning):
		_cancel_aim(false)
		_cancel_melee(false)
		melee_shape_cast.enabled = false
		aim_line.visible = false
		velocity = Vector2.ZERO
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0
	knockback_timer = maxf(knockback_timer - delta, 0.0)
	attack_cooldown_timer = maxf(attack_cooldown_timer - delta, 0.0)
	melee_cooldown_timer = maxf(melee_cooldown_timer - delta, 0.0)
	_select_active_player()
	if state == State.HURT:
		state_timer = maxf(state_timer - delta, 0.0)
		if state_timer <= 0.0:
			is_hurt = false
			visual.modulate = Color.WHITE
			state = State.IDLE
	elif state == State.AIM:
		_update_aim(delta)
	elif state == State.SHOOT:
		_fire_once()
	elif state == State.MELEE_WINDUP:
		_update_melee_windup(delta)
	elif state == State.MELEE_IMPACT:
		_apply_melee_impact()
	elif state == State.MELEE_RECOVERY:
		_update_melee_recovery(delta)
	elif state == State.RECOVERY:
		velocity.x = 0.0
		state_timer = maxf(state_timer - delta, 0.0)
		if state_timer <= 0.0:
			state = State.IDLE
	else:
		_update_movement_and_attack(delta)
	move_and_slide()


func _update_movement_and_attack(delta: float) -> void:
	if knockback_timer > 0.0 or is_hurt:
		return
	if not _is_valid_target(player):
		_update_patrol(delta)
		return
	var offset := player.global_position - global_position
	_face_direction(signf(offset.x))
	velocity.x = 0.0
	state = State.REPOSITION
	_update_combat_choice(offset)
	if combat_choice == &"melee":
		if melee_cooldown_timer <= 0.0:
			_begin_melee()
		return
	var distance := offset.length()
	if distance <= maximum_attack_range and _has_line_of_sight(player):
		if attack_cooldown_timer <= 0.0:
			_begin_aim()
		return
	# Reposition only toward the target when a shot cannot be established.
	velocity.x = _safe_horizontal_velocity(signf(offset.x), move_speed * 0.75)


func _update_combat_choice(offset: Vector2) -> void:
	var horizontal_distance := absf(offset.x)
	var vertically_reachable := absf(offset.y) <= melee_vertical_range
	if vertically_reachable and horizontal_distance <= melee_distance:
		if (state == State.AIM or state == State.SHOOT) and combat_choice != &"melee":
			_cancel_aim(false)
		combat_choice = &"melee"
	elif not vertically_reachable or horizontal_distance > ranged_distance:
		combat_choice = &"ranged"


func _begin_melee() -> void:
	if is_attacking or state == State.AIM or state == State.SHOOT or state == State.RECOVERY:
		return
	state = State.MELEE_WINDUP
	is_attacking = true
	velocity.x = 0.0
	state_timer = melee_windup
	visual.modulate = Color(1.0, 0.45, 0.85, 1.0)


func _update_melee_windup(delta: float) -> void:
	velocity.x = 0.0
	if not _is_valid_target(player) or knockback_timer > 0.0 or is_hurt:
		_cancel_melee(true)
		return
	state_timer = maxf(state_timer - delta, 0.0)
	if state_timer <= 0.0:
		state = State.MELEE_IMPACT


func _apply_melee_impact() -> void:
	velocity.x = 0.0
	if not _is_valid_target(player) or knockback_timer > 0.0 or is_hurt:
		_cancel_melee(true)
		return
	var offset := player.global_position - global_position
	melee_shape_cast.target_position = Vector2(clampf(offset.x, -melee_horizontal_range, melee_horizontal_range), clampf(offset.y, -melee_vertical_range, melee_vertical_range))
	melee_shape_cast.enabled = true
	melee_shape_cast.force_shapecast_update()
	if melee_shape_cast.is_colliding():
		for index in melee_shape_cast.get_collision_count():
			var body := melee_shape_cast.get_collider(index)
			if body is Node and body.is_in_group("player") and not body.is_downed:
				body.take_damage(melee_damage, signf(body.global_position.x - global_position.x))
				break
			elif body is PhysicsBody2D:
				break
	melee_shape_cast.enabled = false
	state = State.MELEE_RECOVERY
	state_timer = melee_recovery
	visual.modulate = Color(0.72, 0.38, 0.78, 1.0)


func _update_melee_recovery(delta: float) -> void:
	velocity.x = 0.0
	state_timer = maxf(state_timer - delta, 0.0)
	if state_timer <= 0.0:
		is_attacking = false
		melee_cooldown_timer = melee_cooldown
		visual.modulate = Color.WHITE
		state = State.IDLE


func _cancel_melee(apply_cooldown: bool) -> void:
	if state != State.MELEE_WINDUP and state != State.MELEE_IMPACT and state != State.MELEE_RECOVERY:
		return
	is_attacking = false
	melee_shape_cast.enabled = false
	visual.modulate = Color.WHITE
	if apply_cooldown:
		melee_cooldown_timer = maxf(melee_cooldown_timer, interrupted_attack_cooldown)
	if state != State.HURT and state != State.DEAD:
		state = State.IDLE


func _begin_aim() -> void:
	if is_attacking or state == State.MELEE_WINDUP or state == State.MELEE_IMPACT or state == State.MELEE_RECOVERY:
		return
	state = State.AIM
	is_attacking = true
	state_timer = aim_windup
	aim_locked = false
	shot_spawned = false
	velocity.x = 0.0
	aim_line.visible = true
	_update_aim_line((player.global_position - muzzle.global_position).normalized())


func _update_aim(delta: float) -> void:
	velocity.x = 0.0
	if not _is_valid_target(player):
		_cancel_aim(true)
		return
	var offset := player.global_position - global_position
	if absf(offset.x) <= melee_distance and absf(offset.y) <= melee_vertical_range:
		combat_choice = &"melee"
		_cancel_aim(false)
		if melee_cooldown_timer <= 0.0:
			_begin_melee()
		return
	if not _has_line_of_sight(player):
		_cancel_aim(true)
		return
	state_timer = maxf(state_timer - delta, 0.0)
	if not aim_locked:
		locked_direction = (player.global_position - muzzle.global_position).normalized()
		if state_timer <= aim_lock_before_shot:
			aim_locked = true
	_update_aim_line(locked_direction)
	if state_timer <= 0.0:
		state = State.SHOOT


func _fire_once() -> void:
	velocity.x = 0.0
	if shot_spawned:
		return
	shot_spawned = true
	aim_line.visible = false
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.shooter = self
	get_parent().add_child(projectile)
	projectile.setup(muzzle.global_position, locked_direction, self, projectile_speed, projectile_damage)
	is_attacking = false
	attack_cooldown_timer = attack_cooldown
	state = State.RECOVERY
	state_timer = attack_recovery


func _cancel_aim(apply_cooldown: bool) -> void:
	if state == State.AIM or state == State.SHOOT:
		is_attacking = false
		shot_spawned = false
		if apply_cooldown:
			attack_cooldown_timer = maxf(attack_cooldown_timer, cancelled_attack_cooldown)
	aim_line.visible = false
	aim_locked = false
	if state != State.HURT and state != State.DEAD:
		state = State.IDLE


func _update_aim_line(direction: Vector2) -> void:
	aim_line.points = PackedVector2Array([to_local(muzzle.global_position), to_local(muzzle.global_position + direction * maximum_attack_range)])


func _has_line_of_sight(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(muzzle.global_position, target.global_position, 1, [self])
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == target


func _select_active_player() -> void:
	var nearest: CharacterBody2D = null
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("player"):
		if not _is_valid_target(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= target_detection_range and distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if _is_valid_target(player):
		var current_distance := global_position.distance_to(player.global_position)
		if current_distance <= target_detection_range and current_distance <= nearest_distance + target_switch_margin:
			return
	if player != nearest:
		if state == State.AIM or state == State.SHOOT:
			_cancel_aim(true)
		_cancel_melee(true)
	player = nearest


func _is_valid_target(candidate: Node) -> bool:
	return is_instance_valid(candidate) and candidate.is_inside_tree() and candidate.is_in_group("player") and not candidate.is_downed and candidate.visible


func _update_patrol(delta: float) -> void:
	state = State.IDLE
	var origin_offset := patrol_origin.x - global_position.x
	if absf(origin_offset) > patrol_radius:
		patrol_direction = signf(origin_offset)
		patrol_pause_timer = 0.0
	elif patrol_pause_timer > 0.0:
		patrol_pause_timer = maxf(patrol_pause_timer - delta, 0.0)
		velocity.x = 0.0
		return
	if absf(global_position.x + patrol_direction * 4.0 - patrol_origin.x) > patrol_radius or not _can_move_horizontally(patrol_direction):
		patrol_direction *= -1.0
		patrol_pause_timer = _next_patrol_pause()
		velocity.x = 0.0
		return
	velocity.x = _safe_horizontal_velocity(patrol_direction, move_speed * patrol_speed_ratio)
	_face_direction(signf(velocity.x))


func _safe_horizontal_velocity(direction: float, speed: float) -> float:
	if direction == 0.0 or not _can_move_horizontally(direction):
		return 0.0
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not is_instance_valid(other) or not other is Node2D:
			continue
		var offset: Vector2 = global_position - other.global_position
		if absf(offset.y) <= 28.0 and absf(offset.x) < separation_distance and absf(offset.x) > 0.01 and signf(offset.x) == direction:
			return direction * speed * 0.8
	return direction * speed


func _can_move_horizontally(direction: float) -> bool:
	wall_check.target_position = Vector2(direction * 22.0, 0.0)
	wall_check.force_raycast_update()
	floor_check.position.x = direction * 15.0
	floor_check.force_raycast_update()
	return not wall_check.is_colliding() and floor_check.is_colliding()


func _face_direction(direction: float) -> void:
	if direction == 0.0:
		return
	visual.scale.x = absf(visual.scale.x) * direction


func take_damage(amount: int, knockback_direction: float = 0.0, knockback_multiplier: float = 1.0) -> void:
	if is_hurt or state == State.DEAD:
		return
	health = maxi(health - amount, 0)
	_cancel_aim(true)
	_cancel_melee(true)
	_update_health_label()
	if knockback_direction != 0.0:
		velocity.x = knockback_direction * KNOCKBACK_FORCE * knockback_multiplier
		velocity.y = KNOCKBACK_UP * knockback_multiplier
		knockback_timer = KNOCKBACK_DURATION
	is_hurt = true
	state = State.HURT
	state_timer = 0.10
	visual.modulate = Color(1, 1, 1, 0.5)
	if health <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	aim_line.visible = false
	melee_shape_cast.enabled = false
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		if run_manager.has_method("handle_enemy_drop"):
			run_manager.handle_enemy_drop(run_room_id, persistent_id, enemy_role, global_position)
		run_manager.register_enemy_death(run_room_id, persistent_id)
	queue_free()


func _update_health_label() -> void:
	if is_instance_valid(health_label):
		health_label.text = "HP: %d/%d" % [health, max_health]


func _next_patrol_pause() -> float:
	return patrol_rng.randf_range(minf(patrol_pause_min, patrol_pause_max), maxf(patrol_pause_min, patrol_pause_max))


func _stable_hash(value: String) -> int:
	var result := 2166136261
	for byte in value.to_utf8_buffer():
		result = int((result ^ byte) * 16777619) & 0x7fffffff
	return result
