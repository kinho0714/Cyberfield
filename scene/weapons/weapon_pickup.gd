class_name WeaponPickup
extends Area2D

@export var pickup_id: StringName
@export var weapon_id: StringName = &"breaker_maul"
var _claimed := false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("weapon_pickup")
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(58, 30)
	collision.shape = shape
	add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-29, -15), Vector2(29, -15), Vector2(29, 15), Vector2(-29, 15)])
	visual.color = Color(0.25, 0.85, 1.0)
	add_child(visual)
	var label := Label.new()
	label.position = Vector2(-105, -60)
	label.size = Vector2(210, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var data := WeaponCatalog.get_definition(weapon_id)
	label.text = "%s\n[USAR] PEGAR // %s %d" % [data.name, String(data.type).to_upper(), int(data.damage)]
	label.visible = false
	add_child(label)
	body_entered.connect(func(body: Node) -> void: if body.is_in_group("player"): label.visible = true)
	body_exited.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			label.visible = get_overlapping_bodies().any(func(candidate: Node) -> bool: return candidate != body and candidate.is_in_group("player")))


func interact(player: Node2D = null) -> void:
	if _claimed or player == null or player.is_downed:
		return
	var lan_session := get_tree().get_first_node_in_group("lan_session")
	if lan_session != null and lan_session.is_client():
		lan_session.request_weapon_pickup(pickup_id)
		return
	claim_authoritative(player)


func claim_authoritative(player: Node) -> bool:
	if _claimed or player == null or global_position.distance_to(player.global_position) > 96.0:
		return false
	if not player.equip_weapon(weapon_id):
		return false
	_claimed = true
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager != null:
		run_manager.record_weapon_found(player.participant_id, weapon_id)
		run_manager.get_current_map_state().collect_content(&"weapon", pickup_id)
	queue_free()
	return true
