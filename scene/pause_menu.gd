extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var main_page: VBoxContainer = $Overlay/Center/MainPage
@onready var settings_page: VBoxContainer = $Overlay/Center/SettingsPage
@onready var zoom_option: OptionButton = $Overlay/Center/SettingsPage/CameraZoom
@onready var touch_slider: HSlider = $Overlay/Center/SettingsPage/TouchScale
@onready var touch_value: Label = $Overlay/Center/SettingsPage/TouchValue
@onready var debug_toggle: CheckButton = $Overlay/Center/SettingsPage/DebugHud
@onready var local_settings: LocalSettings = get_parent().get_node("LocalSettings")

var input_blocked_players: Array[Node] = []
var tree_paused_by_menu := false


func _ready() -> void:
	add_to_group("pause_menu")
	overlay.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Overlay/Center/MainPage/Continue.pressed.connect(close_menu)
	$Overlay/Center/MainPage/Inventory.pressed.connect(_open_inventory)
	$Overlay/Center/MainPage/Settings.pressed.connect(_show_settings)
	$Overlay/Center/MainPage/Abandon.pressed.connect(_abandon_run)
	$Overlay/Center/MainPage/MainMenu.pressed.connect(_return_to_main_menu)
	$Overlay/Center/SettingsPage/Back.pressed.connect(_show_main)
	zoom_option.item_selected.connect(_set_camera_zoom)
	touch_slider.value_changed.connect(_set_touch_scale)
	debug_toggle.toggled.connect(_set_debug_hud)
	for entry: Array in [["PRÓXIMO", &"close"], ["PADRÃO", &"default"], ["DISTANTE", &"distant"]]:
		zoom_option.add_item(String(entry[0]))
		zoom_option.set_item_metadata(zoom_option.item_count - 1, entry[1])
	_load_controls()


func _input(event: InputEvent) -> void:
	if (event.is_action_pressed(&"pause_menu") or event.is_action_pressed(&"ui_cancel")) and not event.is_echo():
		var inventory := get_tree().get_first_node_in_group("inventory_ui")
		if inventory != null and inventory.overlay.visible:
			inventory.close_inventory()
			get_viewport().set_input_as_handled()
			return
		var full_map := get_tree().get_first_node_in_group("full_map")
		if full_map != null and full_map.visible:
			full_map.close_map()
			get_viewport().set_input_as_handled()
			return
		toggle_menu()
		get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	if overlay.visible:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	var attribute_ui := get_tree().get_first_node_in_group("attribute_choice_ui")
	if attribute_ui != null and attribute_ui.visible:
		return
	var room_manager := get_parent()
	if not bool(room_manager.mode_selected) or bool(room_manager.is_transitioning):
		return
	_block_local_gameplay_input()
	var lan_session: LanSession = get_parent().get_node("LanSession")
	if not lan_session.is_network_game():
		get_tree().paused = true
		tree_paused_by_menu = true
	get_parent().get_node("TouchControls").set_menu_blocked(true)
	_load_controls()
	_show_main()
	overlay.visible = true
	$Overlay/Center/MainPage/Continue.grab_focus()


func close_menu() -> void:
	if tree_paused_by_menu:
		get_tree().paused = false
		tree_paused_by_menu = false
	overlay.visible = false
	get_parent().get_node("TouchControls").set_menu_blocked(false)
	for player in input_blocked_players:
		if is_instance_valid(player):
			player.set_input_enabled(true)
	input_blocked_players.clear()


func _block_local_gameplay_input() -> void:
	input_blocked_players.clear()
	var lan_session: LanSession = get_parent().get_node("LanSession")
	for player in get_parent().get_players():
		var is_local_player: bool = not lan_session.is_network_game()
		if lan_session.is_host() and player.participant_id == &"player_1":
			is_local_player = true
		elif lan_session.is_client() and player.participant_id == &"player_2":
			is_local_player = true
		if is_local_player and player.input_enabled:
			player.set_input_enabled(false)
			input_blocked_players.append(player)


func _show_main() -> void:
	main_page.visible = true
	settings_page.visible = false


func _show_settings() -> void:
	main_page.visible = false
	settings_page.visible = true
	zoom_option.grab_focus()


func _open_inventory() -> void:
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	if inventory == null:
		return
	close_menu()
	inventory.open_from_pause()


func _load_controls() -> void:
	for index in zoom_option.item_count:
		if StringName(zoom_option.get_item_metadata(index)) == local_settings.camera_zoom_preference:
			zoom_option.select(index)
			break
	touch_slider.set_value_no_signal(local_settings.touch_control_scale * 100.0)
	touch_value.text = "%d%%" % int(round(local_settings.touch_control_scale * 100.0))
	debug_toggle.set_pressed_no_signal(local_settings.debug_hud_visible)


func _set_camera_zoom(index: int) -> void:
	local_settings.set_camera_zoom_preference(StringName(zoom_option.get_item_metadata(index)))


func _set_touch_scale(value: float) -> void:
	local_settings.set_touch_control_scale(value / 100.0)
	touch_value.text = "%d%%" % int(round(value))


func _set_debug_hud(value: bool) -> void:
	local_settings.set_debug_hud_visible(value)


func _abandon_run() -> void:
	close_menu()
	get_parent().abandon_current_run()


func _return_to_main_menu() -> void:
	close_menu()
	get_parent().return_to_main_menu()
