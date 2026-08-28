extends SceneTree

const LAN_SESSION_SCRIPT := preload("res://scene/network/lan_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var session := LAN_SESSION_SCRIPT.new() as LanSession
	root.add_child(session)
	await process_frame
	if session.host_room("Phase 6 LAN Contract") != OK:
		_fail("host ENet port could not open")
		return
	if session._discovery_senders.is_empty() or session.discovery_interfaces.is_empty():
		_fail("no per-interface UDP discovery sender")
		return
	var diagnostics := session.get_discovery_diagnostics()
	if not diagnostics.contains("27840") or not diagnostics.contains("27841"):
		_fail("LAN diagnostics omit ENet/discovery ports")
		return
	if not session.INPUT_ACTIONS.has(&"jump") or not session.INPUT_ACTIONS.has(&"attack") or not session.INPUT_ACTIONS.has(&"switch_weapon"):
		_fail("LAN input contract is incomplete")
		return
	Input.action_release(&"attack")
	Input.action_press(&"jump")
	if Input.is_action_pressed(&"attack"):
		_fail("jump action aliases attack")
		return
	Input.action_release(&"jump")
	if bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)):
		_fail("Android touch-to-mouse emulation remains enabled")
		return
	session.shutdown()
	session.queue_free()
	print("PHASE6_LAN_CONTRACT_SMOKE_TEST_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error("PHASE6_LAN_CONTRACT_SMOKE_TEST_FAILED: %s" % message)
	quit(1)
