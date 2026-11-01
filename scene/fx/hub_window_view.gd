class_name HubWindowView
extends Node2D
## Janela da Casa do Jhon (Missão Visual 02, 01/11/2026). Só apresentação.
## Desenha a Cidade Baixa vista pela janela: céu, três camadas de prédios com parallax
## pela câmera, letreiros com cintilação, um carro voador ocasional, chuva em duas camadas
## e gotas escorrendo no vidro. Tudo é recortado ao retângulo da moldura (as regiões das
## texturas são calculadas, nada é desenhado fora da janela). Tiras: tools/visual/hub_art.py.
## Custo: 4 texturas + ~70 linhas por quadro; segue VisualQuality.

const SCALE := 2.0
const DIR := "res://assets/environment/hub/"
## Fração do deslocamento da câmera que cada camada "anda" dentro da moldura.
## Longe anda mais (fica quase parada na tela), perto anda pouco (acompanha a parede).
const LAYERS := [
	["window_sky", 0.34],
	["window_far", 0.26],
	["window_mid", 0.16],
	["window_near", 0.07],
]
## Letreiros na camada perto/meio: [camada, x na tira, y (do topo da janela), w, h, cor, cintila]
const SIGNS := [
	[3, 22, 62, 3, 18, Color("ff4fb4"), true],
	[3, 102, 72, 14, 4, Color("39dff2"), false],
	[3, 182, 58, 3, 22, Color("ffb347"), true],
	[3, 262, 76, 12, 4, Color("ff4fb4"), false],
	[2, 60, 66, 6, 2, Color("39dff2"), false],
	[2, 150, 60, 2, 8, Color("ff4fb4"), true],
	[2, 240, 70, 6, 2, Color("ffb347"), false],
]

var window_rect := Rect2(200, 364, 300, 208)  # mundo; a arte nativa é a metade disso
var _textures: Array[Texture2D] = []
var _strip_width := 320.0
var _rain: Array = []
var _droplets: Array = []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _car_x := -40.0
var _car_wait := 2.0
var _anchor_x := 0.0
var _anchor_set := false


func _ready() -> void:
	name = "HubWindowView"
	z_index = -19
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rng.seed = 7001
	for spec: Array in LAYERS:
		var path := DIR + String(spec[0]) + ".png"
		_textures.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	if _textures[0] != null:
		_strip_width = float(_textures[0].get_width())
	var profile := VisualQuality.profile()
	var far_count := 46 if profile == VisualQuality.FULL else (24 if profile == VisualQuality.REDUCED else 14)
	var near_count := 22 if profile == VisualQuality.FULL else (12 if profile == VisualQuality.REDUCED else 6)
	for i in far_count:
		_rain.append(_new_drop(false, true))
	for i in near_count:
		_rain.append(_new_drop(true, true))
	var droplet_count := 7 if profile == VisualQuality.FULL else (4 if profile == VisualQuality.REDUCED else 0)
	for i in droplet_count:
		_droplets.append(_new_droplet(true))


func _native_size() -> Vector2:
	return window_rect.size / SCALE


func _new_drop(near: bool, anywhere: bool) -> Dictionary:
	var size := _native_size()
	return {
		"x": _rng.randf_range(-10.0, size.x),
		"y": _rng.randf_range(-size.y, size.y) if anywhere else _rng.randf_range(-20.0, -2.0),
		"speed": _rng.randf_range(150.0, 190.0) if near else _rng.randf_range(90.0, 120.0),
		"length": _rng.randf_range(5.0, 8.0) if near else _rng.randf_range(2.0, 4.0),
		"alpha": _rng.randf_range(0.35, 0.55) if near else _rng.randf_range(0.16, 0.28),
		"near": near,
	}


func _new_droplet(anywhere: bool) -> Dictionary:
	var size := _native_size()
	return {
		"x": float(_rng.randi_range(2, int(size.x) - 3)),
		"y": _rng.randf_range(0.0, size.y * 0.6) if anywhere else _rng.randf_range(-6.0, size.y * 0.3),
		"speed": _rng.randf_range(6.0, 16.0),
		"pause": _rng.randf_range(0.0, 1.5),
		"trail": 0.0,
	}


func _process(delta: float) -> void:
	_clock += delta
	var size := _native_size()
	for drop: Dictionary in _rain:
		drop.y += float(drop.speed) * delta
		drop.x -= float(drop.speed) * 0.12 * delta                     # vento leve
		if float(drop.y) > size.y + 2.0 or float(drop.x) < -12.0:
			var fresh := _new_drop(bool(drop.near), false)
			for key: String in fresh:
				drop[key] = fresh[key]
	for droplet: Dictionary in _droplets:
		if float(droplet.pause) > 0.0:
			droplet.pause = float(droplet.pause) - delta
		else:
			droplet.y = float(droplet.y) + float(droplet.speed) * delta
			droplet.trail = minf(float(droplet.trail) + float(droplet.speed) * delta, 14.0)
			if _rng.randf() < delta * 0.8:                                # escorre aos trancos
				droplet.pause = _rng.randf_range(0.2, 1.2)
		if float(droplet.y) > size.y + 2.0:
			var fresh := _new_droplet(false)
			for key: String in fresh:
				droplet[key] = fresh[key]
	_car_wait -= delta
	if _car_wait <= 0.0:
		_car_x += 26.0 * delta
		if _car_x > _strip_width:
			_car_x = -40.0
			_car_wait = _rng.randf_range(5.0, 11.0)
	queue_redraw()


## Deslocamento da câmera em relação ao centro da janela (mundo). Sem câmera: 0.
func camera_offset() -> Vector2:
	var viewport := get_viewport()
	var camera := viewport.get_camera_2d() if viewport != null else null
	if camera == null:
		return Vector2.ZERO
	return camera.get_screen_center_position() - window_rect.get_center()


