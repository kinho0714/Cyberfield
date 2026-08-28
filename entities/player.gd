extends CharacterBody2D

const RANGED_PROJECTILE_SCENE := preload("res://entities/ranged_projectile.tscn")

signal downed_state_changed(is_now_downed: bool)
signal revive_progress_changed(progress: float)

@export var participant_id: StringName = &"player_1"
@export_enum("p1", "p2") var input_profile := "p1"
@export var joypad_device_id := -1
@export_range(0.5, 10.0, 0.1) var revive_duration := 2.0
@export_range(0.1, 1.0, 0.05) var revive_health_ratio := 0.4
@export_range(0.1, 5.0, 0.1) var revived_invulnerability := 1.5
@export var revive_range := 52.0
@export_range(0.1, 2.0, 0.05) var combo_end_recovery := 0.20
@export_range(0.05, 0.3, 0.01) var attack_input_buffer_duration := 0.18
@export_range(0.05, 0.5, 0.01) var dash_cancel_window := 0.18
@export_range(0.1, 1.0, 0.01) var post_dash_attack_window := 0.30
@export_range(0.05, 0.5, 0.01) var dash_invulnerability_duration := 0.12
@export_range(0.1, 2.0, 0.05) var heal_duration := 0.6
@export_range(1, 10, 1) var max_heal_doses := 4

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_label: Label = $HealthLabel
@onready var attack_shape_cast: ShapeCast2D = $AttackShapeCast
@onready var ground_slam_shape_cast: ShapeCast2D = $GroundSlamShapeCast
@onready var interaction_area: Area2D = $InteractionArea
@onready var downed_label: Label = $DownedLabel
@onready var revive_bar: ProgressBar = $ReviveBar

const SPEED = 220.0
const JUMP_VELOCITY = -400.0
const DASH_SPEED = 600.0
const DASH_DURATION = 0.15
const GROUND_SLAM_SPEED = 900.0
const GROUND_SLAM_DOUBLE_TAP_WINDOW = 0.3

const MAX_JUMPS = 2

const WALL_SLIDE_SPEED = 100.0
const WALL_CLIMB_SPEED = 80.0
const WALL_CLIMB_DURATION = 2.0

const ATTACK_HIT_DELAY = 0.1
const ATTACK_DURATION = 0.2
const MAX_COMBO_ATTACKS = 5
const COMBO_WINDOW = 0.35

const KNOCKBACK_FORCE = 300.0
const KNOCKBACK_UP = -120.0
const KNOCKBACK_DURATION = 0.18
const FINISHER_KNOCKBACK_MULTIPLIER := 1.5
const DROP_THROUGH_COOLDOWN := 0.18

var is_attacking = false
var is_ground_slamming = false
var base_max_hp := CombatStats.PLAYER_BASE_MAX_HP
var base_melee_damage := CombatStats.PLAYER_BASE_MELEE_DAMAGE
var health := CombatStats.PLAYER_BASE_MAX_HP
var max_health := CombatStats.PLAYER_BASE_MAX_HP
var current_hp: int:
	get:
		return health
	set(value):
		health = value
var max_hp: int:
	get:
		return max_health
	set(value):
		max_health = value
var is_hurt = false

var jumps_left = MAX_JUMPS
var knockback_timer = 0.0
var dash_timer = 0.0
var down_tap_timer = 0.0
var combo_timer = 0.0
var combo_step = 0
var combo_end_recovery_timer := 0.0
var attack_input_buffer_timer := 0.0
var dash_cancel_timer := 0.0
var post_dash_combo_timer := 0.0
var total_combo_hits := 0
var last_attack_hit := false
var attack_generation := 0
var wall_climb_time = WALL_CLIMB_DURATION
var max_wall_climb_duration := WALL_CLIMB_DURATION
var wall_jump_available = true
var input_enabled = true
var is_downed := false
var is_invulnerable := false
var invulnerability_timer := 0.0
var dash_invulnerability_timer := 0.0
var heal_doses := 4
var is_healing := false
var heal_progress := 0.0
var intellect := 0
var health_attribute := 0
var strength := 0
var acquired_upgrades: Dictionary = {}
var healing_bonus := 0.0
var damage_resistance := 0.0
var knockback_bonus := 0.0
var slam_damage_bonus := 0.0
var tech_damage_bonus := 0.0
var dash_duration_bonus := 0.0
var drop_through_timer := 0.0
var equipped_weapons: Array[StringName] = [&"scrap_blade", &""]
var active_weapon_slot := 0
var weapon_cooldowns: Array[float] = [0.0, 0.0]
var _dash_exceptions: Array[Node] = []
var revive_progress := 0.0
var _revive_target: CharacterBody2D = null
var network_prediction_only := false
var network_remote_replica := false
var network_target_position := Vector2.ZERO
var network_target_velocity := Vector2.ZERO


