class_name EnemyStatus
extends Node2D
## Efeitos temporários em inimigos (congelado, lento, queimando), sem editar as cenas
## dos inimigos: um nó filho ajusta `move_speed` por razão (restaurável) e segura os
## temporizadores de ataque. Funciona com Enemy, HeavyEnemy e RangedEnemy.
## Só roda no host/solo (clientes LAN recebem a vida pelo snapshot do inimigo).

const NODE_NAME := "EnemyStatus"
const FROZEN_FACTOR := 0.04
const BURN_TICK := 0.5
const ICE_SHELL := "res://assets/fx/arsenal/status_frozen.png"
const FLAME := "res://assets/fx/arsenal/status_burning.png"

var freeze_timer := 0.0
var slow_timer := 0.0
var slow_factor := 1.0
var burn_timer := 0.0
var burn_dps := 0.0
var _burn_tick := 0.0
var _applied_factor := 1.0
var _ice: AnimatedSprite2D
var _flame: AnimatedSprite2D


static func of(enemy: Node) -> EnemyStatus:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return null
	var existing := enemy.get_node_or_null(NODE_NAME) as EnemyStatus
	if existing != null:
		return existing
	var status := EnemyStatus.new()
	status.name = NODE_NAME
	enemy.add_child(status)
	return status


static func is_alive(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return false
	if enemy.get("is_dead") == true:
		return false
	return int(enemy.get("health")) > 0


static func freeze(enemy: Node, duration: float, after_slow: float, after_slow_time: float) -> void:
	var status := of(enemy)
	if status == null or not is_alive(enemy):
		return
	if enemy.has_method("cancel_attack"):
		enemy.call("cancel_attack")
	status.freeze_timer = maxf(status.freeze_timer, duration)
	status.slow_factor = minf(status.slow_factor if status.slow_timer > 0.0 else 1.0, after_slow)
	status.slow_timer = maxf(status.slow_timer, duration + after_slow_time)
	# Congelar apaga a queima (choque térmico) — escolhas de acessório importam.
	status.burn_timer = 0.0


static func ignite(enemy: Node, dps: float, duration: float) -> void:
	var status := of(enemy)
	if status == null or not is_alive(enemy):
		return
	status.burn_dps = maxf(status.burn_dps if status.burn_timer > 0.0 else 0.0, dps)
	status.burn_timer = maxf(status.burn_timer, duration)
	status.freeze_timer = 0.0


## Dano de efeito: não interrompe ataques nem aplica empurrão (diferente de take_damage).
static func deal_effect_damage(enemy: Node, amount: int) -> void:
	if not is_alive(enemy) or amount <= 0:
		return
	enemy.set("health", maxi(int(enemy.get("health")) - amount, 0))
	enemy.set("health_bar_visible_timer", 2.5)
	if enemy.has_method("_activate_boss_phase_two_if_needed"):
		enemy.call("_activate_boss_phase_two_if_needed")
	if enemy.has_method("_update_health_label"):
		enemy.call("_update_health_label")
	if int(enemy.get("health")) <= 0 and enemy.has_method("_die"):
		enemy.call("_die")


func is_frozen() -> bool:
	return freeze_timer > 0.0


func _ready() -> void:
	z_index = 6
	position = Vector2(0, -30)


func _physics_process(delta: float) -> void:
	var enemy := get_parent()
	if not is_alive(enemy):
		_set_speed_factor(1.0)
		queue_free()
		return
	freeze_timer = maxf(freeze_timer - delta, 0.0)
	slow_timer = maxf(slow_timer - delta, 0.0)
	if burn_timer > 0.0:
		burn_timer = maxf(burn_timer - delta, 0.0)
		_burn_tick += delta
		if _burn_tick >= BURN_TICK:
			_burn_tick -= BURN_TICK
			deal_effect_damage(enemy, roundi(burn_dps * BURN_TICK))
			if not is_alive(enemy):
				return
	else:
		_burn_tick = 0.0
	var factor := 1.0
	if freeze_timer > 0.0:
		factor = FROZEN_FACTOR
		for timer: String in ["attack_cooldown_timer", "shoot_cooldown_timer", "melee_cooldown_timer"]:
			if enemy.get(timer) != null:
				enemy.set(timer, maxf(float(enemy.get(timer)), 0.25))
	elif slow_timer > 0.0:
		factor = slow_factor
	_set_speed_factor(factor)
	_update_visuals()
	if freeze_timer <= 0.0 and slow_timer <= 0.0 and burn_timer <= 0.0:
		_set_speed_factor(1.0)
		_clear_tint()
		queue_free()


func _clear_tint() -> void:
	for path: String in ["EnemyCharacterVisual", "AnimatedSprite2D"]:
		var visual := get_parent().get_node_or_null(path) as CanvasItem if get_parent() != null else null
		if visual != null:
			visual.self_modulate = Color.WHITE


func _set_speed_factor(factor: float) -> void:
	var enemy := get_parent()
	if enemy == null or is_equal_approx(factor, _applied_factor) or enemy.get("move_speed") == null:
		return
	# Razão em vez de valor salvo: buffs do chefe aplicados durante o efeito sobrevivem.
	enemy.set("move_speed", float(enemy.get("move_speed")) / _applied_factor * factor)
	_applied_factor = factor


func _exit_tree() -> void:
	_set_speed_factor(1.0)
	_clear_tint()


func _update_visuals() -> void:
	var visual := get_parent().get_node_or_null("EnemyCharacterVisual") as CanvasItem
	if visual == null:
		visual = get_parent().get_node_or_null("AnimatedSprite2D") as CanvasItem
	if freeze_timer > 0.0:
		_ice = _ensure_sheet(_ice, ICE_SHELL, 4, 6.0)
	elif _ice != null:
		_ice.queue_free()
		_ice = null
	if burn_timer > 0.0:
		_flame = _ensure_sheet(_flame, FLAME, 4, 12.0)
	elif _flame != null:
		_flame.queue_free()
		_flame = null
	if visual != null:
		var tint := Color.WHITE
		if freeze_timer > 0.0:
			tint = Color(0.55, 0.85, 1.35)
		elif slow_timer > 0.0:
			tint = Color(0.8, 0.95, 1.15)
		elif burn_timer > 0.0:
			tint = Color(1.3, 0.85, 0.65)
		visual.self_modulate = tint


func _ensure_sheet(current: AnimatedSprite2D, path: String, frames: int, fps: float) -> AnimatedSprite2D:
	if current != null or not ResourceLoader.exists(path):
		return current
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = VisualSpriteFactory.build_sprite_frames({&"loop": {"texture": load(path), "frames": frames, "fps": fps, "loop": true}})
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(1.5, 1.5)
	add_child(sprite)
	sprite.play(&"loop")
	return sprite
