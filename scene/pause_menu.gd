extends CanvasLayer

const PANEL_PRESENTATION = preload("res://ui/menu_panel_presentation.gd")

@onready var overlay: ColorRect = $Overlay
@onready var main_page: VBoxContainer = $Overlay/Center/MainPage
@onready var settings_page: VBoxContainer = $Overlay/Center/SettingsPage
@onready var zoom_option: OptionButton = $Overlay/Center/SettingsPage/Scroll/Content/CameraZoom
@onready var language_option: OptionButton = $Overlay/Center/SettingsPage/Scroll/Content/LanguageOption
@onready var touch_slider: HSlider = $Overlay/Center/SettingsPage/Scroll/Content/TouchScale
@onready var touch_value: Label = $Overlay/Center/SettingsPage/Scroll/Content/TouchValue
@onready var debug_toggle: CheckButton = $Overlay/Center/SettingsPage/Scroll/Content/DebugHud
@onready var local_settings: LocalSettings = get_parent().get_node("LocalSettings")

var input_blocked_players: Array[Node] = []
var tree_paused_by_menu := false
var settings_slider_touch_index := -1
var title_settings := false
var active_touch_slider: HSlider
var options_touch_index: int = -1
var options_touch_origin: Vector2
var options_scroll_origin: int = 0
var options_gesture: int = 0 # 0 pending, 1 vertical scroll, 2 horizontal slider
const OPTIONS_DRAG_THRESHOLD: float = 12.0
var audio_sliders: Array[HSlider] = []
var category_buttons: Array[Button] = []
var selected_category: int = 0
const AUDIO_LABELS: Array[String] = ["Volume Geral", "Música", "Ambiente", "Efeitos Sonoros", "Diálogos"]
@onready var settings_scroll: ScrollContainer = $Overlay/Center/SettingsPage/Scroll
@onready var settings_content: VBoxContainer = $Overlay/Center/SettingsPage/Scroll/Content


func _ready() -> void:
	add_to_group("pause_menu")
	overlay.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Overlay/Center/MainPage/Continue.pressed.connect(close_menu)
	$Overlay/Center/MainPage/Inventory.pressed.connect(_open_inventory)
	$Overlay/Center/MainPage/Settings.pressed.connect(_show_settings)
	$Overlay/Center/MainPage/Abandon.pressed.connect(_abandon_run)
	$Overlay/Center/MainPage/MainMenu.pressed.connect(_return_to_main_menu)
	$Overlay/Center/SettingsPage/Back.pressed.connect(_settings_back)
	zoom_option.item_selected.connect(_set_camera_zoom)
	language_option.add_item("Português (Brasil)")
	language_option.add_item("English")
	language_option.item_selected.connect(func(index: int) -> void:
		local_settings.set_language("pt_BR" if index == 0 else "en"))
	touch_slider.value_changed.connect(_set_touch_scale)
	debug_toggle.toggled.connect(_set_debug_hud)
	for entry: Array in [["PRÓXIMO", &"close"], ["PADRÃO", &"default"], ["DISTANTE", &"distant"]]:
		zoom_option.add_item(String(entry[0]))
		zoom_option.set_item_metadata(zoom_option.item_count - 1, entry[1])
	for bus: StringName in LocalSettings.AUDIO_BUSES:
		var slider: HSlider = settings_content.get_node(String(bus) + "Volume") as HSlider
		audio_sliders.append(slider)
		_style_audio_slider(slider)
		slider.value_changed.connect(_set_audio_volume.bind(bus))
	get_viewport().size_changed.connect(_fit_settings_scroll)
	_fit_settings_scroll()
	_load_controls()
	PANEL_PRESENTATION.apply_pause(main_page, settings_page, settings_content)
	_build_categories()
	get_viewport().size_changed.connect(_layout_panels)
	call_deferred("_layout_panels")


func _fit_settings_scroll() -> void:
	# Title and Back stay outside the scroll region and remain reachable.
	settings_scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 360.0, 160.0, 320.0)


func _input(event: InputEvent) -> void:
	if not overlay.visible and not get_parent().mode_selected:
		return
	if overlay.visible and (zoom_option.get_popup().visible or language_option.get_popup().visible):
		return
	# B / Circle also performs dash. It may cancel an open menu, but must never
	# open Pause from gameplay when the overlay is closed.
	var pause_pressed: bool = event.is_action_pressed(&"pause_menu")
	var cancel_pressed: bool = overlay.visible and event.is_action_pressed(&"ui_cancel")
	if (pause_pressed or cancel_pressed) and not event.is_echo():
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
		if title_settings or (overlay.visible and settings_page.visible):
			_settings_back()
		else:
			toggle_menu()
		get_viewport().set_input_as_handled()
		return
	if not overlay.visible:
		return
	if _handle_options_gesture(event):
		get_viewport().set_input_as_handled()
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


func open_title_settings() -> void:
	title_settings = true
	_load_controls()
	overlay.visible = true
	_show_settings()