func _ready() -> void:
	if input_profile == "p2":
		LocalCoopInput.ensure_player_two_actions(joypad_device_id)
	attack_shape_cast.enabled = true
	ground_slam_shape_cast.enabled = true
	heal_doses = max_heal_doses
	_update_health_label()
	call_deferred("_register_participant")


func _process(delta: float) -> void:
	if network_remote_replica:
		var interpolation_weight := 1.0 - exp(-18.0 * delta)
		global_position = global_position.lerp(network_target_position, interpolation_weight)
		velocity = network_target_velocity
	if invulnerability_timer > 0.0:
		invulnerability_timer = max(invulnerability_timer - delta, 0.0)

		if invulnerability_timer <= 0.0:
			is_invulnerable = false
	if dash_invulnerability_timer > 0.0:
		dash_invulnerability_timer = maxf(dash_invulnerability_timer - delta, 0.0)
	if is_healing:
		heal_progress = minf(heal_progress + delta, heal_duration)
		if heal_progress >= heal_duration:
			_complete_heal()

	if is_downed or not input_enabled:
		_cancel_revive_attempt()
		return
	if Input.is_action_just_pressed(_action(&"heal")):
		_start_heal()

	if network_prediction_only:
		return
	var target := _nearest_downed_ally()

	if target and Input.is_action_pressed(_action(&"interact")):
		_revive_target = target
		target.receive_revive_progress(self, delta)
	else:
		_cancel_revive_attempt()


