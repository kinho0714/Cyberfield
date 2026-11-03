extends CanvasLayer

signal run_requested(mode: StringName, difficulty: StringName, joypad_device_id: int)
signal lan_requested
## 03/11: destinos das páginas novas. Os painéis (campanhas, social, sessão privada)
## pertencem ao CampaignController; este menu só navega e emite a intenção.
signal campaign_requested(action: StringName)
signal social_requested(tab: StringName)
signal private_session_requested(tab: StringName)

@onready var main_page: VBoxContainer = $Overlay/Center/MainPage
@onready var players_page: VBoxContainer = $Overlay/Center/PlayersPage
@onready var difficulty_page: VBoxContainer = $Overlay/Center/DifficultyPage
@onready var coop_page: VBoxContainer = $Overlay/Center/CoopPage
@onready var solo_page: VBoxContainer = $Overlay/Center/SoloPage
@onready var social_page: VBoxContainer = $Overlay/Center/SocialPage
@onready var continue_button: Button = $Overlay/Center/SoloPage/Continue
@onready var create_button: Button = $Overlay/Center/SoloPage/Create
@onready var quick_button: Button = $Overlay/Center/SoloPage/Quick
@onready var solo_status: Label = $Overlay/Center/SoloPage/Status
@onready var social_button: Button = $Overlay/Center/MainPage/Social
@onready var social_status: Label = $Overlay/Center/SocialPage/Status
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
## Tipo de coop escolhido antes da dificuldade: &"local" (mesmo dispositivo) ou &"lan".
var coop_kind: StringName = &"local"
## Fornecidos pelo CampaignController: Callable() -> {"status": String, "continue": bool}.
var solo_state_provider: Callable
var social_state_provider: Callable


func _ready() -> void:
	play_button.pressed.connect(func() -> void: _show_page(players_page, solo_button))
	social_button.pressed.connect(show_social_page)
	$Overlay/Center/MainPage/Options.pressed.connect(_open_options)
	$Overlay/Center/MainPage/Quit.pressed.connect(get_tree().quit)
	solo_button.pressed.connect(show_solo_page)
	coop_button.pressed.connect(show_coop_page)
	start_button.pressed.connect(func() -> void: _choose_coop(&"local"))
	lan_button.pressed.connect(func() -> void: _choose_coop(&"lan"))
	$Overlay/Center/PlayersPage/Back.pressed.connect(show_main_page)
	continue_button.pressed.connect(func() -> void: _emit_campaign(&"continue"))
	create_button.pressed.connect(func() -> void: _emit_campaign(&"create"))
	$Overlay/Center/SoloPage/Manage.pressed.connect(func() -> void: _emit_campaign(&"manage"))
	quick_button.pressed.connect(func() -> void: _select_mode(&"solo"))
	$Overlay/Center/SoloPage/Back.pressed.connect(func() -> void: _show_page(players_page, solo_button))
	for pair in [[&"PrivateCreate", &"create"], [&"PrivateJoin", &"join"], [&"Invites", &"invites"]]:
		coop_page.get_node(String(pair[0])).pressed.connect(_emit_private.bind(pair[1]))
	for pair in [[&"Profile", &"profile"], [&"Friends", &"friends"], [&"Requests", &"requests"], [&"Blocked", &"blocked"]]:
		social_page.get_node(String(pair[0])).pressed.connect(_emit_social.bind(pair[1]))
	$Overlay/Center/SocialPage/Back.pressed.connect(func() -> void: _show_page(main_page, social_button))
	for status in [solo_status, social_status, controller_label]:
		status.add_theme_font_size_override("font_size", 17)
		status.add_theme_color_override("font_color", Color("7f97a8"))
	normal_button.pressed.connect(func() -> void: _select_difficulty(&"normal"))
	$Overlay/Center/DifficultyPage/Hard.pressed.connect(func() -> void: _select_difficulty(&"hard"))
	$Overlay/Center/DifficultyPage/Pro.pressed.connect(func() -> void: _select_difficulty(&"pro"))
	$Overlay/Center/DifficultyPage/InfernoPro.pressed.connect(func() -> void: _select_difficulty(&"inferno_pro"))
	$Overlay/Center/DifficultyPage/Back.pressed.connect(_back_to_modes)
	$Overlay/Center/CoopPage/Back.pressed.connect(func() -> void: _show_page(players_page, coop_button))
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
			_show_page(players_page, coop_button)
		elif solo_page.visible:
			_show_page(players_page, solo_button)
		elif difficulty_page.visible:
			_back_to_modes()
		elif players_page.visible:
			show_main_page()
		elif social_page.visible:
			_show_page(main_page, social_button)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		# Mouse emulation is disabled in the project; touch activates once on press.
		for page in _pages():
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


