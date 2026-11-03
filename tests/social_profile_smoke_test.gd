extends SceneTree
## Social local (03/11): estados de solicitação, bloqueio, migração de perfil antigo,
## sanitização de nomes e código de convite. Namespaces descartáveis; sem rede.
const PROFILE := preload("res://scene/social/local_profile.gd")
const TEXT := preload("res://scene/social/text_safety.gd")
const INVITE := preload("res://scene/network/private_invite_code.gd")
const DOCUMENT := preload("res://scene/persistence/atomic_document.gd")
const BRIDGE := preload("res://scene/social/social_bridge.gd")
const CLIENT := preload("res://scene/network/private_session_client.gd")
var failures := 0


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var base := "user://test_social_" + Crypto.new().generate_random_bytes(10).hex_encode()
	_legacy_migration(base.path_join("legacy"))
	_requests(base.path_join("requests"))
	_names()
	_invite_codes()
	await _bridge_offline(base.path_join("bridge"))
	print("SOCIAL_PROFILE_REPORT failures=", failures)
	quit(0 if failures == 0 else 1)


func _legacy_migration(path: String) -> void:
	# Perfil gravado pelo formato do Codex (sem incoming/avatar/friend_requests, bloqueio = true).
	var legacy := {"schema_version": 1, "player_id": "c".repeat(32), "public_id": "d".repeat(16), "display_name": "Antigo",
		"privacy": {"visibility": "private", "allow_invites": "friends", "share_presence": false},
		"friends": {"e".repeat(16): {"public_id": "e".repeat(16), "display_name": "Velho", "status": "local_unverified"}},
		"requests": {}, "invites": {}, "blocked": {"f".repeat(16): true}}
	var document := DOCUMENT.new()
	document.directory = path
	check(document.write(legacy), "legacy fixture written")
	var revision_before: int = document.revision
	var profile := PROFILE.new()
	check(profile.initialize(path), "legacy profile loads")
	check(profile.data.incoming.is_empty() and profile.data.avatar == "jhon" and profile.data.privacy.friend_requests == "session", "defaults for new keys")
	check(profile.data.friends.has("e".repeat(16)) and profile.is_blocked("f".repeat(16)), "legacy contacts and blocks kept")
	var reread := DOCUMENT.new()
	reread.directory = path
	reread.read()
	check(reread.revision == revision_before, "loading never rewrites the legacy file")
	check(profile.unblock("F".repeat(16)), "legacy boolean block can be removed (case-insensitive)")
	profile.free()


func _requests(path: String) -> void:
	var profile := PROFILE.new()
	check(profile.initialize(path), "new profile")
	var me: String = profile.data.public_id
	check(not profile.receive_request({"public_id": me, "name": "Eu"}), "own ID refused")
	check(profile.receive_request({"public_id": "AB12" + "0".repeat(12), "name": "Ra\u0007fa\n", "avatar": "spark"}), "incoming request stored")
	var rafa := "ab12" + "0".repeat(12)
	check(profile.data.incoming.has(rafa) and profile.data.incoming[rafa].display_name == "Rafa", "ID normalized and name sanitized")
	check(not profile.data.incoming[rafa].has("player_id"), "incoming keeps public data only")
	var accepted: Dictionary = profile.accept_request(rafa)
	check(not accepted.is_empty() and profile.data.friends[rafa].status == "session_mutual_unverified" and profile.data.incoming.is_empty(), "accept moves to friends")
	check(profile.receive_request({"public_id": "1".repeat(16), "name": "Lu"}) and profile.decline_request("1".repeat(16)), "decline")
	check(not profile.data.friends.has("1".repeat(16)) and profile.data.incoming.is_empty(), "declined is not a friend")
	check(profile.request_contact("2".repeat(16), "Dani") and profile.data.requests["2".repeat(16)].state == "local_pending_not_sent", "local draft")
	check(profile.cancel_request("2".repeat(16)) and profile.data.requests.is_empty(), "cancel pending")
	check(profile.receive_request({"public_id": "3".repeat(16), "name": "Spam"}), "request before block")
	check(profile.block("3".repeat(16)) and profile.data.incoming.is_empty(), "block removes pending request")
	check(not profile.receive_request({"public_id": "3".repeat(16), "name": "Spam"}), "blocked sender silently refused")
	check(not profile.receive_request({"public_id": "3".repeat(16).to_upper(), "name": "Spam"}), "block not bypassed by case")
	check(not profile.add_local_contact("3".repeat(16), "Spam"), "blocked contact refused")
	check(profile.block(rafa) and not profile.data.friends.has(rafa), "block removes friend")
	check(profile.unblock(rafa) and profile.add_session_friend({"public_id": rafa, "name": "Rafa", "avatar": "kai"}), "session friend after unblock")
	check(profile.set_privacy("friends", false, "none") and not profile.receive_request({"public_id": "4".repeat(16), "name": "X"}), "privacy none refuses requests")
	check(profile.set_avatar("kai") and not profile.set_avatar("../../evil"), "avatar whitelist")
	check(profile.rename("  \u202eNovo\u200b Nome  ") and profile.data.display_name == "Novo Nome", "rename sanitized")
	check(not profile.rename("\u200b\n"), "invisible-only name refused")
	var view: Dictionary = profile.public_view()
	check(not view.has("player_id") and not view.has("friends") and not view.has("blocked") and not view.has("incoming"), "public view minimal")
	var card: Dictionary = profile.session_card()
	check(card.keys().size() == 3 and not card.has("player_id"), "session card minimal")
	var reopened := PROFILE.new()
	check(reopened.initialize(path) and reopened.data.friends.has(rafa) and reopened.data.avatar == "kai", "persisted")
	check(reopened.data.privacy.friend_requests == "none", "privacy persisted")
	check(reopened.set_privacy("friends", false, "session"), "requests allowed again")
	for i in PROFILE.MAX_INCOMING + 3:
		reopened.receive_request({"public_id": "%016x" % (0x5000 + i), "name": "N"})
	check(reopened.data.incoming.size() == PROFILE.MAX_INCOMING, "incoming list bounded")
	profile.free()
	reopened.free()