func _physics_process(delta: float) -> void:
	if is_downed:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

		if not is_on_floor():
			velocity += get_gravity() * delta

		move_and_slide()
		return

	if not input_enabled:
		velocity = Vector2.ZERO
		return

	var direction: float = Input.get_axis(_action(&"left"), _action(&"right"))
	var wall_normal: Vector2 = get_wall_normal() if is_on_wall() else Vector2.ZERO
	var touching_wall_in_air: bool = not is_on_floor() and wall_normal.x != 0.0
	var holding_against_wall: bool = (
		direction != 0.0
		and sign(direction) == -sign(wall_normal.x)
	)
	var did_wall_jump := false
	drop_through_timer = maxf(drop_through_timer - delta, 0.0)
	for slot in 2:
		weapon_cooldowns[slot] = maxf(weapon_cooldowns[slot] - delta, 0.0)

	# A press made during an attack represents the next combo intent. Do not let
	# its short post-lock buffer expire while the current attack coroutine still
	# owns the attack state; it starts counting down once that state is released.
	if not is_attacking:
		attack_input_buffer_timer = maxf(attack_input_buffer_timer - delta, 0.0)
	var requested_attack_slot := _requested_attack_slot()
	if requested_attack_slot >= 0 and not is_healing and not is_ground_slamming:
		active_weapon_slot = requested_attack_slot
		attack_input_buffer_timer = attack_input_buffer_duration

	# Add gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Knockback timer.
	if knockback_timer > 0:
		knockback_timer -= delta

	if dash_timer > 0:
		dash_timer = maxf(dash_timer - delta, 0.0)
		if dash_timer <= 0.0:
			_end_dash()
	if dash_cancel_timer > 0.0:
		dash_cancel_timer = maxf(dash_cancel_timer - delta, 0.0)
	if post_dash_combo_timer > 0.0:
		post_dash_combo_timer = maxf(post_dash_combo_timer - delta, 0.0)
		if post_dash_combo_timer <= 0.0 and not is_attacking:
			_reset_combo()

	if down_tap_timer > 0:
		down_tap_timer = max(down_tap_timer - delta, 0.0)

	if combo_timer > 0.0 and not is_attacking:
		combo_timer = max(combo_timer - delta, 0.0)

		if combo_timer <= 0.0:
			_reset_combo()

	if combo_end_recovery_timer > 0.0:
		combo_end_recovery_timer = maxf(combo_end_recovery_timer - delta, 0.0)

		if combo_end_recovery_timer <= 0.0 and not is_downed:
			attack_shape_cast.enabled = true
			_reset_combo()

	if not network_prediction_only and Input.is_action_just_pressed(_action(&"interact")) and _nearest_downed_ally() == null:
		interact_with_nearest()

	# Reset jumps and wall resources only when touching the floor.
	if is_on_floor():
		jumps_left = MAX_JUMPS
		wall_climb_time = max_wall_climb_duration
		wall_jump_available = true
		is_ground_slamming = false
		down_tap_timer = 0.0

	# Require two separate down presses while airborne to start a ground slam.
	if (
		Input.is_action_just_pressed(_action(&"down"))
		and not is_on_floor()
		and not is_ground_slamming
		and not is_attacking
		and not is_healing
		and knockback_timer <= 0
		and dash_timer <= 0
	):
		if down_tap_timer > 0.0:
			down_tap_timer = 0.0
			is_ground_slamming = true
			attack_input_buffer_timer = 0.0
		else:
			down_tap_timer = GROUND_SLAM_DOUBLE_TAP_WINDOW

	if is_ground_slamming:
		velocity.x = 0.0
		velocity.y = GROUND_SLAM_SPEED

	var jump_pressed := Input.is_action_just_pressed(_action(&"jump"))
	if jump_pressed and Input.is_action_pressed(_action(&"down")) and _can_drop_through_platform():
		position.y += 10.0
		velocity.y = 90.0
		drop_through_timer = DROP_THROUGH_COOLDOWN
		jump_pressed = false
	# Handle wall jump before the regular jump + double jump.
	if jump_pressed and not is_attacking and not is_ground_slamming and knockback_timer <= 0:
		if touching_wall_in_air:
			if wall_jump_available:
				velocity.y = JUMP_VELOCITY
				wall_jump_available = false
				did_wall_jump = true
		elif jumps_left > 0:
			velocity.y = JUMP_VELOCITY
			jumps_left -= 1

	# Consume one buffered press as soon as the existing attack state allows it.
	if attack_input_buffer_timer > 0.0 and _can_start_attack():
		attack_input_buffer_timer = 0.0
		attack(active_weapon_slot)

	# Only control horizontal movement when not being knocked back.
	if knockback_timer <= 0 and dash_timer <= 0 and not is_ground_slamming:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	# Handle facing direction.
	if direction > 0:
		anim.flip_h = false
		attack_shape_cast.target_position.x = 30.0

	elif direction < 0:
		anim.flip_h = true
		attack_shape_cast.target_position.x = -30.0

	if Input.is_action_just_pressed(_action(&"dash")) and dash_timer <= 0 and knockback_timer <= 0 and not is_ground_slamming and not is_healing and (combo_end_recovery_timer <= 0.0 or dash_cancel_timer > 0.0):
		if not is_attacking or dash_cancel_timer > 0.0:
			_start_dash()
	if Input.is_action_just_pressed(_action(&"switch_weapon")):
		switch_weapon()

	# Climb while holding toward a wall, then slide once climbing is unavailable.
	if touching_wall_in_air and knockback_timer <= 0 and dash_timer <= 0 and not is_ground_slamming and not did_wall_jump:
		if holding_against_wall and wall_climb_time > 0.0 and not is_attacking:
			velocity.y = -WALL_CLIMB_SPEED
			wall_climb_time = max(wall_climb_time - delta, 0.0)
		elif velocity.y > WALL_SLIDE_SPEED:
			velocity.y = WALL_SLIDE_SPEED

	# Handle animations.
	if not is_attacking:
		if is_on_floor():
			if direction != 0:
				anim.play("walk")
			else:
				anim.play("idle")
		else:
			anim.play("jump")

	move_and_slide()

	if is_ground_slamming and is_on_floor():
		ground_slam_impact()
		is_ground_slamming = false
		down_tap_timer = 0.0


