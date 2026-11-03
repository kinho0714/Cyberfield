class_name PrivateSessionClient
extends Node
## WSS protocol prototype; never replaces LAN or starts gameplay implicitly.
signal status_changed
signal input_received(peer_id: int, sequence: int, actions: Dictionary)
signal state_received(revision: int, state: Dictionary)
const DOCUMENT := preload("res://scene/persistence/atomic_document.gd")
const MAX_MESSAGE := 96 * 1024
var status := "offline"
var last_error := ""
var peer_id := 0
var room_id := ""
var campaign_id := ""
var revision := 0
var invitations: Array[String] = []
var lobby: Dictionary = {}
var socket: WebSocketPeer
var endpoint := ""
var _hello: Dictionary = {}
var _hello_sent := false
var _resume_token := ""
var _sequence := 0
var _retry_at := 0
var _reconnect_until := 0
var _tls_options: TLSOptions
var _received: Dictionary = {}
var _last_backup_at := -2000
var backup_root := "user://coop_received_v1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func connect_session(url: String, operation: String, token: String, session_id: String = "", owned_campaign: String = "", tls_options: TLSOptions = null, required_players: int = 4) -> Error:
	if not url.begins_with("wss://") or url.length() > 512 or "@" in url or "?" in url or "#" in url:
		last_error = "secure_endpoint_required"
		return ERR_INVALID_PARAMETER
	if operation not in ["create", "join", "resume"] or token.length() < 32 or token.length() > 256:
		return ERR_INVALID_PARAMETER
	if socket != null and socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return ERR_ALREADY_IN_USE
	endpoint = url
	_tls_options = tls_options
	_hello = {"op": operation, "token": token, "protocol": 1}
	if operation == "create":
		_hello.campaign_id = owned_campaign
		_hello.required_players = required_players
	else:
		_hello.room_id = session_id
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = MAX_MESSAGE * 2
	socket.outbound_buffer_size = MAX_MESSAGE * 2
	socket.max_queued_packets = 16
	socket.heartbeat_interval = 20.0
	_hello_sent = false
	status = "connecting"
	last_error = ""
	var result: Error = socket.connect_to_url(url, tls_options)
	if result != OK:
		status = "offline"
		_hello.clear()
	status_changed.emit()
	return result


func _process(_delta: float) -> void:
	if socket == null:
		return
	flush_backup()
	socket.poll()
	var state: int = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _hello_sent:
			_send(_hello)
			_hello_sent = true
		var packets := 0
		while socket.get_available_packet_count() > 0 and packets < 16:
			packets += 1
			var raw: PackedByteArray = socket.get_packet()
			if raw.size() > MAX_MESSAGE or not socket.was_string_packet():
				_fail("invalid_server_packet")
				return
			var json: JSON = JSON.new()
			if json.parse(raw.get_string_from_utf8()) != OK or json.data is not Dictionary:
				_fail("invalid_server_packet")
				return
			_receive(json.data)
	elif state == WebSocketPeer.STATE_CLOSED and status not in ["offline", "suspended", "error"]:
		if status != "reconnecting":
			status = "reconnecting" if not _resume_token.is_empty() else "offline"
			if _reconnect_until == 0:
				_reconnect_until = Time.get_ticks_msec() + 600000
			_retry_at = Time.get_ticks_msec() + 3000
			_hello.clear()
			status_changed.emit()
		elif Time.get_ticks_msec() >= _reconnect_until:
			status = "suspended"
			status_changed.emit()
		elif Time.get_ticks_msec() >= _retry_at:
			_retry_at = Time.get_ticks_msec() + 3000
			connect_session(endpoint, "resume", _resume_token, room_id, "", _tls_options)


