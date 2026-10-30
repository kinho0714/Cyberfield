extends Node2D
## Dev preview, outside the game flow: shows the Casa Jhon house stages 0-3 without
## touching the player's save (MetaProgression.house_stage). Open this scene and use
## "Run Current Scene". Tap/click: next stage. Drag: pan the room.

const PRESENTATION := preload("res://scene/casa_jhon_presentation.gd")
const HUB_ATMOSPHERE := preload("res://scene/fx/hub_atmosphere.gd")
const ROOM_SIZE := Vector2(2560.0, 768.0)

var _stage := 0
var _dragged := 0.0
var _camera: Camera2D
var _label: Label
var _room: Node2D


func _ready() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(640.0, 384.0)
	add_child(_camera)
	var hud := CanvasLayer.new()
	add_child(hud)
	_label = Label.new()
	_label.position = Vector2(16.0, 16.0)
	hud.add_child(_label)
	_show_stage()


func _show_stage() -> void:
	if _room != null:
		_room.queue_free()
	_room = Node2D.new()
	add_child(_room)
	move_child(_room, 0)
	var atmosphere := HUB_ATMOSPHERE.new()
	atmosphere.room = ROOM_SIZE
	atmosphere.lights_texture = load(PRESENTATION.STAGE_LIGHTS[_stage]) as Texture2D
	_room.add_child(atmosphere)
	var presentation := PRESENTATION.new()
	presentation.set_progression_state({"house_stage": _stage})
	_room.add_child(presentation)
	_label.text = "CASA JHON - ESTAGIO %d/3   (toque: proximo | arraste: mover)" % _stage


func _unhandled_input(event: InputEvent) -> void:
	var pressed := event is InputEventScreenTouch or event is InputEventMouseButton
	if pressed and event.is_pressed():
		_dragged = 0.0
	elif pressed and _dragged < 12.0:
		_stage = (_stage + 1) % PRESENTATION.STAGE_ART.size()
		_show_stage()
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask != 0):
		var dx: float = event.relative.x
		_dragged += absf(dx)
		_camera.position.x = clampf(_camera.position.x - dx, 640.0, ROOM_SIZE.x - 640.0)