func _names() -> void:
	check(TEXT.clean_name("a\u202eb\u2066c\u0001d\u0085e", 24) == "abcde", "bidi/control removed")
	check(TEXT.clean_name("x".repeat(80), 24).length() == 24, "length limit")
	check(TEXT.clean_name("  Kinho  ") == "Kinho", "trim")


func _invite_codes() -> void:
	var token := "Ab-_" + "x".repeat(40)
	var room := "0123456789abcdef0123456789abcdef"
	var code := INVITE.encode("wss://g14.example.net/coop", room, token)
	check(code.begins_with("CF1-"), "code prefix")
	var parsed: Dictionary = INVITE.decode("  " + code + "\n")
	check(parsed.endpoint == "wss://g14.example.net/coop" and parsed.room_id == room and parsed.token == token, "round trip")
	check(INVITE.encode("ws://insecure", room, token).is_empty(), "insecure endpoint refused")
	check(INVITE.encode("wss://user:pw@host", room, token).is_empty(), "credentials in URL refused")
	check(INVITE.encode("wss://host/?token=x", room, token).is_empty(), "query refused")
	check(INVITE.encode("wss://host", "XYZ", token).is_empty(), "bad room refused")
	check(INVITE.encode("wss://host", room, "short").is_empty(), "short token refused")
	check(INVITE.encode("wss://host", room, "x".repeat(40) + "!").is_empty(), "token charset enforced")
	for bad in ["", "CF1-", "CF1-%%%", "CF2-" + code.substr(4), code + "AAAA", "CF1-" + Marshalls.utf8_to_base64("[]"),
			"CF1-" + Marshalls.utf8_to_base64(JSON.stringify({"v": 1, "e": "wss://h", "r": room, "t": token, "extra": 1})),
			"CF1-" + Marshalls.utf8_to_base64(JSON.stringify({"v": 1, "e": "wss://h", "r": room, "t": 5})),
			"CF1-" + "A".repeat(2000)]:
		check(INVITE.decode(bad).is_empty(), "malformed code refused: " + bad.left(24))


func _bridge_offline(path: String) -> void:
	var profile := PROFILE.new()
	root.add_child(profile)
	profile.initialize(path)
	var client := CLIENT.new()
	root.add_child(client)
	var bridge := BRIDGE.new()
	root.add_child(bridge)
	bridge.setup(profile, client)
	check(not bridge.online_accounts_available(), "no fake online accounts")
	check(bridge.send_request(2) == ERR_UNAVAILABLE and bridge.sent.is_empty(), "offline request is not reported as sent")
	client.friend_response_received.emit(3, true, {"public_id": "9".repeat(16), "name": "Intruso", "avatar": "kai"})
	check(profile.data.friends.is_empty(), "unsolicited acceptance never adds a friend")
	client.friend_request_received.emit(2, {"public_id": "8".repeat(16), "name": "Par", "avatar": "kai"})
	check(profile.data.incoming.has("8".repeat(16)), "request delivered by the session is stored")
	check(bridge.accept("8".repeat(16)).begins_with("Aceito neste aparelho"), "accept offline is reported as local only")
	await process_frame
	bridge.queue_free()
	client.queue_free()
	profile.queue_free()
	await process_frame