func _receive(message: Dictionary) -> void:
	var operation: String = String(message.get("op", ""))
	if operation == "welcome":
		if not _valid_id(String(message.get("room_id", ""))) or int(message.get("peer", 0)) < 1 or int(message.get("peer", 0)) > 4:
			_fail("invalid_welcome")
			return
		room_id = message.room_id
		campaign_id = String(message.get("campaign_id", ""))
		peer_id = int(message.peer)
		revision = int(message.get("revision", 0))
		_resume_token = String(message.get("resume_token", ""))
		invitations.clear()
		for token: Variant in message.get("invites", []):
			if token is String and token.length() <= 256:
				invitations.append(token)
		_hello.clear()
		_reconnect_until = 0
		status = String(message.get("status", "lobby"))
		status_changed.emit()
		if message.get("snapshot") is Dictionary and not message.snapshot.is_empty():
			state_received.emit(revision, message.snapshot)
	elif operation == "lobby":
		if message.get("room_id", "") != room_id or message.get("connected") is not Array or message.connected.size() > 4:
			_fail("invalid_lobby")
			return
		lobby = message.duplicate(true)
		status = String(message.get("status", "lobby"))
		status_changed.emit()
	elif operation == "started":
		status = "active"
		status_changed.emit()
	elif operation == "input":
		if peer_id == 1 and int(message.get("peer", 0)) in [2, 3, 4] and message.get("actions") is Dictionary:
			input_received.emit(int(message.peer), int(message.get("sequence", 0)), message.actions)
	elif operation == "snapshot":
		if message.get("session_id", "") != room_id or message.get("campaign_id", "") != campaign_id:
			_fail("snapshot_identity_mismatch")
			return
		var incoming: int = int(message.get("revision", -1))
		if incoming <= revision or message.get("state") is not Dictionary:
			return
		revision = incoming
		_received = {"schema_version": 1, "campaign_id": campaign_id,
			"session_id": room_id, "revision": revision, "host_peer": 1,
			"participants": lobby.get("connected", []), "state": message.state}
		flush_backup()
		state_received.emit(revision, message.state)
	elif operation == "suspended":
		status = "suspended"
		status_changed.emit()
	elif operation == "error":
		_fail(String(message.get("code", "server_rejected")))


func start_session() -> Error:
	return _send({"op": "start"})


func send_input(actions: Dictionary) -> Error:
	_sequence += 1
	return _send({"op": "input", "sequence": _sequence, "actions": actions})


func publish_snapshot(state: Dictionary) -> Error:
	if peer_id != 1:
		return ERR_UNAUTHORIZED
	return _send({"op": "snapshot", "base_revision": revision, "state": state})


func publish_event(event_id: String) -> Error:
	if peer_id != 1:
		return ERR_UNAUTHORIZED
	return _send({"op": "event", "event_id": event_id})


func leave() -> void:
	flush_backup(true)
	_send({"op": "leave"})
	if socket != null:
		socket.close(1000, "leave")
	status = "offline"
	_hello.clear()
	_resume_token = ""
	_reconnect_until = 0
	invitations.clear()
	status_changed.emit()


func _send(message: Dictionary) -> Error:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_CONNECTION_ERROR
	var text: String = JSON.stringify(message)
	if text.to_utf8_buffer().size() > MAX_MESSAGE:
		return ERR_INVALID_DATA
	return socket.send_text(text)


func _fail(code: String) -> void:
	flush_backup(true)
	last_error = code
	status = "error"
	_hello.clear()
	if socket != null:
		socket.close(1008, "protocol")
	status_changed.emit()


func _valid_id(id: String) -> bool:
	return id.length() == 32 and id.is_valid_hex_number(false)


func flush_backup(force := false) -> bool:
	if _received.is_empty() or (not force and Time.get_ticks_msec() - _last_backup_at < 2000):
		return true
	var backup: AtomicDocument = DOCUMENT.new()
	backup.directory = backup_root.path_join(String(_received.session_id))
	var previous: Dictionary = backup.read()
	if int(previous.get("revision", -1)) >= int(_received.revision):
		_received = {}
		return true
	if not backup.write(_received):
		last_error = "participant_backup_failed"
		return false
	_last_backup_at = Time.get_ticks_msec()
	_received = {}
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		flush_backup(true)
