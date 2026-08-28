extends SceneTree

const LAN_SESSION_SCRIPT := preload("res://scene/network/lan_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := LAN_SESSION_SCRIPT.new() as LanSession
	root.add_child(session)
	var result := session.host_room("Cyberfield Smoke Test")
	if result != OK:
		push_error("LAN_SESSION_SMOKE_TEST_FAILED: create_server returned %d" % result)
		session.shutdown()
		session.free()
		quit(1)
		return
	if not session.is_host() or session.get_player_count() != 1:
		push_error("LAN_SESSION_SMOKE_TEST_FAILED: invalid host lobby state")
		session.shutdown()
		session.free()
		quit(1)
		return
	var announcement := {"protocol": session.PROTOCOL_VERSION, "seed": 123456, "biome_id": "lower_city"}
	var serialized := JSON.stringify(announcement)
	var parsed: Variant = JSON.parse_string(serialized)
	if not parsed is Dictionary or int((parsed as Dictionary).get("seed", 0)) != 123456:
		push_error("LAN_SESSION_SMOKE_TEST_FAILED: config serialization")
		session.shutdown()
		session.free()
		quit(1)
		return
	if not session.has_method("replicate_projectile_spawn") or not session.has_method("replicate_projectile_despawn"):
		push_error("LAN_SESSION_SMOKE_TEST_FAILED: projectile replication API missing")
		session.shutdown()
		session.free()
		quit(1)
		return
	session.shutdown()
	session.free()
	print("LAN_SESSION_SMOKE_TEST_OK")
	quit(0)
