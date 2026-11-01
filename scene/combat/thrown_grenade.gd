class_name ThrownGrenade
extends CharacterBody2D
## Granada arremessada pelos slots ativos. Física simples (colide só com o cenário),
## explode no contato com chão/parede/inimigo ou ao fim do pavio.

const GRAVITY := 900.0
const FUSE := 1.4
const SHEETS := {
	&"ice_grenade": {"body": "res://assets/accessories/ice_grenade_world.png", "burst": "res://assets/fx/arsenal/ice_burst.png"},
	&"fire_grenade": {"body": "res://assets/accessories/fire_grenade_world.png", "burst": "res://assets/fx/arsenal/fire_burst.png"},
}
const FIRE_ZONE := "res://assets/fx/arsenal/fire_zone.png"

var accessory_id: StringName = &"ice_grenade"
var data: Dictionary = {}
var thrower: Node2D
var _age := 0.0
var _exploded := false
var _body: AnimatedSprite2D


func setup(id: StringName, from: Node2D, origin: Vector2, facing: float) -> void:
	accessory_id = id
	data = AccessoryCatalog.get_definition(id)
	thrower = from
	global_position = origin
	var throw: Vector2 = data.get("throw_speed", Vector2(330, -300))
	velocity = Vector2(throw.x * facing, throw.y) + Vector2((from as CharacterBody2D).velocity.x * 0.35 if from is CharacterBody2D else 0.0, 0.0)


func _ready() -> void:
	add_to_group("player_gadget")
	# Cenário, inimigos e jogadores ficam na camada 1; ignora todos os jogadores.
	collision_layer = 0
	collision_mask = 1
	for player in get_tree().get_nodes_in_group("player"):
		if player is PhysicsBody2D:
			add_collision_exception_with(player)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	z_index = 7
	var spec: Dictionary = SHEETS.get(accessory_id, SHEETS[&"ice_grenade"])
	_body = _sheet_sprite(spec.body, 4, 14.0, true)
	if _body != null:
		add_child(_body)
		_body.play(&"play")


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_age += delta
	velocity.y += GRAVITY * delta
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var collider := collision.get_collider() as Node
		if (collider != null and collider.is_in_group("enemy")) or collision.get_normal().y < -0.6:
			explode()
			return
		# Parede/teto: ricocheteia em vez de explodir na mão do jogador.
		velocity = velocity.bounce(collision.get_normal()) * 0.45
	if _age >= FUSE or _touching_enemy():
		explode()


func _touching_enemy() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and EnemyStatus.is_alive(enemy) and (enemy as Node2D).global_position.distance_to(global_position + Vector2(0, 26)) < 30.0:
			return true
	return false


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	velocity = Vector2.ZERO
	if _body != null:
		_body.visible = false
	var radius := float(data.get("radius", 100.0))
	var center := global_position
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node2D) or not EnemyStatus.is_alive(enemy):
			continue
		var body_center := (enemy as Node2D).global_position + Vector2(0, -24)
		if body_center.distance_to(center) > radius:
			continue
		var direction := signf((enemy as Node2D).global_position.x - center.x)
		if accessory_id == &"ice_grenade":
			EnemyStatus.freeze(enemy, float(data.freeze), float(data.slow), float(data.slow_time))
			enemy.take_damage(int(data.damage), 0.0, 0.0)
		else:
			enemy.take_damage(int(data.damage), direction, 1.3)
			EnemyStatus.ignite(enemy, float(data.burn_dps), float(data.burn_time))
	_play_audio(&"weapon_impact")
	CombatFx.shake(self, 5.0 if accessory_id == &"fire_grenade" else 3.0, 0.16)
	var spec: Dictionary = SHEETS.get(accessory_id, SHEETS[&"ice_grenade"])
	var burst := _sheet_sprite(spec.burst, 6, 16.0, false)
	if burst != null:
		burst.scale = Vector2.ONE * (radius / 48.0)
		burst.material = CombatFx._additive_material()
		add_child(burst)
		burst.play(&"play")
	if accessory_id == &"fire_grenade":
		await _burn_zone(center, radius, float(data.get("zone_time", 3.0)))
	else:
		await get_tree().create_timer(0.45).timeout
	queue_free()


func _burn_zone(center: Vector2, radius: float, duration: float) -> void:
	var zone := _sheet_sprite(FIRE_ZONE, 4, 10.0, true)
	if zone != null:
		zone.position = Vector2(0, -6)
		zone.scale = Vector2(radius / 40.0, 1.6)
		add_child(zone)
		zone.play(&"play")
	var elapsed := 0.0
	while elapsed < duration and is_inside_tree():
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy is Node2D and EnemyStatus.is_alive(enemy) and absf((enemy as Node2D).global_position.x - center.x) <= radius and absf((enemy as Node2D).global_position.y - center.y) <= 70.0:
				EnemyStatus.ignite(enemy, float(data.burn_dps), 1.0)
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
		if zone != null:
			zone.modulate.a = clampf(1.2 - elapsed / duration, 0.2, 1.0)


func _sheet_sprite(path: String, frames: int, fps: float, loop: bool) -> AnimatedSprite2D:
	if not ResourceLoader.exists(path):
		return null
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = VisualSpriteFactory.build_sprite_frames({&"play": {"texture": load(path), "frames": frames, "fps": fps, "loop": loop}})
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _play_audio(event_id: StringName) -> void:
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_event"):
		audio.play_event(event_id)
