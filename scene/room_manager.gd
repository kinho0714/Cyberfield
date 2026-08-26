extends Node2D

signal coop_waiting_changed(visible: bool)

const ROOM_BOUNDS := Rect2(0.0, 0.0, 1280.0, 720.0)
const BOUNDARY_THICKNESS := 48.0
const PLAYER_SCENE := preload("res://entities/player.tscn")
const COOP_SPAWN_OFFSET := 22.0
const EXIT_GROUP_DISTANCE := 96.0

@export_file("*.tscn") var initial_room_path := "res://scene/levels/cyberfield_area_01.tscn"
@export var initial_entry_id := &"start"
@export_range(0.05, 2.0, 0.05) var fade_duration := 0.25

@onready var room_container: Node2D = $RoomContainer
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var run_manager: Node = $RunManager
@onready var mode_select: CanvasLayer = $ModeSelect

var current_room: Node = null
var is_transitioning := false
var mode_selected := false


func _ready() -> void:
	add_to_group("room_manager")
	run_manager.add_to_group("run_manager")
	fade_rect.modulate.a = 0.0
	$RunDebugHUD.visible = false
	mode_select.run_requested.connect(start_configured_run)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func start_game_mode(mode: StringName) -> void:
	start_configured_run(mode, &"normal", _first_connected_joypad() if mode == &"coop" else -1)


func start_configured_run(mode: StringName, difficulty: StringName, joypad_device_id: int) -> void:
	if mode_selected or is_transitioning:
		return
	if mode == &"coop" and not Input.get_connected_joypads().has(joypad_device_id):
		mode_select.focus_default()
		return

	is_transitioning = true
	await _fade_to(1.0)
	run_manager.configure_run(mode, difficulty, joypad_device_id)
	_create_players(mode == &"coop", joypad_device_id)
	run_manager.start_new_run()
	for candidate in get_players():
		run_manager.register_participant(candidate.participant_id, true)
	if not _load_room(initial_room_path, initial_entry_id):
		await _clear_run_and_show_menu()
		return
	mode_selected = true
	mode_select.visible = false
	$RunDebugHUD.visible = true
	await _fade_to(0.0)
	_set_all_player_input(true)
	is_transitioning = false


func return_to_mode_selection() -> void:
	return_to_main_menu()


func return_to_main_menu() -> void:
	if is_transitioning:
		return
	await _clear_run_and_show_menu()


func _clear_run_and_show_menu() -> void:
	is_transitioning = true
	_set_all_player_input(false)
	await _fade_to(1.0)
	if is_instance_valid(current_room):
		current_room.queue_free()
		current_room = null
	for candidate in get_players():
		candidate.queue_free()
	await get_tree().process_frame
	run_manager.clear_run()
	mode_selected = false
	coop_waiting_changed.emit(false)
	$RunDebugHUD.visible = false
	mode_select.visible = true
	mode_select.focus_default()
	await _fade_to(0.0)
	is_transitioning = false


func request_room_change(room_path: String, entry_id: StringName) -> void:
	if is_transitioning or room_path.is_empty():
		return
	is_transitioning = true
	_set_all_player_input(false)
	await _fade_to(1.0)
	if not _load_room(room_path, entry_id):
		await _fade_to(0.0)
		_set_all_player_input(true)
		is_transitioning = false
		return
	await get_tree().process_frame
	await _fade_to(0.0)
	_set_all_player_input(run_manager.run_active)
	is_transitioning = false


func restart_current_run() -> void:
	if is_transitioning or not mode_selected:
		return
	is_transitioning = true
	_set_all_player_input(false)
	await _fade_to(1.0)
	run_manager.start_new_run()
	for candidate in get_players():
		candidate.reset_for_new_run()
		run_manager.register_participant(candidate.participant_id, true)
	_load_room(initial_room_path, initial_entry_id)
	await get_tree().process_frame
	await _fade_to(0.0)
	_set_all_player_input(true)
	is_transitioning = false


func _load_room(room_path: String, entry_id: StringName) -> bool:
	var packed_room := load(room_path) as PackedScene
	if packed_room == null:
		push_error("Could not load room: %s" % room_path)
		return false
	var new_room := packed_room.instantiate()
	var room_id: StringName = run_manager.enter_room_by_path(room_path)
	run_manager.prepare_room(room_id, new_room)
	_add_room_safety(new_room)
	room_container.add_child(new_room)
	var entry_point := _find_entry_point(new_room, entry_id)
	if entry_point == null:
		push_error("Entry '%s' was not found in room: %s" % [entry_id, room_path])
		new_room.queue_free()
		return false
	if is_instance_valid(current_room):
		current_room.queue_free()
	current_room = new_room
	_position_players(entry_point.global_position)
	return true


func get_players() -> Array[Node]:
	var result: Array[Node] = []
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate.get_parent() == self:
			result.append(candidate)
	result.sort_custom(func(a: Node, b: Node) -> bool: return String(a.participant_id) < String(b.participant_id))
	return result