func layer_offset(layer: int) -> float:
	## Em pixels nativos da tira; positivo = conteúdo desliza para a esquerda.
	return camera_offset().x * float(LAYERS[layer][1]) / SCALE


func _draw() -> void:
	var size := _native_size()
	draw_set_transform(window_rect.position, 0.0, Vector2.ONE * SCALE)
	draw_rect(Rect2(Vector2.ZERO, size), Color("07061a"))
	var vertical := clampf(camera_offset().y * 0.02, -3.0, 3.0)
	for layer in LAYERS.size():
		var texture := _textures[layer]
		if texture == null:
			continue
		var height := minf(float(texture.get_height()), size.y)
		var source_x := fposmod(roundf(layer_offset(layer)), _strip_width)
		var top := size.y - height + roundf(vertical * float(LAYERS[layer][1]))
		var dest := Rect2(0.0, maxf(top, 0.0), size.x, height - maxf(-top, 0.0) - maxf(top + height - size.y, 0.0))
		var source := Rect2(source_x, maxf(-top, 0.0), size.x, dest.size.y)
		if dest.size.y > 0.0:
			draw_texture_rect_region(texture, dest, source)
		if layer == 1:
			_draw_car(size)
		if layer >= 2:
			_draw_signs(layer, size)
	_draw_rain(size)
	_draw_glass(size)
	_draw_frame(size)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _strip_to_window(layer: int, strip_x: float) -> float:
	return fposmod(strip_x - roundf(layer_offset(layer)), _strip_width)


func _draw_signs(layer: int, size: Vector2) -> void:
	var allow_flicker := VisualQuality.allows_flicker()
	for spec: Array in SIGNS:
		if int(spec[0]) != layer:
			continue
		var x := _strip_to_window(layer, float(spec[1]))
		var rect := Rect2(x, float(spec[2]), float(spec[3]), float(spec[4]))
		var clipped := rect.intersection(Rect2(Vector2.ZERO, size))
		if not clipped.has_area():
			continue
		var alpha := 1.0
		if bool(spec[6]) and allow_flicker:
			alpha = 0.35 if fmod(_clock * 1.7 + float(spec[1]) * 0.13, 4.0) > 3.7 else 0.95
		var colour: Color = spec[5]
		draw_rect(clipped.grow(1.0).intersection(Rect2(Vector2.ZERO, size)), Color(colour, 0.18 * alpha))
		draw_rect(clipped, Color(colour, alpha))


func _draw_car(size: Vector2) -> void:
	if _car_wait > 0.0:
		return
	var x := _strip_to_window(1, _car_x)
	if x < 0.0 or x > size.x - 4.0:
		return
	var y := 24.0 + sin(_clock * 0.7) * 1.0
	draw_rect(Rect2(x, y, 4, 1), Color("1a1230"))
	draw_rect(Rect2(x + 3, y, 1, 1), Color("ffe7a8"))
	draw_rect(Rect2(x, y + 1, 1, 1), Color("ff2a6d", 0.9 if fmod(_clock, 0.6) < 0.3 else 0.3))


func _draw_rain(size: Vector2) -> void:
	for drop: Dictionary in _rain:
		var x := roundf(float(drop.x))
		var y1 := float(drop.y)
		var y0 := y1 - float(drop.length)
		if y1 < 0.0 or y0 > size.y or x < 0.0 or x >= size.x:
			continue
		var colour := Color(0.72, 0.78, 1.0, float(drop.alpha))
		var start := Vector2(x + float(drop.length) * 0.12, clampf(roundf(y0), 0.0, size.y))
		var finish := Vector2(x, clampf(roundf(y1), 0.0, size.y))
		draw_line(start, finish, colour, 1.0)


func _draw_glass(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.45, 0.75, 0.07))         # vidro
	for k in 3:                                                                 # reflexo diagonal
		var x := 18.0 + k * 3.0
		draw_line(Vector2(x, 2), Vector2(x + 22, size.y * 0.55), Color(1, 1, 1, 0.035), 2.0)
	for droplet: Dictionary in _droplets:
		var x := float(droplet.x)
		var y := roundf(float(droplet.y))
		if y < 0.0 or y >= size.y:
			continue
		var trail := float(droplet.trail)
		if trail > 1.0:
			draw_line(Vector2(x + 0.5, maxf(y - trail, 0.0)), Vector2(x + 0.5, y), Color(0.75, 0.85, 1.0, 0.14), 1.0)
		draw_rect(Rect2(x, y, 1, 2), Color(0.85, 0.92, 1.0, 0.65))
		draw_rect(Rect2(x - 1, y + 1, 1, 1), Color(0.6, 0.7, 1.0, 0.35))


func _draw_frame(size: Vector2) -> void:
	var frame := Color("1c1418")
	var highlight := Color("4a3a3c")
	var mid_x := roundf(size.x * 0.5)
	var bar_y := roundf(size.y * 0.36)
	draw_rect(Rect2(mid_x - 1, 0, 3, size.y), frame)                            # montante central
	draw_rect(Rect2(mid_x - 1, 0, 1, size.y), highlight)
	draw_rect(Rect2(0, bar_y - 1, size.x, 2), frame)                            # travessa
	draw_rect(Rect2(0, bar_y - 1, size.x, 1), highlight)
	draw_rect(Rect2(0, 0, size.x, 1), Color(0, 0, 0, 0.6))                      # sombra do caixilho
	draw_rect(Rect2(0, 0, 1, size.y), Color(0, 0, 0, 0.5))