func _settings_back() -> void:
	_cancel_options_gesture()
	if title_settings:
		title_settings = false
		settings_slider_touch_index = -1
		get_viewport().gui_release_focus()
		overlay.visible = false
		get_parent().get_node("ModeSelect").return_from_options()
	else:
		_show_main()
		$Overlay/Center/MainPage/Settings.grab_focus()


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
	_cancel_options_gesture()
	get_viewport().gui_release_focus()
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
	_cancel_options_gesture()
	$Overlay/Center/MainPage/SessionSummary.text = get_parent().get_node("RunDebugHUD").get_session_summary(true)
	main_page.visible = true
	settings_page.visible = false


func _show_settings() -> void:
	_cancel_options_gesture()
	main_page.visible = not title_settings
	settings_page.visible = true
	_select_category(0)
	call_deferred("_layout_panels")
	zoom_option.grab_focus()


func _handle_screen_touch_pressed(event: InputEventScreenTouch) -> void:
	var position: Vector2 = event.position
	# Sidebar stays usable while Settings is open. Calls the original actions.
	if settings_page.visible and main_page.visible:
		var actions: Dictionary = {"Continue": close_menu, "Inventory": _open_inventory,
			"Settings": _show_settings, "Abandon": _abandon_run, "MainMenu": _return_to_main_menu}
		for key: String in actions:
			if _touch_hits(main_page.get_node(key) as Control, position):
				actions[key].call()
				get_viewport().set_input_as_handled()
				return
	if settings_page.visible:
		if _touch_hits($Overlay/Center/SettingsPage/Back, position):
			_settings_back()
		elif _touch_hits(zoom_option, position):
			zoom_option.show_popup()
		elif _touch_hits(language_option, position):
			language_option.show_popup()
		elif _touch_hits(debug_toggle, position):
			var next_debug_value: bool = not debug_toggle.button_pressed
			debug_toggle.set_pressed_no_signal(next_debug_value)
			_set_debug_hud(next_debug_value)
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
	if not control.is_visible_in_tree() or not control.get_global_rect().has_point(position):
		return false
	if settings_content.is_ancestor_of(control) and not settings_scroll.get_global_rect().has_point(position):
		return false
	if control is BaseButton and control.disabled:
		return false
	control.grab_focus()
	return true


func _update_touch_slider(position: Vector2) -> void:
	if active_touch_slider == null:
		return
	var slider_rect: Rect2 = active_touch_slider.get_global_rect()
	if slider_rect.size.x <= 0.0:
		return
	var ratio: float = clampf((position.x - slider_rect.position.x) / slider_rect.size.x, 0.0, 1.0)
	active_touch_slider.value = lerpf(active_touch_slider.min_value, active_touch_slider.max_value, ratio)


func _open_inventory() -> void:
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	if inventory == null:
		return
	close_menu()
	inventory.open_from_pause()


func _load_controls() -> void:
	language_option.select(0 if local_settings.language == "pt_BR" else 1)
	for index in zoom_option.item_count:
		if StringName(zoom_option.get_item_metadata(index)) == local_settings.camera_zoom_preference:
			zoom_option.select(index)
			break
	touch_slider.set_value_no_signal(local_settings.touch_control_scale * 100.0)
	touch_value.text = "%d%%" % int(round(local_settings.touch_control_scale * 100.0))
	debug_toggle.set_pressed_no_signal(local_settings.debug_hud_visible)
	for index in audio_sliders.size():
		var bus: StringName = LocalSettings.AUDIO_BUSES[index]
		var percent: float = local_settings.get_audio_volume(bus) * 100.0
		audio_sliders[index].set_value_no_signal(percent)
		_update_audio_label(bus, percent)


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


func _set_audio_volume(percent: float, bus: StringName) -> void:
	local_settings.set_audio_volume(bus, percent / 100.0)
	_update_audio_label(bus, percent)


func _update_audio_label(bus: StringName, percent: float) -> void:
	var label: Label = settings_content.get_node(String(bus) + "Label") as Label
	label.text = "%s — %d%%" % [tr(AUDIO_LABELS[LocalSettings.AUDIO_BUSES.find(bus)]), int(round(percent))]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		language_option.select(0 if local_settings.language == "pt_BR" else 1)
		$Overlay/Center/MainPage/SessionSummary.text = get_parent().get_node("RunDebugHUD").get_session_summary(true)
		for bus: StringName in LocalSettings.AUDIO_BUSES:
			_update_audio_label(bus, local_settings.get_audio_volume(bus) * 100.0)
		call_deferred("_layout_panels")


