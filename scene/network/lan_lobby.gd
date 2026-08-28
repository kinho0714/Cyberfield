extends CanvasLayer

signal close_requested

@onready var lan_session: LanSession = get_parent().get_node("LanSession")
@onready var main_page: VBoxContainer = $Overlay/Center/MainPage
@onready var host_page: VBoxContainer = $Overlay/Center/HostPage
@onready var search_page: VBoxContainer = $Overlay/Center/SearchPage
@onready var ip_page: VBoxContainer = $Overlay/Center/IpPage
@onready var room_list: ItemList = $Overlay/Center/SearchPage/Rooms
@onready var host_status: Label = $Overlay/Center/HostPage/Status
@onready var search_status: Label = $Overlay/Center/SearchPage/Status
@onready var ip_status: Label = $Overlay/Center/IpPage/Status
@onready var ip_input: LineEdit = $Overlay/Center/IpPage/IpInput
@onready var difficulty: OptionButton = $Overlay/Center/HostPage/Difficulty
@onready var join_button: Button = $Overlay/Center/SearchPage/Join
var selected_room_key := ""


func _ready() -> void:
	visible = false
	$Overlay/Center/MainPage/Create.pressed.connect(_create_room)
	$Overlay/Center/MainPage/Search.pressed.connect(_search_rooms)
	$Overlay/Center/MainPage/DirectIp.pressed.connect(func() -> void: _show_page(ip_page, ip_input))
	$Overlay/Center/MainPage/Back.pressed.connect(_close)
	$Overlay/Center/HostPage/Start.pressed.connect(_start_run)
	$Overlay/Center/HostPage/Back.pressed.connect(_return_to_main)
	$Overlay/Center/SearchPage/Refresh.pressed.connect(_search_rooms)
	$Overlay/Center/SearchPage/Join.pressed.connect(_join_selected_room)
	$Overlay/Center/SearchPage/DirectIp.pressed.connect(func() -> void: _show_page(ip_page, ip_input))
	$Overlay/Center/SearchPage/Back.pressed.connect(_return_to_main)
	$Overlay/Center/IpPage/Join.pressed.connect(_join_ip)
	$Overlay/Center/IpPage/Back.pressed.connect(_return_to_main)
	room_list.item_selected.connect(_select_room)
	room_list.item_activated.connect(func(_index: int) -> void: _join_selected_room())
	join_button.disabled = true
	lan_session.lobby_changed.connect(_refresh)
	lan_session.discovered_rooms_changed.connect(_refresh_rooms)
	lan_session.connection_message_changed.connect(func(_message: String) -> void: _refresh())
	for entry: Array in [["NORMAL", &"normal"], ["DIFÍCIL", &"hard"], ["PRO", &"pro"], ["INFERNO DO PRO", &"inferno_pro"]]:
		difficulty.add_item(String(entry[0]))
		difficulty.set_item_metadata(difficulty.item_count - 1, entry[1])


func open() -> void:
	visible = true
	_return_to_main()


func close_for_run() -> void:
	visible = false


func show_connection_error(message: String) -> void:
	visible = true
	_show_page(main_page, $Overlay/Center/MainPage/Create)
	$Overlay/Center/MainPage/Info.text = message


func _create_room() -> void:
	if lan_session.host_room("Cyberfield LAN") == OK:
		_show_page(host_page, $Overlay/Center/HostPage/Start)
	_refresh()


func _search_rooms() -> void:
	lan_session.search_rooms()
	_show_page(search_page, room_list)
	_refresh_rooms()


func _join_selected_room() -> void:
	if selected_room_key.is_empty():
		search_status.text = "Selecione uma sala ou use ENTRAR POR IP."
		return
	var room := _find_room_by_key(selected_room_key)
	if room.is_empty():
		selected_room_key = ""
		join_button.disabled = true
		return
	if lan_session.join_room(String(room.address), int(room.port)) == OK:
		_show_page(host_page, $Overlay/Center/HostPage/Back)
	_refresh()


func _select_room(index: int) -> void:
	if index < 0 or index >= room_list.item_count:
		join_button.disabled = true
		return
	var room_key := String(room_list.get_item_metadata(index))
	var room := _find_room_by_key(room_key)
	if room.is_empty():
		join_button.disabled = true
		return
	selected_room_key = room_key
	join_button.disabled = false
	search_status.text = "Selecionada: %s // %s:%d // %d/2" % [String(room.get("name", "Sala")), String(room.get("address", "")), int(room.get("port", 0)), int(room.get("players", 0))]


func _join_ip() -> void:
	if lan_session.join_room(ip_input.text) == OK:
		_show_page(host_page, $Overlay/Center/HostPage/Back)
	_refresh()


func _start_run() -> void:
	var selected_difficulty := StringName(difficulty.get_item_metadata(difficulty.selected))
	lan_session.start_host_run(selected_difficulty)


func _return_to_main() -> void:
	lan_session.shutdown()
	_show_page(main_page, $Overlay/Center/MainPage/Create)
	_refresh()


func _close() -> void:
	lan_session.shutdown()
	visible = false
	close_requested.emit()


func _show_page(page: VBoxContainer, focus: Control) -> void:
	for candidate in [main_page, host_page, search_page, ip_page]:
		candidate.visible = candidate == page
	focus.grab_focus()


func _refresh() -> void:
	var role_text := lan_session.get_role_label()
	var player_count := lan_session.get_player_count()
	var host_only_note := "\nDEBUG: o host pode iniciar 1/2." if lan_session.role == LanSession.Role.HOST and player_count == 1 else ""
	host_status.text = "%s // PEER %d\nJOGADORES: %d/2\n%s%s\n%s" % [role_text, multiplayer.get_unique_id(), player_count, lan_session.connection_message, host_only_note, lan_session.get_discovery_diagnostics()]
	$Overlay/Center/HostPage/Start.visible = lan_session.role == LanSession.Role.HOST
	difficulty.disabled = lan_session.role != LanSession.Role.HOST
	search_status.text = lan_session.connection_message
	ip_status.text = lan_session.connection_message


func _refresh_rooms() -> void:
	room_list.clear()
	var selected_visual_index := -1
	for room in lan_session.discovered_rooms:
		var room_key := _room_key(room)
		room_list.add_item("%s — %s:%d — %d/2" % [room.name, room.address, int(room.port), int(room.players)])
		room_list.set_item_metadata(room_list.item_count - 1, room_key)
		if room_key == selected_room_key:
			selected_visual_index = room_list.item_count - 1
	if selected_visual_index >= 0:
		room_list.select(selected_visual_index)
		_select_room(selected_visual_index)
	else:
		if not selected_room_key.is_empty():
			selected_room_key = ""
		join_button.disabled = true
	if room_list.item_count == 0:
		search_status.text = "Nenhuma sala encontrada. Tente atualizar ou entrar por IP."


func _room_key(room: Dictionary) -> String:
	return "%s:%d" % [String(room.get("address", "")), int(room.get("port", LanSession.GAME_PORT))]


func _find_room_by_key(key: String) -> Dictionary:
	for room in lan_session.discovered_rooms:
		if _room_key(room) == key:
			return room
	return {}
