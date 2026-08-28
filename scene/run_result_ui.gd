class_name RunResultUI
extends CanvasLayer

var overlay: ColorRect
var cards: HBoxContainer
var _buttons: Dictionary = {}
var _panels: Dictionary = {}
var _blocked_players: Dictionary = {}
var _shown_result_hash := 0
var _last_meta_reward := 0


func _ready() -> void:
	add_to_group("run_result_ui")
	layer = 89
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.005, 0.015, 0.035, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	center.add_child(cards)
	overlay.visible = false


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		for participant_value: Variant in _buttons:
			var participant_id := StringName(participant_value)
			var button := _buttons[participant_id] as Button
			if button.is_visible_in_tree() and button.get_global_rect().has_point(event.position):
				close_result(participant_id)
				get_viewport().set_input_as_handled()
				return


func _process(_delta: float) -> void:
	if not overlay.visible:
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null:
		return
	for participant_value: Variant in _blocked_players.keys():
		var participant_id := StringName(participant_value)
		var player: Node = room_manager._find_player(participant_id)
		if player != null and Input.is_action_just_pressed(player._action(&"interact")):
			close_result(participant_id)


func show_latest_results() -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or not room_manager.current_is_hub:
		return
	var result: Dictionary = room_manager.run_manager.last_run_results
	if result.is_empty():
		return
	var meta := get_tree().get_first_node_in_group("meta_progression") as MetaProgression
	_last_meta_reward = meta.record_run(result) if meta != null else 0
	var result_hash := hash(JSON.stringify(result))
	if result_hash == _shown_result_hash:
		return
	_shown_result_hash = result_hash
	_clear_cards()
	var lan: LanSession = room_manager.get_node("LanSession")
	for player in room_manager.get_players():
		if lan.is_network_game() and player.participant_id != lan.get_local_participant_id():
			continue
		_add_result_card(player, result)
	if _blocked_players.is_empty():
		return
	overlay.visible = true
	room_manager.get_node("TouchControls").set_menu_blocked(true)


func close_result(participant_id: StringName) -> void:
	if not _blocked_players.has(participant_id):
		return
	var player := _blocked_players[participant_id] as Node
	if is_instance_valid(player):
		player.set_input_enabled(true)
	_blocked_players.erase(participant_id)
	var panel := _panels.get(participant_id) as PanelContainer
	if panel != null:
		panel.visible = false
	if _blocked_players.is_empty():
		overlay.visible = false
		var room_manager := get_tree().get_first_node_in_group("room_manager")
		if room_manager != null:
			room_manager.get_node("TouchControls").set_menu_blocked(false)


func _add_result_card(player: Node, result: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 470)
	cards.add_child(panel)
	var margin := MarginContainer.new()
	var margin_names: Array[StringName] = [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]
	for side: StringName in margin_names:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "%s   •   %s" % [String(player.participant_id).replace("player_", "P"), "RUN CONCLUÍDA" if bool(result.get("completed", false)) else "RUN PERDIDA"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.modulate = Color(0.3, 1.0, 0.72) if bool(result.get("completed", false)) else Color(1.0, 0.42, 0.5)
	column.add_child(title)
	var details := Label.new()
	details.text = _format_result(player.participant_id, result)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(details)
	var close_button := Button.new()
	close_button.text = "FECHAR / CONTINUAR  [USAR]"
	close_button.custom_minimum_size = Vector2(310, 54)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP if player.input_profile == "p1" else Control.MOUSE_FILTER_IGNORE
	close_button.pressed.connect(close_result.bind(player.participant_id))
	column.add_child(close_button)
	_buttons[player.participant_id] = close_button
	_panels[player.participant_id] = panel
	if player.input_enabled:
		player.set_input_enabled(false)
	_blocked_players[player.participant_id] = player


func _format_result(participant_id: StringName, result: Dictionary) -> String:
	var participants: Dictionary = result.get("participants", {}) as Dictionary
	var stats: Dictionary = participants.get(participant_id, participants.get(String(participant_id), {})) as Dictionary
	var weapons_found: Dictionary = result.get("weapons_found", {}) as Dictionary
	var weapons: Array = weapons_found.get(participant_id, weapons_found.get(String(participant_id), [])) as Array
	var weapon_names: PackedStringArray = []
	for weapon_value: Variant in weapons:
		weapon_names.append(WeaponCatalog.get_display_name(StringName(weapon_value)))
	var trap_events: Dictionary = result.get("trap_events", {}) as Dictionary
	return "RESUMO\n  TEMPO  %s      DIFICULDADE  %s\n  STAGE  %d/6      SUCATA DA RUN  $%d\n  CRÉDITOS PERMANENTES  +◈%d\n\nATRIBUTOS DA RUN\n  INT %d      SAÚDE %d      FORÇA %d\n\nARMAS ENCONTRADAS\n  %s\n\nEVENTOS\n  BOSS  %s\n  TRAPS  %d ATIVADAS  •  %d CONCLUÍDAS  •  %d RECOMPENSADAS" % [
		_format_time(float(result.get("elapsed_time", 0.0))), String(result.get("difficulty", "normal")).to_upper(), clampi(int(result.get("stage_index", 0)) + 1, 1, 6), int(result.get("money_earned", 0)),
		_last_meta_reward, int(stats.get("intellect", 0)), int(stats.get("health", 0)), int(stats.get("strength", 0)), "\n  ".join(weapon_names) if not weapon_names.is_empty() else "NENHUMA",
		"DERROTADO" if bool(result.get("boss_defeated", false)) else "NÃO DERROTADO", int(trap_events.get("activated", 0)), int(trap_events.get("cleared", 0)), int(trap_events.get("rewarded", 0)),
	]


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), floori(seconds) % 60]


func _clear_cards() -> void:
	for child in cards.get_children():
		child.queue_free()
	_buttons.clear()
	_panels.clear()
	_blocked_players.clear()
