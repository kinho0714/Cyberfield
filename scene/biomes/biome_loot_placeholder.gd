extends Area2D

const CHEST_TEXTURE := preload("res://assets/temporary_items/pixelexplosive/metal_chest_01.png")

@export var loot_id: StringName
@export var amount := 20

var _collected := false

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group("biome_loot")
	collision_mask = 1
	visual.visible = false
	var sprite := Sprite2D.new()
	sprite.name = "TemporaryChestVisual"
	sprite.texture = CHEST_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(1.5, 1.5)
	sprite.position = Vector2(0.0, -3.0)
	add_child(sprite)
	var label := get_node_or_null("Label") as Label
	if label == null:
		return
	label.visible = false
	body_entered.connect(func(body: Node) -> void: if body.is_in_group("player"): label.visible = true)
	body_exited.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			label.visible = get_overlapping_bodies().any(func(candidate: Node) -> bool: return candidate != body and candidate.is_in_group("player")))


func interact(_interactor: Node2D = null) -> void:
	if _collected:
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager == null or not run_manager.collect_biome_loot(loot_id, amount):
		return
	_collected = true
	_play_audio_event(&"loot_open")
	queue_free()


func _play_audio_event(event_id: StringName) -> void:
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_event"):
		audio.play_event(event_id)
