extends SceneTree
## Um participante Godot REAL da sessão privada (03/11). O harness Python
## (tests/private_relay_social_test.py) inicia quatro processos deste script contra o
## relay TLS de loopback: anfitrião + três convidados que entram por código de convite.
## Usa os módulos de produção: PrivateSessionClient, SocialBridge, LocalPlayerProfile e
## PrivateInviteCode. Certificado descartável confiado só aqui (TLSOptions.client).
## Não é gameplay sincronizado: valida sala, convites, social, inputs e snapshot.
const CLIENT := preload("res://scene/network/private_session_client.gd")
const PROFILE := preload("res://scene/social/local_profile.gd")
const BRIDGE := preload("res://scene/social/social_bridge.gd")
const INVITE := preload("res://scene/network/private_invite_code.gd")
const DOCUMENT := preload("res://scene/persistence/atomic_document.gd")
var failures := 0
var fixture: Dictionary = {}
var seat := 0
var client: Node
var profile: Node
var bridge: Node
var inputs: Dictionary = {}
var states := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("seat %d: %s" % [seat, message])


func _until(condition: Callable, seconds := 30.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return condition.call()


func _marker(name: String) -> String:
	return String(fixture.dir).path_join(name)


func _write(name: String, data: Dictionary) -> void:
	var file := FileAccess.open(_marker(name + ".tmp"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(_marker(name + ".tmp"), _marker(name))


func _read(name: String) -> Dictionary:
	if not FileAccess.file_exists(_marker(name)):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_marker(name)))
	return parsed if parsed is Dictionary else {}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	fixture = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	seat = int(args[1])
	var certificate := X509Certificate.new()
	check(certificate.load(String(fixture.cert)) == OK, "load disposable certificate")
	var tls := TLSOptions.client(certificate)
	profile = PROFILE.new()
	root.add_child(profile)
	check(profile.initialize(String(fixture.dir).path_join("profile_%d" % seat)), "profile in disposable namespace")
	profile.rename(["", "Anfitriã" + char(0x202E), "Dani", "Rafa", "Lu"][seat])
	profile.set_avatar(["jhon", "jhon", "kai", "spark", "jackson"][seat])
	client = CLIENT.new()
	client.backup_root = String(fixture.dir).path_join("received_%d" % seat)
	root.add_child(client)
	bridge = BRIDGE.new()
	root.add_child(bridge)
	bridge.setup(profile, client)
	client.input_received.connect(func(peer: int, sequence: int, actions: Dictionary) -> void: inputs[peer] = [sequence, actions])
	client.state_received.connect(func(_revision: int, _state: Dictionary) -> void: states += 1)
	if seat == 1:
		await _host(tls)
	else:
		await _guest(tls)
	var result := {"seat": seat, "public_id": profile.data.public_id, "friends": profile.data.friends.keys(),
		"incoming": profile.data.incoming.keys(), "failures": failures}
	_write("result_%d.json" % seat, result)
	client.leave()
	await process_frame
	print("PRIVATE_PEER_REPORT seat=", seat, " failures=", failures)
	quit(0 if failures == 0 else 1)


func _host(tls: TLSOptions) -> void:
	var campaign_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
	check(client.connect_session(String(fixture.url), "create", String(fixture.token), "", campaign_id, tls, profile.session_card()) == OK, "host connects")
	check(await _until(func() -> bool: return client.peer_id == 1 and client.invitations.size() == 3), "host welcomed with three invitations")
	var codes: Array[String] = []
	for token in client.invitations:
		codes.append(INVITE.encode(String(fixture.url), client.room_id, token))
	check(not codes.has(""), "invite codes encoded")
	_write("invites.json", {"codes": codes})
	check(await _until(func() -> bool: return client.lobby.get("connected", []).size() == 4, 60.0), "four authorized seats connected")
	var host_entry: Dictionary = client.roster_entry(1)
	check(String(host_entry.get("name", "")) == "Anfitriã", "own name sanitized by client and relay")
	check(client.roster.size() == 4, "roster lists four seats")
	for entry: Dictionary in client.roster:
		check(not entry.has("public_id"), "roster never exposes public IDs")
	check(await _until(func() -> bool: return not _read("social_done_2.json").is_empty() and not _read("social_done_3.json").is_empty() and not _read("social_done_4.json").is_empty(), 60.0), "guests finished social checks")
	check(client.start_session() == OK, "host requests start")
	check(await _until(func() -> bool: return client.status == "active"), "protocol active with four Godot clients")
	_write("started.json", {"ok": true})
	check(await _until(func() -> bool: return inputs.size() == 3), "inputs from the three guests reached the host")
	for peer in [2, 3, 4]:
		check(inputs.has(peer) and int(inputs[peer][0]) == 1 and bool(inputs[peer][1].get("right", false)), "guest %d input labeled by relay" % peer)
	var state := {"world_state": {"fixture": "four_godot"}, "player_states": {}, "story_state": {}, "inventory_state": {}}
	check(client.publish_snapshot(state) == OK, "host publishes snapshot")
	check(await _until(func() -> bool: return int(client.revision) >= 1), "host sees revision 1")
	check(await _until(func() -> bool: return not _read("received_2.json").is_empty() and not _read("received_3.json").is_empty() and not _read("received_4.json").is_empty(), 60.0), "guests confirmed snapshot")


func _guest(tls: TLSOptions) -> void:
	check(await _until(func() -> bool: return not _read("invites.json").is_empty(), 60.0), "host published invite codes")
	# O relay atribui assentos por ordem de chegada: entradas em sequência deixam o
	# processo N no assento N, e o teste confere essa atribuição feita pelo servidor.
	if seat > 2:
		check(await _until(func() -> bool: return not _read("joined_%d.json" % (seat - 1)).is_empty(), 60.0), "previous guest joined")
	var code := String(_read("invites.json").codes[seat - 2])
	var parsed: Dictionary = INVITE.decode(code)
	check(not parsed.is_empty() and String(parsed.endpoint) == String(fixture.url), "invite code decodes to the real endpoint")
	check(client.connect_session(String(parsed.endpoint), "join", String(parsed.token), String(parsed.room_id), "", tls, profile.session_card()) == OK, "guest connects with code")
	check(await _until(func() -> bool: return client.peer_id == seat, 30.0), "guest receives its seat")
	_write("joined_%d.json" % seat, {"peer": client.peer_id})
	check(await _until(func() -> bool: return client.lobby.get("connected", []).size() == 4, 60.0), "guest sees four connected")
	var reused: Dictionary = INVITE.decode(code)
	check(not reused.is_empty(), "same code still decodes (server enforces single use)")
	match seat:
		2:
			check(bridge.send_request(3) == OK, "seat 2 asks seat 3")
			check(await _until(func() -> bool: return profile.data.friends.size() == 1), "seat 3 accepted: seat 2 gained a friend")
			check(await _until(func() -> bool: return profile.data.incoming.size() == 1), "seat 4 request arrived at seat 2")
			if profile.data.incoming.size() == 1:
				var from_four := String(profile.data.incoming.keys()[0])
				check(bridge.decline(from_four) == "Solicitação recusada.", "seat 2 declines seat 4")
				check(profile.data.incoming.is_empty(), "declined request removed")
		3:
			check(await _until(func() -> bool: return profile.data.incoming.size() == 1), "seat 3 received seat 2 request")
			if profile.data.incoming.size() == 1:
				var from_two := String(profile.data.incoming.keys()[0])
				check(bridge.accept(from_two).begins_with("Aceito. O outro jogador foi avisado"), "seat 3 accepts through the session")
				check(profile.data.friends.has(from_two), "seat 3 stored mutual friend")
		4:
			check(bridge.send_request(2) == OK, "seat 4 asks seat 2")
			check(await _until(func() -> bool: return not bridge.sent.has(2)), "seat 4 got an answer")
			check(profile.data.friends.is_empty(), "refusal never adds a friend")
	_write("social_done_%d.json" % seat, {"ok": failures == 0})
	check(await _until(func() -> bool: return client.status == "active", 60.0), "guest sees protocol active")
	check(client.send_input({"right": true}) == OK, "guest sends input")
	check(await _until(func() -> bool: return states >= 1), "guest received host snapshot")
	var backup := DOCUMENT.new()
	backup.directory = client.backup_root.path_join(client.room_id)
	client.flush_backup(true)
	var saved: Dictionary = backup.read()
	check(int(saved.get("revision", 0)) == 1 and String(saved.get("session_id", "")) == client.room_id, "guest persisted only the received snapshot")
	_write("received_%d.json" % seat, {"ok": true})