func attack(slot: int = -1) -> void:
	var requested_slot := active_weapon_slot if slot < 0 else clampi(slot, 0, 1)
	var weapon_id := equipped_weapons[requested_slot]
	if weapon_id.is_empty() or weapon_cooldowns[requested_slot] > 0.0:
		return
	active_weapon_slot = requested_slot
	var definition := WeaponCatalog.get_definition(weapon_id)
	if StringName(definition.get("type", &"melee")) == &"ranged":
		_fire_ranged_weapon(requested_slot, definition)
		return
	if is_attacking or combo_end_recovery_timer > 0.0 or is_downed or is_healing or not input_enabled:
		return
	weapon_cooldowns[requested_slot] = float(definition.get("cooldown", ATTACK_DURATION))

	is_attacking = true
	attack_generation += 1
	var this_attack := attack_generation

	if post_dash_combo_timer > 0.0:
		combo_step = 1
		post_dash_combo_timer = 0.0
	elif combo_timer > 0.0 and combo_step > 0:
		combo_step += 1
	else:
		combo_step = 1

	total_combo_hits += 1
	last_attack_hit = false
	combo_timer = 0.0
	attack_shape_cast.enabled = true

	anim.play("attack")

	await get_tree().create_timer(ATTACK_HIT_DELAY).timeout

	if not input_enabled or is_downed or this_attack != attack_generation:
		is_attacking = false
		return

	attack_shape_cast.force_shapecast_update()

	if not network_prediction_only and attack_shape_cast.is_colliding():
		for i in attack_shape_cast.get_collision_count():
			var body = attack_shape_cast.get_collider(i)

			if body.is_in_group("enemy"):
				var knockback_direction = sign(
					body.global_position.x - global_position.x
				)

				last_attack_hit = true
				var knockback_multiplier := (FINISHER_KNOCKBACK_MULTIPLIER if combo_step == MAX_COMBO_ATTACKS else 1.0) * get_weapon_knockback() * (1.0 + knockback_bonus)
				body.take_damage(get_melee_damage(requested_slot), knockback_direction, knockback_multiplier)
				break
	if combo_step == MAX_COMBO_ATTACKS and last_attack_hit:
		dash_cancel_timer = dash_cancel_window

	await get_tree().create_timer(ATTACK_DURATION).timeout

	if this_attack != attack_generation:
		return

	is_attacking = false

	if combo_step >= MAX_COMBO_ATTACKS:
		combo_timer = 0.0
		combo_end_recovery_timer = combo_end_recovery
		attack_shape_cast.enabled = false
		if not last_attack_hit:
			_reset_combo(false)
	else:
		combo_timer = COMBO_WINDOW


func _start_dash() -> void:
	var is_combo_cancel := dash_cancel_timer > 0.0 and last_attack_hit and combo_step == MAX_COMBO_ATTACKS
	if is_combo_cancel:
		attack_generation += 1
		is_attacking = false
		combo_step = 0
		combo_timer = 0.0
		combo_end_recovery_timer = 0.0
		dash_cancel_timer = 0.0
		post_dash_combo_timer = post_dash_attack_window
	else:
		_reset_combo()
	var dash_direction := -1.0 if anim.flip_h else 1.0
	velocity.x = dash_direction * DASH_SPEED
	dash_timer = DASH_DURATION * (1.0 + dash_duration_bonus)
	dash_invulnerability_timer = dash_invulnerability_duration
	_dash_exceptions.clear()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is PhysicsBody2D:
			add_collision_exception_with(enemy)
			_dash_exceptions.append(enemy)


func _end_dash() -> void:
	for enemy in _dash_exceptions:
		if is_instance_valid(enemy):
			remove_collision_exception_with(enemy)
	_dash_exceptions.clear()


func _reset_combo(clear_recovery := true) -> void:
	combo_timer = 0.0
	combo_step = 0
	dash_cancel_timer = 0.0
	post_dash_combo_timer = 0.0
	total_combo_hits = 0
	last_attack_hit = false
	if clear_recovery:
		combo_end_recovery_timer = 0.0


