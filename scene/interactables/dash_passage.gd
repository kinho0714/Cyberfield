class_name DashPassage
extends StaticBody2D
## Passagem secreta que só abre com DASH (P1-C, 02/11/2026). Reutilizável: qualquer cena
## ou gerador cria `DashPassage.new()`, define `passage_id` e `size` e adiciona à árvore.
##
## - Parede sólida (camada 1) para quem anda, pula, escala ou é empurrado.
## - Um detector um pouco maior percebe o jogador DURANTE o dash (dash_timer > 0) e abre.
## - Aberta, a colisão some e o estado vai para o BiomeMapState (kind "passage"): continua
##   aberta na mesma run e chega aos clientes LAN pelo snapshot do mapa do host.
## - Visual próprio (painel rachado com setas de dash) para o jogador aprender o sinal.

signal opened(passage_id: StringName)

const DETECTOR_MARGIN := 14.0

@export var passage_id: StringName
@export var size := Vector2(26.0, 460.0)
## Sentido do dash que atravessa (1 = para a direita, -1 = para a esquerda): só visual.
@export var dash_direction := 1.0

var is_open := false
var _shape: CollisionShape2D
var _detector: Area2D
var _visual: Node2D


func _ready() -> void:
	add_to_group("dash_passage")
	collision_layer = 1
	collision_mask = 0
	set_meta("collision_role", &"dash_passage")
	_shape = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	_shape.shape = rectangle
	add_child(_shape)
	_detector = Area2D.new()
	_detector.collision_layer = 0
	_detector.collision_mask = 1
	var detector_shape := CollisionShape2D.new()
	var detector_rect := RectangleShape2D.new()
	detector_rect.size = size + Vector2(DETECTOR_MARGIN * 2.0, 0.0)
	detector_shape.shape = detector_rect
	_detector.add_child(detector_shape)
	add_child(_detector)
	_visual = _build_visual()
	add_child(_visual)
	var run_manager := _run_manager()
	if run_manager != null:
		run_manager.state_changed.connect(_sync_from_map)
	_sync_from_map()


func _physics_process(_delta: float) -> void:
	if is_open:
		return
	for body in _detector.get_overlapping_bodies():
		if body.is_in_group("player") and is_dashing(body) and not bool(body.get("network_remote_replica")):
			open_passage(true)
			return


static func is_dashing(body: Node) -> bool:
	return float(body.get("dash_timer") if body.get("dash_timer") != null else 0.0) > 0.0


func open_passage(record: bool = true) -> void:
	if is_open:
		return
	is_open = true
	_shape.set_deferred("disabled", true)
	_detector.set_deferred("monitoring", false)
	if record:
		var run_manager := _run_manager()
		if run_manager != null:
			run_manager.get_current_map_state().collect_content(&"passage", passage_id)
		var audio := get_tree().get_first_node_in_group("audio_service")
		if audio != null and audio.has_method("play_event"):
			audio.play_event(&"world_door")
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(_visual, "modulate:a", 0.12, 0.25)
	else:
		_visual.modulate.a = 0.12
	opened.emit(passage_id)


func _sync_from_map() -> void:
	if is_open or not is_inside_tree():
		return
	var run_manager := _run_manager()
	if run_manager != null and run_manager.get_current_map_state().is_content_collected(&"passage", passage_id):
		open_passage(false)


func _build_visual() -> Node2D:
	var root := Node2D.new()
	root.name = "DashPassageVisual"
	var half := size * 0.5
	var panel := Polygon2D.new()
	panel.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	panel.color = Color(0.07, 0.11, 0.16, 1.0)
	root.add_child(panel)
	var edge := Line2D.new()
	edge.width = 2.0
	edge.default_color = Color(0.25, 0.85, 0.95, 0.75)
	edge.points = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(-half.x, half.y), Vector2(half.x, half.y), Vector2(half.x, -half.y)])
	root.add_child(edge)
	# Rachaduras e setas de dash na altura do jogador: o sinal de "atravesse correndo".
	var crack := Line2D.new()
	crack.width = 2.0
	crack.default_color = Color(0.55, 0.95, 1.0, 0.9)
	crack.points = PackedVector2Array([Vector2(-half.x + 3, half.y - 120), Vector2(2, half.y - 96), Vector2(-4, half.y - 70), Vector2(half.x - 3, half.y - 52)])
	root.add_child(crack)
	for index in 3:
		var arrow := Polygon2D.new()
		var y := half.y - 40.0 - float(index) * 26.0
		var d := signf(dash_direction) if dash_direction != 0.0 else 1.0
		arrow.polygon = PackedVector2Array([Vector2(-8 * d, y - 7), Vector2(6 * d, y), Vector2(-8 * d, y + 7), Vector2(-4 * d, y)])
		arrow.color = Color(1.0, 0.82, 0.35, 0.85)
		root.add_child(arrow)
	return root


func _run_manager() -> Node:
	return get_tree().get_first_node_in_group("run_manager") if is_inside_tree() else null
