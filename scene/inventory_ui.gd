extends CanvasLayer

var overlay: ColorRect
var slot_buttons: Array[Button] = []
var _blocked_players: Array[Node] = []
var _tree_paused := false
var _return_to_pause := false


func _ready() -> void:
	add_to_group("inventory_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.005, 0.015, 0.035, 0.96)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(560, 320)
	center.add_child(panel)
	var title := Label.new()
	title.text = "INVENTÁRIO // 2 SLOTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	panel.add_child(title)
	for index in 2:
		var button := Button.new()
		button.custom_minimum_size = Vector2(540, 92)
		button.pressed.connect(_select_slot.bind(index))
		panel.add_child(button)
		slot_buttons.append(button)
	var close := Button.new()
	close.text = "FECHAR"
	close.pressed.connect(close_inventory)
	panel.add_child(close)
	overlay.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_inventory") and not event.is_echo():
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif overlay.visible and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		close_inventory()
		get_viewport().set_input_as_handled()


func toggle_inventory() -> void:
	if overlay.visible:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	var attribute_ui := get_tree().get_first_node_in_group("attribute_choice_ui")
	if attribute_ui != null and attribute_ui.visible:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or not room_manager.mode_selected or room_manager.is_transitioning:
		return
	var full_map := get_tree().get_first_node_in_group("full_map")
	if full_map != null and full_map.visible:
		full_map.close_map()
	var pause := get_tree().get_first_node_in_group("pause_menu")
	if pause != null and pause.overlay.visible:
		pause.close_menu()
	_block_local_players(room_manager)
	var lan_session: LanSession = room_manager.get_node("LanSession")
	if not lan_session.is_network_game():
		get_tree().paused = true
		_tree_paused = true
	room_manager.get_node("TouchControls").set_menu_blocked(true)
	overlay.visible = true
	_refresh()
	slot_buttons[0].grab_focus()


func open_from_pause() -> void:
	_return_to_pause = true
	open_inventory()


func close_inventory() -> void:
	if _tree_paused:
		get_tree().paused = false
		_tree_paused = false
	overlay.visible = false
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		room_manager.get_node("TouchControls").set_menu_blocked(false)
	for player in _blocked_players:
		if is_instance_valid(player):
			player.set_input_enabled(true)
	_blocked_players.clear()
	if _return_to_pause:
		_return_to_pause = false
		var pause := get_tree().get_first_node_in_group("pause_menu")
		if pause != null:
			pause.open_menu()


func _select_slot(index: int) -> void:
	var player := _local_player()
	if player != null and not player.equipped_weapons[index].is_empty():
		player.active_weapon_slot = index
		_refresh()


func _refresh() -> void:
	var player := _local_player()
	if player == null:
		return
	for index in 2:
		var weapon_id: StringName = player.equipped_weapons[index]
		if weapon_id.is_empty():
			slot_buttons[index].text = "SLOT %d // VAZIO" % (index + 1)
			slot_buttons[index].disabled = true
			continue
		var data := WeaponCatalog.get_definition(weapon_id)
		slot_buttons[index].disabled = false
		slot_buttons[index].text = "%s SLOT %d // %s\nTIPO %s  DANO %d  RECARGA %.2fs  RARIDADE %s" % [">" if player.active_weapon_slot == index else " ", index + 1, data.name, String(data.type).to_upper(), data.damage, data.cooldown, String(data.rarity).to_upper()]


func _local_player() -> Node:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null:
		return null
	var lan: LanSession = room_manager.get_node("LanSession")
	for player in room_manager.get_players():
		if not lan.is_network_game() or lan.is_host() and player.participant_id == &"player_1" or lan.is_client() and player.participant_id == &"player_2":
			return player
	return null


func _block_local_players(room_manager: Node) -> void:
	_blocked_players.clear()
	var local := _local_player()
	if local != null and local.input_enabled:
		local.set_input_enabled(false)
		_blocked_players.append(local)