func _fire_ranged_weapon(slot: int, definition: Dictionary) -> void:
	if is_downed or is_healing or not input_enabled or network_prediction_only:
		return
	weapon_cooldowns[slot] = float(definition.get("cooldown", 0.42))
	var player_anim := anim if anim != null else get_node("AnimatedSprite2D") as AnimatedSprite2D
	var direction := Vector2.LEFT if player_anim.flip_h else Vector2.RIGHT
	var origin := global_position + Vector2(direction.x * 28.0, -8.0)
	var projectile := RANGED_PROJECTILE_SCENE.instantiate()
	get_parent().add_child(projectile)
	var damage := maxi(1, roundi(float(definition.get("damage", 34)) * (1.0 + 0.10 * intellect + tech_damage_bonus)))
	projectile.setup(origin, direction, self, 620.0, damage, &"enemy")
	var lan_session := get_tree().get_first_node_in_group("lan_session") if is_inside_tree() else null
	if lan_session != null:
		projectile.network_id = lan_session.replicate_projectile_spawn(origin, direction, 620.0, damage, &"enemy")


func get_melee_damage(slot: int = -1) -> int:
	var weapon_id := get_active_weapon_id() if slot < 0 else equipped_weapons[clampi(slot, 0, 1)]
	var weapon_damage := int(WeaponCatalog.get_definition(weapon_id).get("damage", CombatStats.PLAYER_BASE_MELEE_DAMAGE))
	return maxi(1, roundi(weapon_damage * (1.0 + CombatStats.STRENGTH_DAMAGE_PER_LEVEL * strength)))


func get_slam_damage() -> int:
	return maxi(1, roundi(CombatStats.player_slam_damage(strength) * (1.0 + slam_damage_bonus)))


func get_weapon_knockback() -> float:
	return float(WeaponCatalog.get_definition(get_active_weapon_id()).get("knockback", 1.0))


func get_active_weapon_id() -> StringName:
	return equipped_weapons[active_weapon_slot] if not equipped_weapons[active_weapon_slot].is_empty() else &"scrap_blade"


func equip_weapon(weapon_id: StringName, replace_slot: int = -1) -> bool:
	if weapon_id.is_empty() or not WeaponCatalog.WEAPONS.has(weapon_id):
		return false
	if equipped_weapons.has(weapon_id):
		return false
	var target_slot := replace_slot
	if target_slot < 0:
		target_slot = equipped_weapons.find(&"")
	if target_slot < 0:
		target_slot = active_weapon_slot
	target_slot = clampi(target_slot, 0, 1)
	equipped_weapons[target_slot] = weapon_id
	active_weapon_slot = target_slot
	_sync_progress()
	return true


func switch_weapon() -> void:
	var other_slot := 1 - active_weapon_slot
	if not equipped_weapons[other_slot].is_empty():
		active_weapon_slot = other_slot
		_sync_progress()


func _can_drop_through_platform() -> bool:
	if drop_through_timer > 0.0 or not is_on_floor():
		return false
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider() as Node
		if collider != null and collider.get_meta("collision_role", &"") == &"one_way_platform":
			return true
	return false


func add_attribute(attribute: StringName) -> bool:
	if is_downed:
		return false
	match attribute:
		&"intellect":
			intellect += 1
			max_wall_climb_duration = WALL_CLIMB_DURATION + intellect * 0.5
			wall_climb_time = minf(wall_climb_time, max_wall_climb_duration)
		&"health":
			var previous_max_health := max_health
			health_attribute += 1
			max_health = CombatStats.player_max_hp(health_attribute)
			# Preserve missing HP instead of turning an attribute choice into a full heal.
			health = mini(max_health, health + max_health - previous_max_health)
			_update_health_label()
		&"strength":
			strength += 1
		_:
			return false
	_sync_progress()
	return true


