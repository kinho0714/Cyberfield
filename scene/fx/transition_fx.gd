class_name TransitionFx
extends Control
## Transição entre salas/biomas (Missão Visual 02). Só apresentação: lê a opacidade do
## FadeRect existente (RoomManager._fade_to) e desenha por cima, enquanto o fade está a
## meio caminho, faixas de varredura, uma linha de scan ciano e blocos de "glitch".
## Duração e lógica do fade não mudam. MÍNIMO desliga; REDUZIDO tira o glitch.

const CYAN := Color("39dff2")
const MAGENTA := Color("ff4fb4")

var fade_rect: CanvasItem
var _clock := 0.0
var _had_drawing := false


func _ready() -> void:
	name = "TransitionFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_clock += delta
	var drawing: bool = is_instance_valid(fade_rect) and fade_rect.modulate.a > 0.02 and fade_rect.modulate.a < 0.98
	if drawing or _had_drawing:
		queue_redraw()
	_had_drawing = drawing


func _draw() -> void:
	if fade_rect == null or not is_instance_valid(fade_rect) or VisualQuality.profile() == VisualQuality.MINIMAL:
		return
	var alpha := fade_rect.modulate.a
	if alpha <= 0.02 or alpha >= 0.98:
		return
	var view := get_viewport_rect().size
	var strength := sin(alpha * PI)                                   # máximo no meio do fade
	var band := 6.0
	var y := 0.0
	while y < view.y:                                                  # faixas de varredura
		draw_rect(Rect2(0.0, y, view.x, 2.0), Color(0.0, 0.0, 0.0, 0.35 * strength))
		y += band
	var scan := fmod(alpha * 1.6 + _clock * 0.2, 1.0) * view.y        # linha de scan
	draw_rect(Rect2(0.0, scan, view.x, 2.0), Color(CYAN, 0.55 * strength))
	draw_rect(Rect2(0.0, scan - 10.0, view.x, 10.0), Color(CYAN, 0.08 * strength))
	if VisualQuality.profile() != VisualQuality.FULL:
		return
	var seed := int(_clock * 18.0)                                     # blocos de glitch
	for k in 5:
		var h := float((seed * 37 + k * 101) % 23 + 4)
		var gy := float((seed * 53 + k * 211) % int(maxf(view.y, 1.0)))
		var gx := float((seed * 71 + k * 131) % 60) - 30.0
		draw_rect(Rect2(gx, gy, view.x, h), Color(MAGENTA if k % 2 else CYAN, 0.10 * strength))
