extends Area2D

@export var exit_id: StringName
@export var destination_id: StringName

const GATE := preload("res://assets/props/gates/exit_gate.png")

var _used := false


func _ready() -> void:
	collision_mask = 1
	_dress_gate()
	var label := get_node_or_null("Label") as Label
	if label == null:
		return
	label.visible = false
	body_entered.connect(func(body: Node) -> void: if body.is_in_group("player"): label.visible = true)
	body_exited.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			label.visible = get_overlapping_bodies().any(func(candidate: Node) -> bool: return candidate != body and candidate.is_in_group("player")))


func _dress_gate() -> void:
	# Presentation only: the original gate art sits over the door footprint. Door and
	# Frame stay visible (contract) but recede so the gate reads as the exit.
	var door := get_node_or_null("Door") as Polygon2D
	var frame := get_node_or_null("Frame") as Line2D
	if door != null:
		door.color = Color(door.color, 0.12)
	if frame != null:
		frame.width = 2.0
		frame.default_color = Color(frame.default_color, 0.45)
	var gate := Sprite2D.new()
	gate.name = "ExitGate"
	gate.texture = GATE
	gate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(gate)
	move_child(gate, 0)  # behind the prompt label and the faint door/frame tint


func interact(interactor: Node2D = null) -> void:
	if _used or interactor == null or bool(interactor.get("is_downed")):
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if room_manager == null or run_manager == null or room_manager.is_transitioning:
		return
	if not room_manager.can_use_exit(self, interactor):
		return
	_used = true
	_play_audio_event(&"world_door")
	room_manager.request_biome_advance(exit_id, destination_id)


func _play_audio_event(event_id: StringName) -> void:
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_event"):
		audio.play_event(event_id)