func add_upgrade(upgrade_id: StringName) -> bool:
	var definition := AttributeUpgradeCatalog.get_definition(upgrade_id)
	if definition.is_empty() or is_downed:
		return false
	var category := StringName(definition.category)
	acquired_upgrades[upgrade_id] = int(acquired_upgrades.get(upgrade_id, 0)) + 1
	match StringName(definition.key):
		&"max_health": return add_attribute(&"health")
		&"healing": healing_bonus += float(definition.magnitude)
		&"resistance": damage_resistance = minf(damage_resistance + float(definition.magnitude), 0.30)
		&"melee_damage": pass
		&"knockback": knockback_bonus += float(definition.magnitude)
		&"slam_damage": slam_damage_bonus += float(definition.magnitude)
		&"climb_stamina":
			max_wall_climb_duration += float(definition.magnitude)
		&"dash_duration":
			dash_duration_bonus += float(definition.magnitude)
		&"tech_damage":
			tech_damage_bonus += float(definition.magnitude)
		_: return false
	if category == &"health": health_attribute += 1
	elif category == &"strength": strength += 1
	elif category == &"intellect": intellect += 1
	_sync_progress()
	return true


func _start_heal() -> void:
	if is_healing or is_attacking or is_ground_slamming or dash_timer > 0.0 or is_downed or not input_enabled or heal_doses <= 0 or health >= max_health:
		return
	is_healing = true
	heal_progress = 0.0
	_reset_combo()
	is_attacking = false
	attack_generation += 1


func _complete_heal() -> void:
	if not is_healing:
		return
	health = mini(max_health, health + roundi(CombatStats.heal_amount(max_health) * (1.0 + healing_bonus)))
	heal_doses -= 1
	is_healing = false
	heal_progress = 0.0
	_update_health_label()
	_sync_progress()


func _cancel_heal() -> void:
	is_healing = false
	heal_progress = 0.0


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		attack_input_buffer_timer = 0.0
		_cancel_heal()
		_end_dash()
		dash_invulnerability_timer = 0.0
		attack_generation += 1
		velocity = Vector2.ZERO
		is_attacking = false
		is_ground_slamming = false
		dash_timer = 0.0
		_reset_combo()
		attack_shape_cast.enabled = not is_downed


func apply_bandage(heal_ratio: float = 0.10) -> bool:
	if is_downed or health >= max_health:
		return false
	health = mini(max_health, health + maxi(1, roundi(max_health * heal_ratio)))
	_update_health_label()
	return true


func reset_for_new_run() -> void:
	intellect = 0
	health_attribute = 0
	strength = 0
	acquired_upgrades.clear()
	healing_bonus = 0.0
	damage_resistance = 0.0
	knockback_bonus = 0.0
	slam_damage_bonus = 0.0
	tech_damage_bonus = 0.0
	dash_duration_bonus = 0.0
	equipped_weapons = [&"scrap_blade", &""]
	active_weapon_slot = 0
	weapon_cooldowns = [0.0, 0.0]
	max_wall_climb_duration = WALL_CLIMB_DURATION
	max_health = CombatStats.PLAYER_BASE_MAX_HP
	health = max_health
	heal_doses = max_heal_doses
	is_healing = false
	heal_progress = 0.0
	_update_health_label()
	velocity = Vector2.ZERO
	is_attacking = false
	is_ground_slamming = false
	is_hurt = false
	is_downed = false
	is_invulnerable = false
	invulnerability_timer = 0.0
	revive_progress = 0.0
	jumps_left = MAX_JUMPS
	knockback_timer = 0.0
	dash_timer = 0.0
	down_tap_timer = 0.0
	attack_input_buffer_timer = 0.0
	_reset_combo()
	attack_generation += 1
	wall_climb_time = max_wall_climb_duration
	wall_jump_available = true
	attack_shape_cast.enabled = true
	ground_slam_shape_cast.enabled = true
	anim.modulate = Color(0.45, 0.8, 1.0, 1.0) if input_profile == "p2" else Color.WHITE
	anim.play("idle")
	downed_label.visible = false
	revive_bar.visible = false
	_revive_target = null
	_update_participant_state(true)
	_sync_progress()


func ground_slam_impact() -> void:
	print("GROUND SLAM IMPACT")
	if network_prediction_only:
		return

	ground_slam_shape_cast.force_shapecast_update()

	var hit_enemies: Array[Node2D] = []

	for i in ground_slam_shape_cast.get_collision_count():
		var body = ground_slam_shape_cast.get_collider(i)

		if body is Node2D and body.is_in_group("enemy") and not hit_enemies.has(body):
			hit_enemies.append(body)

			var knockback_direction := -1.0 if body.global_position.x < global_position.x else 1.0

			body.take_damage(get_slam_damage(), knockback_direction)


