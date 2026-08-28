class_name BandagePickup
extends Area2D

const HEAL_RATIO := 0.10
var pickup_id: StringName
var room_id: StringName
var _nearby: Array[Node] = []


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("bandage_pickup")
	collision_layer = 2
	collision_mask = 1
	body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player") and not _nearby.has(body): _nearby.append(body))
	body_exited.connect(func(body: Node) -> void: _nearby.erase(body))
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	shape_node.shape = shape
	add_child(shape_node)
	var label := Label.new()
	label.position = Vector2(-62, -48)
	label.size = Vector2(124, 42)
	label.text = "+ CURATIVO\n[USAR]"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	add_child(label)
	body_entered.connect(func(body: Node) -> void: if body.is_in_group("player"): label.visible = true)
	body_exited.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			label.visible = not _nearby.is_empty())


func interact(player: Node2D = null) -> void:
	if player == null or bool(player.get("is_downed")):
		return
	var lan := get_tree().get_first_node_in_group("lan_session")
	if lan != null and lan.is_client():
		lan.request_bandage_pickup(pickup_id)
		return
	claim_authoritative(player)


func claim_authoritative(player: Node) -> bool:
	var manager := get_tree().get_first_node_in_group("run_manager")
	if manager != null and manager.collect_bandage_drop(room_id, pickup_id, player):
		queue_free()
		return true
	return false
