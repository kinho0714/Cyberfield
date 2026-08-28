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
var settings_slider_touch_index := -1


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
		return
	if not overlay.visible:
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_handle_screen_touch_pressed(touch_event)
		elif touch_event.index == settings_slider_touch_index:
			settings_slider_touch_index = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == settings_slider_touch_index:
			_update_touch_slider(drag_event.position)
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
	settings_slider_touch_index = -1
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
		if player.participant_id == lan_session.get_local_participant_id():
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


func _handle_screen_touch_pressed(event: InputEventScreenTouch) -> void:
	var position: Vector2 = event.position
	if settings_page.visible:
		if _touch_hits($Overlay/Center/SettingsPage/Back, position):
			_show_main()
		elif _touch_hits(zoom_option, position):
			_cycle_camera_zoom()
		elif _touch_hits(debug_toggle, position):
			var next_debug_value: bool = not debug_toggle.button_pressed
			debug_toggle.set_pressed_no_signal(next_debug_value)
			_set_debug_hud(next_debug_value)
		elif _touch_hits(touch_slider, position):
			settings_slider_touch_index = event.index
			_update_touch_slider(position)
		else:
			return
	else:
		if _touch_hits($Overlay/Center/MainPage/Continue, position):
			close_menu()
		elif _touch_hits($Overlay/Center/MainPage/Inventory, position):
			_open_inventory()
		elif _touch_hits($Overlay/Center/MainPage/Settings, position):
			_show_settings()
		elif _touch_hits($Overlay/Center/MainPage/Abandon, position):
			_abandon_run()
		elif _touch_hits($Overlay/Center/MainPage/MainMenu, position):
			_return_to_main_menu()
		else:
			return
	get_viewport().set_input_as_handled()


func _touch_hits(control: Control, position: Vector2) -> bool:
	return control.is_visible_in_tree() and control.get_global_rect().has_point(position)


func _cycle_camera_zoom() -> void:
	if zoom_option.item_count <= 0:
		return
	var next_index: int = wrapi(zoom_option.selected + 1, 0, zoom_option.item_count)
	zoom_option.select(next_index)
	_set_camera_zoom(next_index)


func _update_touch_slider(position: Vector2) -> void:
	var slider_rect: Rect2 = touch_slider.get_global_rect()
	if slider_rect.size.x <= 0.0:
		return
	var ratio: float = clampf((position.x - slider_rect.position.x) / slider_rect.size.x, 0.0, 1.0)
	touch_slider.value = lerpf(touch_slider.min_value, touch_slider.max_value, ratio)


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
