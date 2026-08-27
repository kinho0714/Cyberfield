extends CanvasLayer

signal run_requested(mode: StringName, difficulty: StringName, joypad_device_id: int)
signal lan_requested

const MODE_LABELS := {&"solo": "1 JOGADOR", &"coop": "2 JOGADORES"}
const DIFFICULTY_LABELS := {&"normal": "NORMAL", &"hard": "DIFÍCIL", &"pro": "PRO", &"inferno_pro": "INFERNO DO PRO"}

@onready var main_page: VBoxContainer = $Overlay/Center/MainPage
@onready var players_page: VBoxContainer = $Overlay/Center/PlayersPage
@onready var difficulty_page: VBoxContainer = $Overlay/Center/DifficultyPage
@onready var confirm_page: VBoxContainer = $Overlay/Center/ConfirmPage
@onready var play_button: Button = $Overlay/Center/MainPage/Play
@onready var solo_button: Button = $Overlay/Center/PlayersPage/Solo
@onready var coop_button: Button = $Overlay/Center/PlayersPage/Coop
@onready var lan_button: Button = $Overlay/Center/PlayersPage/Lan
@onready var normal_button: Button = $Overlay/Center/DifficultyPage/Normal
@onready var confirm_label: Label = $Overlay/Center/ConfirmPage/Selection
@onready var controller_label: Label = $Overlay/Center/ConfirmPage/Controller
@onready var start_button: Button = $Overlay/Center/ConfirmPage/Start

var selected_mode: StringName = &"solo"
var selected_difficulty: StringName = &"normal"
var selected_joypad_device_id := -1


func _ready() -> void:
	play_button.pressed.connect(func() -> void: _show_page(players_page, solo_button))
	solo_button.pressed.connect(func() -> void: _select_mode(&"solo"))
	coop_button.pressed.connect(func() -> void: _select_mode(&"coop"))
	lan_button.pressed.connect(func() -> void: lan_requested.emit())
	$Overlay/Center/PlayersPage/Back.pressed.connect(show_main_page)
	normal_button.pressed.connect(func() -> void: _select_difficulty(&"normal"))
	$Overlay/Center/DifficultyPage/Hard.pressed.connect(func() -> void: _select_difficulty(&"hard"))
	$Overlay/Center/DifficultyPage/Pro.pressed.connect(func() -> void: _select_difficulty(&"pro"))
	$Overlay/Center/DifficultyPage/InfernoPro.pressed.connect(func() -> void: _select_difficulty(&"inferno_pro"))
	$Overlay/Center/DifficultyPage/Back.pressed.connect(func() -> void: _show_page(players_page, solo_button))
	$Overlay/Center/ConfirmPage/Back.pressed.connect(func() -> void: _show_page(difficulty_page, normal_button))
	start_button.pressed.connect(_request_run)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	show_main_page()


func show_main_page() -> void:
	selected_mode = &"solo"
	selected_difficulty = &"normal"
	selected_joypad_device_id = -1
	_refresh_controller()
	_show_page(main_page, play_button)


func focus_default() -> void:
	show_main_page()


func _select_mode(mode: StringName) -> void:
	selected_mode = mode
	_refresh_controller()
	_show_page(difficulty_page, normal_button)


func _select_difficulty(difficulty: StringName) -> void:
	selected_difficulty = difficulty
	_refresh_confirmation()
	_show_page(confirm_page, start_button)


func _request_run() -> void:
	_refresh_controller()
	if selected_mode == &"coop" and selected_joypad_device_id < 0:
		return
	start_button.disabled = true
	run_requested.emit(selected_mode, selected_difficulty, selected_joypad_device_id)


func _show_page(page: VBoxContainer, initial_focus: Control) -> void:
	for candidate in [main_page, players_page, difficulty_page, confirm_page]:
		candidate.visible = candidate == page
	if page == confirm_page:
		_refresh_confirmation()
	initial_focus.grab_focus()


func _refresh_confirmation() -> void:
	var warning := "\nQUANTIDADE EXTREMA DE INIMIGOS" if selected_difficulty == &"inferno_pro" else ""
	var enemy_hp := CombatStats.scaled_health(CombatStats.COMMON_ENEMY_BASE_HP, selected_difficulty)
	var boss_hp := CombatStats.scaled_health(CombatStats.BOSS_BASE_HP, selected_difficulty)
	confirm_label.text = (
		"MODO: %s\nDIFICULDADE: %s\nENEMY NORMAL: %d HP\nCHEFE: %d HP%s"
		% [MODE_LABELS[selected_mode], DIFFICULTY_LABELS[selected_difficulty], enemy_hp, boss_hp, warning]
	)
	_refresh_controller()


func _refresh_controller() -> void:
	var connected := Input.get_connected_joypads()
	selected_joypad_device_id = connected[0] if not connected.is_empty() else -1
	if selected_mode == &"coop":
		if selected_joypad_device_id >= 0:
			controller_label.text = "CONTROLE P2: %s (ID %d)" % [Input.get_joy_name(selected_joypad_device_id), selected_joypad_device_id]
			start_button.disabled = false
		else:
			controller_label.text = "CONECTE UM CONTROLE PARA O PLAYER 2"
			start_button.disabled = true
	else:
		controller_label.text = "PLAYER 1: TECLADO E MOUSE"
		start_button.disabled = false


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_controller()