## Dificuldade para PARTIDA AVULSA (solo, perfil clássico) ou para o coop escolhido.
func _select_mode(mode: StringName) -> void:
	selected_mode = mode
	_refresh_controller()
	_show_page(difficulty_page, normal_button)


func _select_difficulty(difficulty: StringName) -> void:
	selected_difficulty = difficulty
	if selected_mode == &"solo" or coop_kind == &"local":
		_request_run()
	else:
		_request_lan()


func _choose_coop(kind: StringName) -> void:
	if kind == &"local" and start_button.disabled:
		return
	coop_kind = kind
	_select_mode(&"coop")


func _back_to_modes() -> void:
	if selected_mode == &"coop":
		_show_page(coop_page, lan_button if coop_kind == &"lan" or start_button.disabled else start_button)
	else:
		show_solo_page(quick_button)


func show_solo_page(focus: Control = null) -> void:
	var state: Dictionary = solo_state_provider.call() if solo_state_provider.is_valid() else {}
	continue_button.disabled = not bool(state.get("continue", false))
	solo_status.text = String(state.get("status", "CAMPANHAS INDISPONÍVEIS"))
	if focus == null or (focus is BaseButton and (focus as BaseButton).disabled):
		focus = create_button if continue_button.disabled else continue_button
	_show_page(solo_page, focus)


func show_coop_page() -> void:
	_refresh_controller()
	_show_page(coop_page, lan_button if start_button.disabled else start_button)


func show_social_page(focus_name: StringName = &"Profile") -> void:
	var state: Dictionary = social_state_provider.call() if social_state_provider.is_valid() else {}
	social_status.text = String(state.get("status", "PERFIL LOCAL • OFFLINE"))
	_show_page(social_page, social_page.get_node(String(focus_name)) as Control)


## Usado pelos painéis ao voltar: reabre a página de origem com o foco no botão de origem.
func return_to(page: StringName, focus_name: StringName = &"") -> void:
	visible = true
	requesting_run = false
	match page:
		&"solo":
			show_solo_page(solo_page.get_node_or_null(String(focus_name)) as Control)
		&"coop":
			_refresh_controller()
			var target := coop_page.get_node_or_null(String(focus_name)) as Control
			_show_page(coop_page, target if target != null else lan_button)
		&"social":
			show_social_page(focus_name if social_page.has_node(String(focus_name)) else &"Profile")
		_:
			show_main_page()


func _emit_campaign(action: StringName) -> void:
	if requesting_run:
		return
	campaign_requested.emit(action)


func _emit_private(tab: StringName) -> void:
	if requesting_run:
		return
	private_session_requested.emit(tab)


func _emit_social(tab: StringName) -> void:
	social_requested.emit(tab)


func _pages() -> Array:
	return [main_page, players_page, difficulty_page, coop_page, solo_page, social_page]


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
	for candidate in _pages():
		candidate.visible = candidate == page
	initial_focus.grab_focus()


func _refresh_controller() -> void:
	var connected := Input.get_connected_joypads()
	selected_joypad_device_id = connected[0] if not connected.is_empty() else -1
	start_button.disabled = selected_joypad_device_id < 0
	controller_label.text = tr("CONTROLE P2: %s") % Input.get_joy_name(selected_joypad_device_id) if selected_joypad_device_id >= 0 else "MESMO DISPOSITIVO: CONECTE UM CONTROLE P2"
	if start_button.disabled and start_button.has_focus():
		lan_button.grab_focus()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_controller()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_controller()
