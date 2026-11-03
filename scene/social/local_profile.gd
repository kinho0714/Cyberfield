class_name LocalPlayerProfile
extends Node
const DOCUMENT := preload("res://scene/persistence/atomic_document.gd")
var repository: AtomicDocument = DOCUMENT.new()
var data: Dictionary = {}
var last_error := ""
var connection_status := "offline"


func initialize(path: String = "user://identity_v1") -> bool:
	if not data.is_empty():
		return true
	repository.directory = path
	var loaded: Dictionary = repository.read()
	if loaded.is_empty():
		if repository.has_files():
			last_error = "identity_recovery_required"
			return false
		loaded = {"schema_version": 1, "player_id": _id(16), "public_id": _id(8),
			"display_name": "Jogador", "privacy": {"visibility": "private", "allow_invites": "friends", "share_presence": false},
			"friends": {}, "requests": {}, "invites": {}, "blocked": {}}
		if not repository.write(loaded):
			last_error = repository.error
			return false
	if not _valid(loaded):
		last_error = "invalid_profile"
		return false
	data = loaded
	return true


func _id(bytes: int) -> String:
	return Crypto.new().generate_random_bytes(bytes).hex_encode()


func _valid(value: Dictionary) -> bool:
	if int(value.get("schema_version", 0)) != 1 or value.get("player_id") is not String or value.get("public_id") is not String or value.get("display_name") is not String:
		return false
	if value.player_id.length() != 32 or not value.player_id.is_valid_hex_number(false) or not _valid_public_id(value.public_id) or value.display_name.length() > 40:
		return false
	for key in ["privacy", "friends", "requests", "invites", "blocked"]:
		if value.get(key) is not Dictionary:
			return false
	return true


func public_view() -> Dictionary:
	if data.is_empty():
		return {}
	return {"public_id": data.public_id, "display_name": data.display_name,
		"verified_online": false, "connection_status": connection_status}


func rename(name: String) -> bool:
	if data.is_empty() or name.strip_edges().is_empty():
		return false
	var next: Dictionary = data.duplicate(true)
	next.display_name = name.strip_edges().left(40)
	return _commit(next)


func add_local_contact(public_id: String, name: String) -> bool:
	if data.is_empty() or not _valid_public_id(public_id) or public_id == data.public_id or data.blocked.has(public_id):
		return false
	var next: Dictionary = data.duplicate(true)
	next.friends[public_id] = {"public_id": public_id, "display_name": name.strip_edges().left(40), "status": "local_unverified"}
	return _commit(next)


func remove_contact(public_id: String) -> bool:
	if data.is_empty():
		return false
	var next: Dictionary = data.duplicate(true)
	next.friends.erase(public_id)
	return _commit(next)


func block(public_id: String) -> bool:
	if data.is_empty() or not _valid_public_id(public_id) or public_id == data.public_id:
		return false
	var next: Dictionary = data.duplicate(true)
	next.blocked[public_id] = true
	next.friends.erase(public_id)
	for key in ["requests", "invites"]:
		for id: Variant in next[key].keys():
			if next[key][id].get("public_id", "") == public_id:
				next[key].erase(id)
	return _commit(next)


func unblock(public_id: String) -> bool:
	if data.is_empty():
		return false
	var next: Dictionary = data.duplicate(true)
	next.blocked.erase(public_id)
	return _commit(next)


func request_contact(public_id: String) -> bool:
	if data.is_empty() or not _valid_public_id(public_id) or data.blocked.has(public_id) or public_id == data.public_id:
		return false
	var next: Dictionary = data.duplicate(true)
	next.requests[public_id] = {"public_id": public_id, "state": "local_pending_not_sent"}
	return _commit(next)


func set_privacy(invites: String, share_presence: bool) -> bool:
	if data.is_empty() or invites not in ["none", "friends"]:
		return false
	var next: Dictionary = data.duplicate(true)
	next.privacy.allow_invites = invites
	next.privacy.share_presence = share_presence
	return _commit(next)


func authenticate_online(_credential: String) -> Error:
	# A local public ID is never an authenticated backend identity.
	return ERR_UNAVAILABLE


func _valid_public_id(id: String) -> bool:
	return id.length() == 16 and id.is_valid_hex_number(false)


func _commit(next: Dictionary) -> bool:
	if not repository.write(next):
		last_error = repository.error
		return false
	data = next
	last_error = ""
	return true
