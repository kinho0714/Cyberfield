class_name PlayerGadgets
extends Node
## Dois slots exclusivos de acessório/habilidade ativa (gadget_1/gadget_2), separados
## das armas e dos cyberwares. Cargas + recarga por carga. Só funciona durante a run.

const GRENADE_SCRIPT := preload("res://scene/combat/thrown_grenade.gd")
const TURRET_SCRIPT := preload("res://scene/combat/portable_turret.gd")

signal gadget_used(slot: int, accessory_id: StringName)

var player: CharacterBody2D
var slots: Array[StringName] = [&"", &""]
var charges: Array[int] = [0, 0]
var recharge: Array[float] = [0.0, 0.0]


func _ready() -> void:
	player = get_parent() as CharacterBody2D


func configure(accessory_ids: Array) -> void:
	for slot in AccessoryCatalog.SLOT_COUNT:
		var id := StringName(accessory_ids[slot]) if slot < accessory_ids.size() else &""
		slots[slot] = id if AccessoryCatalog.has_accessory(id) and not slots.slice(0, slot).has(id) else &""
		charges[slot] = max_charges(slot)
		recharge[slot] = 0.0


func max_charges(slot: int) -> int:
	return int(AccessoryCatalog.get_definition(slots[slot]).get("charges", 0)) if not slots[slot].is_empty() else 0


func recharge_time(slot: int) -> float:
	return float(AccessoryCatalog.get_definition(slots[slot]).get("recharge", 1.0))


## 0..1 da carga em andamento (para o HUD).
func recharge_ratio(slot: int) -> float:
	if slots[slot].is_empty() or charges[slot] >= max_charges(slot):
		return 1.0
	return clampf(recharge[slot] / maxf(recharge_time(slot), 0.01), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if player == null or bool(player.get("network_remote_replica")):
		return
	for slot in AccessoryCatalog.SLOT_COUNT:
		if slots[slot].is_empty() or charges[slot] >= max_charges(slot):
			recharge[slot] = 0.0
			continue
		recharge[slot] += delta
		if recharge[slot] >= recharge_time(slot):
			recharge[slot] = 0.0
			charges[slot] += 1
	if bool(player.get("is_downed")) or not bool(player.get("input_enabled")) or bool(player.get("network_prediction_only")):
		return
	for slot in AccessoryCatalog.SLOT_COUNT:
		var action: StringName = player.call("_action", StringName("gadget_%d" % (slot + 1)))
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			use(slot)


func can_use(slot: int) -> bool:
	if slot < 0 or slot >= AccessoryCatalog.SLOT_COUNT or slots[slot].is_empty() or charges[slot] <= 0:
		return false
	var run_manager := player.get_tree().get_first_node_in_group("run_manager") if player.is_inside_tree() else null
	return run_manager != null and bool(run_manager.run_active) and not bool(player.get("is_downed"))


func use(slot: int) -> bool:
	if not can_use(slot):
		return false
	var id := slots[slot]
	var facing := -1.0 if bool((player.get_node("AnimatedSprite2D") as AnimatedSprite2D).flip_h) else 1.0
	# Dentro da sala atual: some junto com ela na troca de estágio/morte.
	var room_manager := player.get_tree().get_first_node_in_group("room_manager")
	var world: Node = room_manager.current_room if room_manager != null and is_instance_valid(room_manager.get("current_room")) else player.get_parent()
	if id == &"portable_turret":
		var turret := TURRET_SCRIPT.new() as PortableTurret
		turret.setup(player, player.global_position)
		world.add_child(turret)
		turret.global_position = player.global_position + Vector2(26.0 * facing, -4.0)
		turret.call("_snap_to_floor")
	else:
		var grenade := GRENADE_SCRIPT.new() as ThrownGrenade
		grenade.accessory_id = id
		world.add_child(grenade)
		grenade.setup(id, player, player.global_position + Vector2(14.0 * facing, -40.0), facing)
	charges[slot] -= 1
	var audio := player.get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_event"):
		audio.play_event(&"weapon_equip")
	gadget_used.emit(slot, id)
	return true


func get_state() -> Dictionary:
	return {"slots": slots.duplicate(), "charges": charges.duplicate(), "recharge": recharge.duplicate()}


func apply_state(state: Dictionary) -> void:
	var incoming_slots: Array = state.get("slots", []) as Array
	var incoming_charges: Array = state.get("charges", []) as Array
	var incoming_recharge: Array = state.get("recharge", []) as Array
	for slot in AccessoryCatalog.SLOT_COUNT:
		if slot < incoming_slots.size():
			slots[slot] = StringName(incoming_slots[slot])
		if slot < incoming_charges.size():
			charges[slot] = int(incoming_charges[slot])
		if slot < incoming_recharge.size():
			recharge[slot] = float(incoming_recharge[slot])
