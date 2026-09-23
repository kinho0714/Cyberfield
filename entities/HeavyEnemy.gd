class_name HeavyEnemy
extends "res://entities/Enemy.gd"

const HEAVY_PROJECTILE_SCENE := preload("res://entities/heavy_projectile.tscn")

enum RangedPhase { READY, WINDUP, RECOVERY }

@export var ranged_min_distance := 150.0
@export var ranged_max_distance := 460.0
@export var ranged_vertical_tolerance := 180.0
@export var shoot_windup := 0.85
@export var shoot_recovery := 0.60
@export var shoot_cooldown := 2.20
@export var projectile_speed := 300.0
@export var projectile_damage := CombatStats.HEAVY_PROJECTILE_BASE_DAMAGE

var ranged_phase := RangedPhase.READY
var ranged_phase_timer := 0.0
var shoot_cooldown_timer := 0.0
var locked_shot_direction := Vector2.RIGHT

@onready var muzzle := $Muzzle as Marker2D


func _ready() -> void:
	enemy_role = EnemyRole.HEAVY
	var temporary_visual := get_node_or_null("TempPixelVisual") as TempPixelVisual
	if temporary_visual != null:
		temporary_visual.set_character_kind(&"heavy")
	super._ready()


func _physics_process(delta: float) -> void:
	shoot_cooldown_timer = maxf(shoot_cooldown_timer - delta, 0.0)
	if ranged_phase != RangedPhase.READY:
		_update_ranged_attack(delta)
	super._physics_process(delta)


func configure_damage(melee_value: int, projectile_value: int = CombatStats.HEAVY_PROJECTILE_BASE_DAMAGE) -> void:
	attack_damage = maxi(melee_value, 1)
	projectile_damage = maxi(projectile_value, 1)


func _try_special_attack(target_offset: Vector2) -> bool:
	if ranged_phase != RangedPhase.READY:
		return true
	if shoot_cooldown_timer > 0.0 or is_hurt or knockback_timer > 0.0 or not _is_valid_target(player):
		return false
	var horizontal_distance := absf(target_offset.x)
	if horizontal_distance < ranged_min_distance or horizontal_distance > ranged_max_distance or absf(target_offset.y) > ranged_vertical_tolerance:
		return false
	_update_muzzle_facing()
	if not _has_shot_line_of_sight(player):
		return false
	_begin_ranged_attack()
	return true


func _begin_ranged_attack() -> void:
	ranged_phase = RangedPhase.WINDUP
	ranged_phase_timer = shoot_windup
	is_attacking = true
	attack_generation += 1
	attack_telegraph_active = true
	anim.modulate = attack_telegraph_color
	velocity.x = 0.0
	_update_muzzle_facing()
	locked_shot_direction = (player.global_position - muzzle.global_position).normalized()
	anim.play(&"attack")


func _update_ranged_attack(delta: float) -> void:
	velocity.x = 0.0
	if ranged_phase == RangedPhase.WINDUP:
		if not _is_valid_target(player) or is_hurt or knockback_timer > 0.0:
			_cancel_ranged_attack(true)
			return
		var target_offset := player.global_position - global_position
		if absf(target_offset.x) < ranged_min_distance or not _has_shot_line_of_sight(player):
			_cancel_ranged_attack(false)
			return
		ranged_phase_timer = maxf(ranged_phase_timer - delta, 0.0)
		if ranged_phase_timer <= 0.0:
			_fire_heavy_projectile()
			ranged_phase = RangedPhase.RECOVERY
			ranged_phase_timer = shoot_recovery
			attack_telegraph_active = false
			anim.modulate = _default_visual_modulate()
	elif ranged_phase == RangedPhase.RECOVERY:
		ranged_phase_timer = maxf(ranged_phase_timer - delta, 0.0)
		if ranged_phase_timer <= 0.0:
			ranged_phase = RangedPhase.READY
			is_attacking = false
			shoot_cooldown_timer = shoot_cooldown


func _fire_heavy_projectile() -> void:
	var projectile := HEAVY_PROJECTILE_SCENE.instantiate()
	projectile.shooter = self
	get_parent().add_child(projectile)
	projectile.setup(muzzle.global_position, locked_shot_direction, self, projectile_speed, projectile_damage)
	var lan_session := get_tree().get_first_node_in_group("lan_session")
	if lan_session != null and lan_session.is_host():
		projectile.network_id = lan_session.replicate_projectile_spawn(
			muzzle.global_position, locked_shot_direction, projectile_speed,
			projectile_damage, &"player", &"heavy"
		)


func _update_muzzle_facing() -> void:
	muzzle.position.x = -absf(muzzle.position.x) if anim.flip_h else absf(muzzle.position.x)


func _has_shot_line_of_sight(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(muzzle.global_position, target.global_position, 1, [self])
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == target


func _cancel_ranged_attack(apply_cooldown: bool) -> void:
	if ranged_phase == RangedPhase.READY:
		return
	ranged_phase = RangedPhase.READY
	ranged_phase_timer = 0.0
	is_attacking = false
	attack_telegraph_active = false
	anim.modulate = _default_visual_modulate()
	if apply_cooldown:
		shoot_cooldown_timer = maxf(shoot_cooldown_timer, shoot_cooldown * 0.35)


func take_damage(amount: int, knockback_direction: float = 0.0, knockback_multiplier: float = 1.0) -> void:
	_cancel_ranged_attack(true)
	super.take_damage(amount, knockback_direction, knockback_multiplier)