func interact_with_nearest() -> void:
	var nearest_interactable: Area2D = null
	var nearest_distance := INF

	for area in interaction_area.get_overlapping_areas():
		if area.is_in_group("interactable") and area.has_method("interact"):
			var distance := global_position.distance_squared_to(area.global_position)

			if distance < nearest_distance:
				nearest_distance = distance
				nearest_interactable = area

	if nearest_interactable:
			nearest_interactable.interact(self)


func _action(base_action: StringName) -> StringName:
	if input_profile == "p2":
		return StringName("p2_" + String(base_action))

	return base_action


func _attack_just_pressed() -> bool:
	if not Input.is_action_just_pressed(_action(&"attack")):
		return false

	# Desktop mouse clicks over UI must stay blocked. On mobile, the held virtual
	# joystick is a hovered Control and must not discard a separate attack touch.
	if input_profile == "p1" and not OS.has_feature("mobile") and get_viewport().gui_get_hovered_control() != null:
		return false

	return true


func _requested_attack_slot() -> int:
	if Input.is_action_just_pressed(_action(&"attack_slot_2")):
		return 1
	if Input.is_action_just_pressed(_action(&"attack_slot_1")) or _attack_just_pressed():
		return 0
	return -1


func _can_start_attack() -> bool:
	return (
		not is_attacking
		and not is_healing
		and not is_ground_slamming
		and dash_timer <= 0.0
		and combo_end_recovery_timer <= 0.0
	)


func get_network_state() -> Dictionary:
	return {
		"participant_id": participant_id,
		"position": global_position,
		"velocity": velocity,
		"flip_h": anim.flip_h,
		"animation": anim.animation,
		"animation_frame": anim.frame,
		"health": health,
		"max_health": max_health,
		"is_downed": is_downed,
		"is_attacking": is_attacking,
		"intellect": intellect,
		"health_attribute": health_attribute,
		"strength": strength,
		"heal_doses": heal_doses,
		"equipped_weapons": equipped_weapons.duplicate(),
		"active_weapon_slot": active_weapon_slot,
		"acquired_upgrades": acquired_upgrades.duplicate(true),
	}


func apply_network_state(state: Dictionary, predicted_local: bool = false) -> void:
	var network_position: Vector2 = state.get("position", global_position)
	var network_velocity: Vector2 = state.get("velocity", velocity)
	if predicted_local:
		var prediction_error := global_position.distance_to(network_position)
		if prediction_error >= 160.0:
			global_position = network_position
			velocity = network_velocity
		elif prediction_error >= 3.0:
			global_position = global_position.lerp(network_position, 0.22)
	else:
		network_target_position = network_position
		network_target_velocity = network_velocity
	anim.flip_h = bool(state.get("flip_h", anim.flip_h))
	var network_animation := StringName(state.get("animation", anim.animation))
	if anim.sprite_frames.has_animation(network_animation):
		anim.animation = network_animation
		anim.frame = clampi(int(state.get("animation_frame", anim.frame)), 0, maxi(anim.sprite_frames.get_frame_count(network_animation) - 1, 0))
	health = int(state.get("health", health))
	max_health = int(state.get("max_health", max_health))
	is_downed = bool(state.get("is_downed", is_downed))
	is_attacking = bool(state.get("is_attacking", is_attacking))
	intellect = int(state.get("intellect", intellect))
	health_attribute = int(state.get("health_attribute", health_attribute))
	strength = int(state.get("strength", strength))
	heal_doses = int(state.get("heal_doses", heal_doses))
	var network_weapons: Array = state.get("equipped_weapons", equipped_weapons) as Array
	if network_weapons.size() == 2:
		equipped_weapons = [StringName(network_weapons[0]), StringName(network_weapons[1])]
	active_weapon_slot = clampi(int(state.get("active_weapon_slot", active_weapon_slot)), 0, 1)
	acquired_upgrades = (state.get("acquired_upgrades", acquired_upgrades) as Dictionary).duplicate(true)
	_update_health_label()


