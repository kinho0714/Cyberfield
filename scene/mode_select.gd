extends CanvasLayer

signal run_requested(mode: StringName, difficulty: StringName, joypad_device_id: int)
signal lan_requested

@onready var main_page: VBoxContainer = $Overlay/Center/MainPage
@onready var players_page: VBoxContainer = $Overlay/Center/PlayersPage
@onready var difficulty_page: VBoxContainer = $Overlay/Center/DifficultyPage
@onready var coop_page: VBoxContainer = $Overlay/Center/CoopPage
@onready var play_button: Button = $Overlay/Center/MainPage/Play
@onready var solo_button: Button = $Overlay/Center/PlayersPage/Solo
@onready var coop_button: Button = $Overlay/Center/PlayersPage/Coop
@onready var lan_button: Button = $Overlay/Center/CoopPage/Lan
@onready var normal_button: Button = $Overlay/Center/DifficultyPage/Normal
@onready var controller_label: Label = $Overlay/Center/CoopPage/Controller
@onready var start_button: Button = $Overlay/Center/CoopPage/Start

var selected_mode: StringName = &"solo"
var selected_difficulty: StringName = &"normal"
var selected_joypad_device_id := -1
var returning_from_lan := false
var requesting_run := false


func _ready() -> void:
	play_button.pressed.connect(func() -> void: _show_page(players_page, solo_button))
	$Overlay/Center/MainPage/Options.pressed.connect(_open_options)
	$Overlay/Center/MainPage/Quit.pressed.connect(get_tree().quit)
	solo_button.pressed.connect(func() -> void: _select_mode(&"solo"))
	coop_button.pressed.connect(func() -> void: _select_mode(&"coop"))
	lan_button.pressed.connect(_request_lan)
	$Overlay/Center/PlayersPage/Back.pressed.connect(show_main_page)
	normal_button.pressed.connect(func() -> void: _select_difficulty(&"normal"))
	$Overlay/Center/DifficultyPage/Hard.pressed.connect(func() -> void: _select_difficulty(&"hard"))
	$Overlay/Center/DifficultyPage/Pro.pressed.connect(func() -> void: _select_difficulty(&"pro"))
	$Overlay/Center/DifficultyPage/InfernoPro.pressed.connect(func() -> void: _select_difficulty(&"inferno_pro"))
	$Overlay/Center/DifficultyPage/Back.pressed.connect(_back_to_modes)
	$Overlay/Center/CoopPage/Back.pressed.connect(_back_to_difficulty)
	start_button.pressed.connect(_request_run)
	get_parent().get_node("LanLobby").close_requested.connect(_mark_lan_return)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	show_main_page()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if requesting_run:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		if coop_page.visible:
			_back_to_difficulty()
		elif difficulty_page.visible:
			_back_to_modes()
		elif players_page.visible:
			show_main_page()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		# Mouse emulation is disabled in the project; touch activates once on press.
		for page in [main_page, players_page, difficulty_page, coop_page]:
			if not page.visible:
				continue
			for child in page.get_children():
				if child is Button and not child.disabled and child.get_global_rect().has_point(event.position):
					child.grab_focus()
					get_viewport().set_input_as_handled()
					child.pressed.emit()
					return


func show_main_page() -> void:
	requesting_run = false
	returning_from_lan = false
	selected_mode = &"solo"
	selected_difficulty = &"normal"
	_refresh_controller()
	_show_page(main_page, play_button)


func focus_default() -> void:
	requesting_run = false
	if returning_from_lan and not get_parent().mode_selected:
		returning_from_lan = false
		_refresh_controller()
		_show_page(coop_page, lan_button)
	else:
		show_main_page()


func _select_mode(mode: StringName) -> void:
	selected_mode = mode
	_refresh_controller()
	_show_page(difficulty_page, normal_button)


func _select_difficulty(difficulty: StringName) -> void:
	selected_difficulty = difficulty
	if selected_mode == &"solo":
		_request_run()
	else:
		_refresh_controller()
		_show_page(coop_page, lan_button if start_button.disabled else start_button)


func _back_to_modes() -> void:
	_show_page(players_page, coop_button if selected_mode == &"coop" else solo_button)


func _back_to_difficulty() -> void:
	var names := {&"normal": "Normal", &"hard": "Hard", &"pro": "Pro", &"inferno_pro": "InfernoPro"}
	_show_page(difficulty_page, difficulty_page.get_node(names[selected_difficulty]) as Control)


func _request_run() -> void:
	if requesting_run:
		return
	_refresh_controller()
	if selected_mode == &"coop" and selected_joypad_device_id < 0:
		return
	requesting_run = true
	get_viewport().gui_release_focus()
	run_requested.emit(selected_mode, selected_difficulty, selected_joypad_device_id)


func _request_lan() -> void:
	# Only initialize the existing lobby UI; host authority and protocol are unchanged.
	var lobby := get_parent().get_node("LanLobby")
	var choice := lobby.get_node("Overlay/Center/HostPage/Difficulty") as OptionButton
	for index in choice.item_count:
		if StringName(choice.get_item_metadata(index)) == selected_difficulty:
			choice.select(index)
			break
	lan_requested.emit()


func _mark_lan_return() -> void:
	returning_from_lan = true


func _open_options() -> void:
	get_viewport().gui_release_focus()
	visible = false
	get_parent().get_node("PauseMenu").open_title_settings()


func return_from_options() -> void:
	visible = true
	_show_page(main_page, $Overlay/Center/MainPage/Options)


func _show_page(page: VBoxContainer, initial_focus: Control) -> void:
	get_viewport().gui_release_focus()
	for candidate in [main_page, players_page, difficulty_page, coop_page]:
		candidate.visible = candidate == page
	initial_focus.grab_focus()


func _refresh_controller() -> void:
	var connected := Input.get_connected_joypads()
	selected_joypad_device_id = connected[0] if not connected.is_empty() else -1
	start_button.disabled = selected_joypad_device_id < 0
	controller_label.text = "CONTROLE P2: %s" % Input.get_joy_name(selected_joypad_device_id) if selected_joypad_device_id >= 0 else "CONECTE UM CONTROLE PARA O PLAYER 2"
	if start_button.disabled and start_button.has_focus():
		lan_button.grab_focus()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_controller()