func can_use_exit(exit: Area2D, interactor: Node2D) -> bool:
	if interactor == null or interactor.is_downed:
		return false
	if not run_manager.is_coop():
		return true
	for candidate in get_players():
		if candidate.is_downed or candidate.global_position.distance_to(exit.global_position) > EXIT_GROUP_DISTANCE:
			coop_waiting_changed.emit(true)
			return false
	coop_waiting_changed.emit(false)
	return true


func _create_players(coop: bool, joypad_device_id: int) -> void:
	for candidate in get_players():
		candidate.queue_free()
	var player_one := PLAYER_SCENE.instantiate()
	player_one.name = "Player"
	player_one.participant_id = &"player_1"
	player_one.input_profile = "p1"
	add_child(player_one)
	if coop:
		var player_two := PLAYER_SCENE.instantiate()
		player_two.name = "Player2"
		player_two.participant_id = &"player_2"
		player_two.input_profile = "p2"
		player_two.joypad_device_id = joypad_device_id
		add_child(player_two)
		player_two.anim.modulate = Color(0.45, 0.8, 1.0, 1.0)
		player_one.add_collision_exception_with(player_two)
		player_two.add_collision_exception_with(player_one)


func _position_players(entry_position: Vector2) -> void:
	var active_players := get_players()
	for index in active_players.size():
		var offset := 0.0
		if active_players.size() == 2:
			offset = -COOP_SPAWN_OFFSET if index == 0 else COOP_SPAWN_OFFSET
		active_players[index].global_position = Vector2(clampf(entry_position.x + offset, 16.0, 1264.0), entry_position.y)
		active_players[index].velocity = Vector2.ZERO
		active_players[index].visible = true


func _set_all_player_input(enabled: bool) -> void:
	if not enabled:
		var choice_ui := get_tree().get_first_node_in_group("attribute_choice_ui")
		if choice_ui:
			choice_ui.cancel_selection()
	for candidate in get_players():
		candidate.set_input_enabled(enabled)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	if not mode_selected or not run_manager.is_coop():
		return
	var connected := Input.get_connected_joypads()
	if connected.has(run_manager.p2_joypad_device_id) or connected.is_empty():
		run_manager.state_changed.emit()
		return
	var new_device: int = connected[0]
	run_manager.p2_joypad_device_id = new_device
	run_manager.p2_joypad_name = Input.get_joy_name(new_device)
	for candidate in get_players():
		if candidate.input_profile == "p2":
			candidate.joypad_device_id = new_device
			LocalCoopInput.ensure_player_two_actions(new_device)
	run_manager.state_changed.emit()


func _first_connected_joypad() -> int:
	var connected := Input.get_connected_joypads()
	return connected[0] if not connected.is_empty() else -1


func _add_room_safety(room: Node2D) -> void:
	var boundaries := StaticBody2D.new()
	boundaries.name = "RoomBoundaries"
	room.add_child(boundaries)
	_add_boundary_shape(boundaries, Vector2(-BOUNDARY_THICKNESS * 0.5, ROOM_BOUNDS.size.y * 0.5), Vector2(BOUNDARY_THICKNESS, ROOM_BOUNDS.size.y + BOUNDARY_THICKNESS * 2.0))
	_add_boundary_shape(boundaries, Vector2(ROOM_BOUNDS.size.x + BOUNDARY_THICKNESS * 0.5, ROOM_BOUNDS.size.y * 0.5), Vector2(BOUNDARY_THICKNESS, ROOM_BOUNDS.size.y + BOUNDARY_THICKNESS * 2.0))
	var kill_zone := Area2D.new()
	kill_zone.name = "FallKillZone"
	kill_zone.collision_layer = 0
	kill_zone.collision_mask = 1
	var kill_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(ROOM_BOUNDS.size.x + BOUNDARY_THICKNESS * 2.0, 80.0)
	kill_shape.shape = rectangle
	kill_shape.position = Vector2(ROOM_BOUNDS.size.x * 0.5, ROOM_BOUNDS.end.y + 100.0)
	kill_zone.add_child(kill_shape)
	kill_zone.body_entered.connect(_on_fall_kill_zone_body_entered)
	room.add_child(kill_zone)
	for title_name in [&"Title", &"RoomLabel"]:
		var world_title := room.get_node_or_null(NodePath(String(title_name))) as CanvasItem
		if world_title:
			world_title.visible = false


func _add_boundary_shape(body: StaticBody2D, position: Vector2, size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	collision.position = position
	body.add_child(collision)


func _on_fall_kill_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("enter_downed"):
		body.enter_downed()


func _find_entry_point(room: Node, entry_id: StringName) -> Marker2D:
	for node in get_tree().get_nodes_in_group("room_entry"):
		if room.is_ancestor_of(node) and node.name == entry_id:
			return node as Marker2D
	return null


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_rect, "modulate:a", alpha, fade_duration)
	await tween.finished