func _handle_options_gesture(event: InputEvent) -> bool:
	if not settings_page.is_visible_in_tree():
		return false
	if event is InputEventScreenTouch:
		if event.pressed:
			if options_touch_index >= 0:
				return settings_scroll.get_global_rect().has_point(event.position)
			if not settings_scroll.get_global_rect().has_point(event.position):
				return false
			options_touch_index = event.index
			options_touch_origin = event.position
			options_scroll_origin = settings_scroll.scroll_vertical
			options_gesture = 0
			active_touch_slider = null
			var sliders: Array[HSlider] = [touch_slider]
			sliders.append_array(audio_sliders)
			for slider: HSlider in sliders:
				if slider.is_visible_in_tree() and slider.get_global_rect().has_point(event.position):
					active_touch_slider = slider
					break
			# Do not grab focus or mutate volume before the gesture is classified.
			return true
		if event.index != options_touch_index:
			return false
		if not event.canceled and options_gesture == 0 and settings_scroll.get_global_rect().has_point(event.position) and event.position.distance_to(options_touch_origin) < OPTIONS_DRAG_THRESHOLD:
			if active_touch_slider != null:
				active_touch_slider.grab_focus()
				_update_touch_slider(event.position)
			else:
				# A completed tap keeps the existing native dropdown/toggle callbacks.
				var tap: InputEventScreenTouch = InputEventScreenTouch.new()
				tap.position = event.position
				tap.index = event.index
				tap.pressed = true
				_handle_screen_touch_pressed(tap)
		_cancel_options_gesture()
		return true
	if event is InputEventScreenDrag and event.index == options_touch_index:
		var displacement: Vector2 = event.position - options_touch_origin
		if options_gesture == 0:
			if absf(displacement.y) >= OPTIONS_DRAG_THRESHOLD and absf(displacement.y) >= absf(displacement.x):
				options_gesture = 1
			elif active_touch_slider != null and absf(displacement.x) >= OPTIONS_DRAG_THRESHOLD and absf(displacement.x) > absf(displacement.y):
				options_gesture = 2
				active_touch_slider.grab_focus()
		if options_gesture == 1:
			# ScrollContainer clamps its native range. Same path handles up and down.
			settings_scroll.scroll_vertical = options_scroll_origin - int(round(displacement.y))
		elif options_gesture == 2:
			_update_touch_slider(event.position)
		return true
	return false


func _cancel_options_gesture() -> void:
	options_touch_index = -1
	options_gesture = 0
	active_touch_slider = null
	settings_slider_touch_index = -1


func _style_audio_slider(slider: HSlider) -> void:
	PANEL_PRESENTATION.style_slider(slider, Color("39dff2"))


func _build_categories() -> void:
	var tabs := HBoxContainer.new()
	tabs.name = "Categories"
	tabs.add_theme_constant_override("separation", 8)
	settings_page.add_child(tabs)
	settings_page.move_child(tabs, 1)
	var labels: Array[String] = ["JOGO", "CONTROLES", "ÁUDIO"]
	for index in labels.size():
		var button := Button.new()
		button.text = labels[index]
		button.custom_minimum_size = Vector2(136, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_category.bind(index))
		button.gui_input.connect(_category_touch.bind(button, index))
		button.add_theme_font_size_override("font_size", 18)
		PANEL_PRESENTATION.style_button(button)
		tabs.add_child(button)
		category_buttons.append(button)
	_select_category(0)


func _category_touch(event: InputEvent, button: Button, index: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_select_category(index)
		button.grab_focus()
		button.accept_event()


func _select_category(index: int) -> void:
	_cancel_options_gesture()
	selected_category = index
	var groups: Array = [["ZoomLabel", "CameraZoom", "DebugHud", "LanguageLabel", "LanguageOption"],
		["TouchLabel", "TouchScale", "TouchValue"],
		["MasterLabel", "MasterVolume", "MusicLabel", "MusicVolume", "AmbienceLabel", "AmbienceVolume", "SFXLabel", "SFXVolume", "DialogueLabel", "DialogueVolume"]]
	for child in settings_content.get_children():
		if child is Control:
			child.visible = String(child.name) in groups[index]
	for tab in category_buttons.size():
		var path: String = "settings/settings_tab_selected" if tab == index else "settings/settings_tab_normal"
		PANEL_PRESENTATION.set_button_normal(category_buttons[tab], PANEL_PRESENTATION.style(path, 8, 8))
		for state in ["hover", "pressed"]:
			category_buttons[tab].add_theme_stylebox_override(state, PANEL_PRESENTATION.style("settings/settings_tab_selected", 8, 8))
	settings_scroll.scroll_vertical = 0


func _layout_panels() -> void:
	# Responsive composition, independent of the old right-anchored menu container.
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var center := $Overlay/Center as Control
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	PANEL_PRESENTATION.clear_minimum_widths(main_page)
	PANEL_PRESENTATION.clear_minimum_widths(settings_page)
	main_page.position = Vector2(40, maxf(28, (screen.y - main_page.get_combined_minimum_size().y) * 0.5))
	main_page.size = Vector2(248, main_page.get_combined_minimum_size().y)
	var left: float = 344 if not title_settings else maxf(32, (screen.x - 880) * 0.5)
	settings_page.position = Vector2(left, maxf(28, (screen.y - settings_page.get_combined_minimum_size().y) * 0.5))
	settings_page.size = Vector2(maxf(560, screen.x - left - 40), settings_page.get_combined_minimum_size().y)
