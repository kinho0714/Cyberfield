extends SceneTree
const PROFILE := preload("res://scene/social/local_profile.gd")
var failures := 0


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile: LocalPlayerProfile = PROFILE.new()
	var path: String = "user://test_profile_" + Crypto.new().generate_random_bytes(12).hex_encode()
	check(profile.initialize(path), "local identity created without account")
	var id: String = profile.data.player_id
	var contact: String = "a".repeat(16)
	check(profile.rename("Tester") and profile.add_local_contact(contact, "Friend"), "name and local contact")
	check(profile.request_contact("b".repeat(16)), "pending local request")
	check(profile.public_view().display_name == "Tester" and not profile.public_view().has("player_id"), "private ID excluded")
	check(not profile.public_view().has("friends") and not profile.public_view().has("blocked"), "social graph private")
	check(profile.authenticate_online("declared_id") == ERR_UNAVAILABLE, "no fake authentication")
	check(profile.block(contact) and not profile.data.friends.has(contact), "block removes contact")
	check(not profile.add_local_contact(contact, "Blocked"), "blocked contact refused")
	var reopened: LocalPlayerProfile = PROFILE.new()
	check(reopened.initialize(path) and reopened.data.player_id == id, "persistent identity")
	check(reopened.data.blocked.has(contact), "privacy persists")
	var latest: String = path.path_join("%012d.json" % reopened.repository.revision)
	var file: FileAccess = FileAccess.open(latest, FileAccess.WRITE)
	file.store_string("broken fixture")
	file.close()
	var recovered: LocalPlayerProfile = PROFILE.new()
	check(recovered.initialize(path) and recovered.data.player_id == id, "identity recovers previous revision")
	var files_before: PackedStringArray = recovered.repository._files()
	for name in files_before:
		file = FileAccess.open(path.path_join(name), FileAccess.WRITE)
		file.store_string("broken disposable profile")
		file.close()
	var unreadable: LocalPlayerProfile = PROFILE.new()
	check(not unreadable.initialize(path) and unreadable.data.is_empty(), "all-invalid identity never silently replaced")
	check(unreadable.repository._files() == files_before, "invalid identity revisions preserved")
	unreadable.free()
	profile.free()
	reopened.free()
	recovered.free()
	print("LOCAL_PROFILE_REPORT failures=", failures)
	quit(0 if failures == 0 else 1)
