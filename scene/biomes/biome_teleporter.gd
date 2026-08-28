class_name BiomeTeleporter
extends Area2D

@export var teleporter_id: StringName
@export var module_instance_id: StringName
@export var display_name := "SETOR"
var arrival_position := Vector2.ZERO

var _active := false
var _label: Label
var _visual: Polygon2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("biome_teleporter")
	collision_layer = 2
	collision_mask = 1
	body_entered.connect(_on_body_proximity.bind(true))
	body_exited.connect(_on_body_proximity.bind(false))
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 42.0
	collision.shape = shape
	add_child(collision)
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([Vector2(-34, 8), Vector2(-24, -14), Vector2(0, -26), Vector2(24, -14), Vector2(34, 8), Vector2(0, 22)])
	add_child(_visual)
	_label = Label.new()
	_label.position = Vector2(-82, -62)
	_label.size = Vector2(164, 28)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible = false
	add_child(_label)
	arrival_position = global_position + Vector2(0, -48)
	_refresh()


func interact(interactor: Node2D = null) -> void:
	if interactor == null or bool(interactor.get("is_downed")):
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null:
		return
	if not _active:
		room_manager.request_teleporter_activation(teleporter_id, interactor)
	else:
		room_manager.open_teleporter_menu(teleporter_id, interactor)


func set_active(value: bool) -> void:
	_active = value
	_refresh()


func is_active() -> bool:
	return _active


func _refresh() -> void:
	if _visual == null:
		return
	_visual.color = Color(0.2, 0.95, 1.0, 0.95) if _active else Color(0.18, 0.32, 0.4, 0.85)
	_label.text = "[E] TELEPORTAR" if _active else "[E] ATIVAR TELEPORTE"


func _on_body_proximity(body: Node, entered: bool) -> void:
	if body.is_in_group("player"):
		_label.visible = entered or get_overlapping_bodies().any(func(candidate: Node) -> bool: return candidate != body and candidate.is_in_group("player"))
