class_name TouchScrollRouter
extends RefCounted
## Toque para painéis com rolagem (Android). O projeto desliga
## `pointing/emulate_mouse_from_touch`, então Button e ScrollContainer não recebem toque
## sozinhos. Este roteador classifica cada dedo em TOQUE (dispara o botão ao soltar) ou
## ARRASTO (rola o ScrollContainer sob o dedo), respeita o recorte das áreas roláveis e
## procura os botões na árvore a cada toque — listas reconstruídas não ficam obsoletas.
## Mouse e teclado continuam pelo caminho nativo do Godot; o roteador só olha toque.

const DRAG_THRESHOLD := 14.0

var root: Control
var _index := -1
var _origin := Vector2.ZERO
var _scroll: ScrollContainer
var _scroll_origin := 0
var _dragging := false
## Último botão disparado (útil para testes e para depuração no aparelho).
var last_activated: BaseButton


func _init(target_root: Control) -> void:
	root = target_root


func reset() -> void:
	_index = -1
	_scroll = null
	_dragging = false


## Retorna true quando o evento foi consumido (o chamador marca como tratado).
func handle(event: InputEvent) -> bool:
	if root == null or not root.is_visible_in_tree():
		reset()
		return false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _index >= 0:
				return true
			_index = touch.index
			_origin = touch.position
			_dragging = false
			_scroll = _scroll_at(touch.position)
			_scroll_origin = _scroll.scroll_vertical if _scroll != null else 0
			return true
		if touch.index != _index:
			# Soltura de um dedo que começou antes do painel abrir (ex.: botão INTERAGIR).
			return false
		var tap := not touch.canceled and not _dragging and touch.position.distance_to(_origin) < DRAG_THRESHOLD
		reset()
		if tap:
			activate_at(touch.position)
		return true
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _index:
			return false
		var offset := drag.position - _origin
		if not _dragging and absf(offset.y) >= DRAG_THRESHOLD and absf(offset.y) >= absf(offset.x):
			_dragging = true
		elif not _dragging and offset.length() >= DRAG_THRESHOLD * 2.0:
			# Arrasto lateral longo: não é toque, mas também não rola.
			_dragging = true
		if _dragging and _scroll != null:
			_scroll.scroll_vertical = _scroll_origin - int(round(offset.y))
		return true
	return false


## Dispara o botão visível e habilitado sob o ponto (coordenadas do viewport).
func activate_at(position: Vector2) -> BaseButton:
	var button := button_at(position)
	if button == null:
		return null
	last_activated = button
	if button.focus_mode != Control.FOCUS_NONE:
		button.grab_focus()
	if button is OptionButton:
		(button as OptionButton).show_popup()
	else:
		if button.toggle_mode:
			button.button_pressed = not button.button_pressed
		button.pressed.emit()
	return button


func button_at(position: Vector2) -> BaseButton:
	var buttons := root.find_children("*", "BaseButton", true, false)
	# Última na árvore = desenhada por cima.
	for i in range(buttons.size() - 1, -1, -1):
		var button := buttons[i] as BaseButton
		if button.disabled or not button.is_visible_in_tree():
			continue
		if not button.get_global_rect().has_point(position):
			continue
		if not _inside_clip(button, position):
			continue
		return button
	return null


func _inside_clip(control: Control, position: Vector2) -> bool:
	var parent := control.get_parent()
	while parent != null and parent != root.get_parent():
		if parent is ScrollContainer and not (parent as Control).get_global_rect().has_point(position):
			return false
		parent = parent.get_parent()
	return true


func _scroll_at(position: Vector2) -> ScrollContainer:
	var found: ScrollContainer = null
	for node in root.find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(position):
			found = scroll # o mais interno vence (aparece depois na busca)
	return found
