class_name ScrapPickup
extends Area2D

const ICON := preload("res://assets/temporary_items/foozle/scrap_components.png")

var pickup_id: StringName
var room_id: StringName
var amount := 1
var attraction_range := 140.0
var attraction_speed := 330.0
var _collected := false


func _ready() -> void:
	add_to_group("scrap_pickup")
	collision_layer = 0
	collision_mask = 0
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-19, -14), Vector2(19, -14), Vector2(19, 14), Vector2(-19, 14)
	])
	glow.color = Color(0.95, 0.66, 0.16, 0.20)
	glow.z_index = 1
	add_child(glow)
	var sprite := Sprite2D.new()
	sprite.texture = ICON
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.0, 2.0)
	sprite.z_index = 2
	add_child(sprite)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	var lan := get_tree().get_first_node_in_group("lan_session")
	if lan != null and lan.is_client():
		return
	var nearest: Node2D = null
	var nearest_distance := attraction_range
	for player in get_tree().get_nodes_in_group("player"):
		if not player.visible or bool(player.get("is_downed")):
			continue
		var distance := global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	if nearest == null:
		return
	global_position = global_position.move_toward(nearest.global_position, attraction_speed * delta)
	if global_position.distance_to(nearest.global_position) <= 14.0:
		collect()


func collect() -> void:
	if _collected:
		return
	var manager := get_tree().get_first_node_in_group("run_manager")
	if manager == null or not manager.collect_scrap_drop(room_id, pickup_id):
		return
	_collected = true
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null:
		audio.play_event(&"scrap_collect")
	queue_free()
