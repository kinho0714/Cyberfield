class_name LoadingTransition
extends CanvasLayer
## Main-thread scene transaction. Only ResourceLoader performs background resource IO.
signal completed(success: bool)
var error_visible := false
var waiting_for_connection := false
var holds := 0
var active := false
var cancelled := false
var _sealed := false
var _abandoned: Dictionary = {}
var last_error := ""
var generation := 0
var _was_paused := false
var _panel: ColorRect
var _label: Label
var _bar: ProgressBar
var _close: Button
var _touch_router: TouchScrollRouter
var _resources: Dictionary = {}
var _started_us := 0
var last_duration_us := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_panel = ColorRect.new()
	_panel.color = Color("080e1b")
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 120)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := Label.new()
	title.text = "CYBERFIELD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("39dff2"))
	box.add_child(title)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 12
	_bar.show_percentage = false
	box.add_child(_bar)
	_close = Button.new()
	_close.text = "VOLTAR"
	_close.pressed.connect(func() -> void:
		if active:
			cancel()
		else:
			dismiss_error())
	box.add_child(_close)
	ContentRegistry.apply_ui_theme(_panel)
	_touch_router = TouchScrollRouter.new(_panel)
	_panel.hide()
	set_process(false)

func begin(message := "Preparando ambiente…") -> bool:
	if active:
		return false
	if error_visible:
		error_visible = false
		get_tree().paused = _was_paused
	active = true
	cancelled = false
	_sealed = false
	generation += 1
	last_error = ""
	_started_us = Time.get_ticks_usec()
	_was_paused = get_tree().paused
	get_tree().paused = true
	_close.text = "CANCELAR"
	_close.disabled = false
	_close.show()
	_bar.show()
	_panel.show()
	stage(message)
	return true

func stage(message: String) -> void:
	_label.text = message
	_bar.indeterminate = true

func load_scene(path: String) -> PackedScene:
	if cancelled:
		return null
	if not active or not ResourceLoader.exists(path, "PackedScene"):
		last_error = "Cena indisponível. Arquivos e saves preservados."
		return null
	_sealed = false
	_close.show()
	if _resources.has(path):
		return _resources[path] as PackedScene
	var token := generation
	stage("Carregando região…")
	# Present the overlay before requesting IO or instantiating anything.
	await get_tree().process_frame
	if cancelled or token != generation:
		return null
	var result: Error = OK
	if _abandoned.has(path):
		_abandoned.erase(path)
	else:
		result = ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if result != OK:
		last_error = "Não foi possível iniciar o carregamento."
		return null
	var deadline := Time.get_ticks_msec() + 60000
	while active and token == generation:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			if packed == null:
				last_error = "Recurso de cena inválido."
			else:
				if _resources.size() >= 2:
					_resources.erase(_resources.keys()[0])
				_resources[path] = packed
				stage("Preparando ambiente…")
			return packed
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS or Time.get_ticks_msec() >= deadline:
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_abandoned[path] = true
				set_process(true)
			last_error = "Falha ou tempo limite no carregamento. Tente novamente."
			return null
		_bar.indeterminate = progress.is_empty()
		if not progress.is_empty():
			_bar.value = clampf(float(progress[0]), 0.0, 1.0) * 100.0
		await get_tree().process_frame
	_abandoned[path] = true
	set_process(true)
	last_error = "Carregamento cancelado."
	return null

func finish(success := true) -> void:
	if not active:
		return
	seal()
	stage("Preparando câmera e controles…")
	# Allow queued frees, ready/deferred setup and restored transforms to settle.
	await get_tree().process_frame
	last_duration_us = Time.get_ticks_usec() - _started_us
	active = false
	if success and not cancelled:
		get_tree().paused = _was_paused
		if not waiting_for_connection:
			_panel.hide()
	else:
		error_visible = true
		get_tree().paused = true
		_label.text = last_error if not last_error.is_empty() else "Falha ao preparar região. Save preservado."
		_bar.hide()
		_close.text = "VOLTAR"
		_close.disabled = false
		_close.show()
	completed.emit(success and not cancelled)

func cancel() -> void:
	if active and not _sealed:
		generation += 1
		cancelled = true
		last_error = "Carregamento cancelado. Save preservado."
		stage("Cancelando carregamento…")
		_close.disabled = true


func show_connection_wait() -> void:
	waiting_for_connection = true
	_close.hide()
	_panel.show()
	_bar.show()
	stage("Sincronizando sessão… Aguardando reconexão.")


func clear_connection_wait() -> void:
	waiting_for_connection = false
	if not active and not error_visible:
		_panel.hide()


func seal() -> void:
	# No cancel between committing a prepared room and exposing its validated state.
	_sealed = true
	_close.hide()


func _process(_delta: float) -> void:
	# ResourceLoader has no forced cancellation API. Drain only completed workers;
	# never block the main thread waiting for an abandoned request.
	for path: String in _abandoned.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
			_abandoned.erase(path)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_abandoned.erase(path)
	set_process(not _abandoned.is_empty())


func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if _touch_router.handle(event):
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventJoypadButton:
		if event.is_action_pressed(&"ui_cancel"):
			if active:
				cancel()
			elif not waiting_for_connection:
				dismiss_error()
		elif event.is_action_pressed(&"ui_accept") and _close.visible and not _close.disabled:
			_close.pressed.emit()
		# Gameplay and always-processing modals must not consume loading inputs.
		get_viewport().set_input_as_handled()


func dismiss_error() -> void:
	if not error_visible:
		return
	error_visible = false
	get_tree().paused = _was_paused
	if not waiting_for_connection:
		_panel.hide()
	var game: Node = get_parent()
	game._set_all_player_input(game.mode_selected and not game.is_transitioning and not _was_paused)