func take_damage(amount: int, knockback_direction: float = 0.0) -> void:
	if is_hurt or is_downed or is_invulnerable or dash_invulnerability_timer > 0.0:
		return

	_cancel_heal()
	_end_dash()
	dash_timer = 0.0
	dash_invulnerability_timer = 0.0
	_reset_combo()
	is_ground_slamming = false
	var reduced_amount := maxi(1, roundi(amount * (1.0 - damage_resistance)))
	health = maxi(health - reduced_amount, 0)
	_update_health_label()

	print("Player health: ", health)

	if knockback_direction != 0.0:
		velocity.x = knockback_direction * KNOCKBACK_FORCE
		velocity.y = KNOCKBACK_UP
		knockback_timer = KNOCKBACK_DURATION

	is_hurt = true
	anim.modulate = Color(1, 1, 1, 0.5)

	await get_tree().create_timer(0.1).timeout

	anim.modulate = Color(1, 1, 1, 1)

	is_hurt = false

	if health <= 0:
		enter_downed()


func enter_downed() -> void:
	if is_downed:
		return

	health = 0
	_update_health_label()
	is_downed = true
	is_hurt = false
	is_attacking = false
	is_ground_slamming = false
	velocity = Vector2.ZERO
	knockback_timer = 0.0
	dash_timer = 0.0
	attack_input_buffer_timer = 0.0
	_reset_combo()
	_cancel_heal()
	_end_dash()
	dash_invulnerability_timer = 0.0
	attack_generation += 1
	revive_progress = 0.0
	attack_shape_cast.enabled = false
	ground_slam_shape_cast.enabled = false
	downed_label.visible = true
	revive_bar.visible = false
	_update_participant_state(false)
	downed_state_changed.emit(true)


func receive_revive_progress(reviver: CharacterBody2D, delta: float) -> void:
	if not is_downed or reviver == null or reviver.is_downed:
		cancel_revive_progress()
		return

	if global_position.distance_to(reviver.global_position) > revive_range:
		cancel_revive_progress()
		return

	revive_progress = min(revive_progress + delta, revive_duration)
	revive_bar.visible = true
	revive_bar.value = revive_progress / revive_duration * 100.0
	revive_progress_changed.emit(revive_progress / revive_duration)

	if revive_progress >= revive_duration:
		revive()


func cancel_revive_progress() -> void:
	if not is_downed:
		return

	revive_progress = 0.0
	revive_bar.value = 0.0
	revive_bar.visible = false
	revive_progress_changed.emit(0.0)


func revive() -> void:
	if not is_downed:
		return

	is_downed = false
	health = maxi(1, ceili(max_health * revive_health_ratio))
	_update_health_label()
	revive_progress = 0.0
	is_invulnerable = true
	invulnerability_timer = revived_invulnerability
	attack_shape_cast.enabled = true
	ground_slam_shape_cast.enabled = true
	downed_label.visible = false
	revive_bar.visible = false
	_update_participant_state(true)
	downed_state_changed.emit(false)


func _nearest_downed_ally() -> CharacterBody2D:
	var nearest: CharacterBody2D = null
	var nearest_distance := revive_range * revive_range

	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate == self or not candidate.is_downed:
			continue

		var distance := global_position.distance_squared_to(candidate.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = candidate

	return nearest


func _cancel_revive_attempt() -> void:
	if is_instance_valid(_revive_target):
		_revive_target.cancel_revive_progress()

	_revive_target = null


func _register_participant() -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")

	if run_manager:
		run_manager.register_participant(participant_id, true)
		_sync_progress()


func _update_participant_state(active: bool) -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")

	if run_manager:
		run_manager.set_participant_active(participant_id, active)


func _update_health_label() -> void:
	if is_instance_valid(health_label):
		health_label.text = "HP: %d/%d" % [health, max_health]


func _sync_progress() -> void:
	if not is_inside_tree():
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager and run_manager.has_method("update_participant_progress"):
		run_manager.update_participant_progress(participant_id, {
			"heal_doses": heal_doses,
			"intellect": intellect,
			"health": health_attribute,
			"strength": strength,
			"current_hp": health,
			"max_hp": max_health,
			"melee_damage": get_melee_damage(),
			"equipped_weapons": equipped_weapons.duplicate(),
			"active_weapon_slot": active_weapon_slot,
			"upgrades": acquired_upgrades.duplicate(true),
		})
