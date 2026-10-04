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
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(-25, -17), Vector2(25, -17), Vector2(25, 17), Vector2(-25, 17)])
	glow.color = Color(0.1, 0.95, 0.85, 0.22)
	glow.scale = Vector2(1.25, 1.25)
	glow.z_index = 1
	add_child(glow)
	var packet := Polygon2D.new()
	packet.polygon = PackedVector2Array([Vector2(-23, -15), Vector2(23, -15), Vector2(23, 15), Vector2(-23, 15)])
	packet.color = Color(0.9, 0.96, 0.92, 1.0)
	packet.z_index = 2
	add_child(packet)
	var cross := Line2D.new()
	cross.points = PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2.ZERO, Vector2(0, -9), Vector2(0, 9)])
	cross.width = 5.0
	cross.default_color = Color(0.08, 0.75, 0.68, 1.0)
	cross.z_index = 3
	add_child(cross)
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
