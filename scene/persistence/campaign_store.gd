class_name CampaignStore
extends RefCounted
## Immutable revisions: a failed write never truncates an existing snapshot.
## Variant decoding never allows objects. Checksums detect damage, not hostile edits.

const SCHEMA_VERSION := 1
const KEEP_REVISIONS := 3
const MAX_BYTES := 32 * 1024 * 1024
var root_path := "user://campaigns_v1"
var last_error := ""


func new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func valid_id(id: String) -> bool:
	return id.length() == 32 and id.is_valid_hex_number(false)


func create_campaign(display_name: String, seed_value: int, permanent: Dictionary, dev := false) -> Dictionary:
	var id := new_id()
	var now := Time.get_datetime_string_from_system(true)
	var data := {
		"campaign_id": id, "display_name": display_name.strip_edges().left(80),
		"created_at": now, "last_played_at": now, "campaign_seed": seed_value,
		"save_version": SCHEMA_VERSION, "mode": "dev" if dev else "solo",
		"owner_id": "local", "participants": ["local"], "revision": 0,
		"permanent": permanent.duplicate(true), "story": {}, "events": {},
		"session": {}, "interrupted": false,
	}
	if not save_campaign(data):
		return {}
	return data


func save_campaign(data: Dictionary) -> bool:
	last_error = ""
	var id := String(data.get("campaign_id", ""))
	if not _valid_data(data) or not valid_id(id):
		return _fail("invalid_campaign")
	var previous := load_campaign(id)
	if last_error == "future_schema":
		return false
	if not previous.is_empty() and int(data.get("revision", 0)) != int(previous.revision):
		return _fail("revision_conflict")
	if previous.is_empty() and int(data.get("revision", 0)) != 0:
		return _fail("no_valid_previous_revision")
	var next := data.duplicate(true)
	next.revision = int(data.get("revision", 0)) + 1
	next.last_played_at = Time.get_datetime_string_from_system(true)
	var folder := root_path.path_join(id)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return _fail("directory_failed")
	var payload := Marshalls.raw_to_base64(var_to_bytes(next))
	var envelope := {"schema_version": SCHEMA_VERSION, "payload": payload, "checksum": payload.sha256_text()}
	var target := folder.path_join("%012d.json" % int(next.revision))
	# A damaged revision is retained; never overwrite it during recovery.
	while FileAccess.file_exists(target):
		next.revision += 1
		target = folder.path_join("%012d.json" % int(next.revision))
	payload = Marshalls.raw_to_base64(var_to_bytes(next))
	envelope.payload = payload
	envelope.checksum = payload.sha256_text()
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("open_failed")
	file.store_string(JSON.stringify(envelope))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _fail("write_failed")
	if _read_revision(temporary, id).is_empty():
		return _fail("verification_failed")
	if DirAccess.rename_absolute(temporary, target) != OK:
		return _fail("rename_failed")
	data.revision = next.revision
	data.last_played_at = next.last_played_at
	_prune(folder, id)
	last_error = ""
	return true


func load_campaign(id: String) -> Dictionary:
	last_error = ""
	if not valid_id(id):
		_fail("invalid_id")
		return {}
	var folder := root_path.path_join(id)
	var files := _revision_files(folder)
	var best: Dictionary = {}
	for filename in files:
		var value := _read_revision(folder.path_join(filename), id)
		# Never silently downgrade a campaign written by a newer game.
		if last_error == "future_schema":
			return {}
		if not value.is_empty() and int(value.revision) > int(best.get("revision", 0)):
			best = value
	if best.is_empty():
		_fail("no_valid_snapshot")
	else:
		last_error = ""
	return best


func list_campaigns() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	for id in directory.get_directories():
		if valid_id(id):
			var data := load_campaign(id)
			if data.is_empty():
				result.append({"campaign_id": id, "display_name": "SAVE INDISPONÍVEL", "error": last_error})
			else:
				result.append({"campaign_id": id, "display_name": data.display_name,
					"mode": data.mode, "revision": data.revision, "interrupted": data.interrupted,
					"last_played_at": data.last_played_at})
	return result


func rename_campaign(id: String, display_name: String) -> bool:
	var data := load_campaign(id)
	if data.is_empty() or display_name.strip_edges().is_empty():
		return false
	data.display_name = display_name.strip_edges().left(80)
	return save_campaign(data)


func delete_campaign(id: String, confirmed_id: String) -> bool:
	if not valid_id(id) or confirmed_id != id:
		return _fail("confirmation_required")
	# Isolated soft deletion retains all snapshots, including damaged versions.
	return DirAccess.rename_absolute(root_path.path_join(id), root_path.path_join("deleted_" + id + "_" + new_id())) == OK


func record_event(data: Dictionary, event_id: String, value: Dictionary) -> bool:
	if event_id.is_empty() or data.events.has(event_id):
		return false
	var next := data.duplicate(true)
	next.events[event_id] = true
	next.story.merge(value, true)
	if not save_campaign(next):
		return false
	data.merge(next, true)
	return true


func _valid_data(value: Dictionary) -> bool:
	return valid_id(String(value.get("campaign_id", ""))) and value.get("session") is Dictionary \
		and value.get("permanent") is Dictionary and value.get("story") is Dictionary \
		and value.get("events") is Dictionary and value.get("mode", "") in ["solo", "dev"] \
		and int(value.get("save_version", -1)) == SCHEMA_VERSION \
		and value.get("revision") is int and int(value.revision) >= 0 \
		and value.get("display_name") is String


func _read_revision(path: String, id: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return {}
	var envelope: Dictionary = parsed
	if int(envelope.get("schema_version", 0)) > SCHEMA_VERSION:
		_fail("future_schema")
		return {}
	if int(envelope.get("schema_version", 0)) != SCHEMA_VERSION:
		return {}
	var payload := String(envelope.get("payload", ""))
	if payload.sha256_text() != String(envelope.get("checksum", "")):
		return {}
	var decoded: Variant = bytes_to_var(Marshalls.base64_to_raw(payload))
	if decoded is not Dictionary or not _valid_data(decoded) or String(decoded.campaign_id) != id:
		return {}
	return decoded


func _revision_files(folder: String) -> PackedStringArray:
	var directory := DirAccess.open(folder)
	var result := PackedStringArray()
	if directory != null:
		for filename in directory.get_files():
			if filename.ends_with(".json") and filename.get_basename().is_valid_int():
				result.append(filename)
	result.sort()
	return result


func _prune(folder: String, id: String) -> void:
	var valid := PackedStringArray()
	for filename in _revision_files(folder):
		if not _read_revision(folder.path_join(filename), id).is_empty():
			valid.append(filename)
	while valid.size() > KEEP_REVISIONS:
		DirAccess.remove_absolute(folder.path_join(valid[0]))
		valid.remove_at(0)


func _fail(code: String) -> bool:
	last_error = code
	return false
