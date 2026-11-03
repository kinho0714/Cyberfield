class_name AtomicDocument
extends RefCounted
## Small JSON-only local documents. Three immutable valid revisions; never load Objects.
var directory := "user://identity_v1"
var error := ""
var revision := 0
const MAX_BYTES := 256 * 1024


func read() -> Dictionary:
	error = ""
	revision = 0
	var best: Dictionary = {}
	for name in _files():
		var value: Dictionary = _read_file(directory.path_join(name))
		if error == "future_document":
			return {}
		if not value.is_empty() and int(value.revision) > revision:
			revision = int(value.revision)
			best = value.data
	return best.duplicate(true)


func write(data: Dictionary) -> bool:
	var expected: int = revision
	read()
	if error == "future_document":
		return false
	if revision != expected:
		error = "document_conflict"
		return false
	if not DirAccess.dir_exists_absolute(directory) and DirAccess.make_dir_recursive_absolute(directory) != OK:
		error = "document_directory_failed"
		return false
	var next: int = revision + 1
	var path: String = directory.path_join("%012d.json" % next)
	while FileAccess.file_exists(path):
		next += 1
		path = directory.path_join("%012d.json" % next)
	var payload: String = JSON.stringify({"schema_version": 1, "revision": next, "data": data})
	var text: String = JSON.stringify({"payload": payload, "checksum": payload.sha256_text()})
	if text.to_utf8_buffer().size() > MAX_BYTES:
		error = "document_too_large"
		return false
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "document_open_failed"
		return false
	file.store_string(text)
	file.flush()
	var code: Error = file.get_error()
	file.close()
	if code != OK or _read_file(path + ".tmp").is_empty() or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		error = "document_write_failed"
		return false
	revision = next
	var valid: Array[String] = []
	for name in _files():
		if not _read_file(directory.path_join(name)).is_empty():
			valid.append(name)
	while valid.size() > 3:
		DirAccess.remove_absolute(directory.path_join(valid.pop_front()))
	error = ""
	return true


func has_files() -> bool:
	return not _files().is_empty()


func _files() -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(directory)
	var result: PackedStringArray = []
	if dir != null:
		for name in dir.get_files():
			if name.ends_with(".json") and name.get_basename().is_valid_int():
				result.append(name)
	result.sort()
	return result


func _read_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK or parser.data is not Dictionary:
		return {}
	var envelope: Dictionary = parser.data
	if envelope.get("payload") is not String or String(envelope.payload).sha256_text() != envelope.get("checksum", ""):
		return {}
	if parser.parse(envelope.payload) != OK or parser.data is not Dictionary:
		return {}
	var value: Dictionary = parser.data
	if int(value.get("schema_version", 0)) > 1:
		error = "future_document"
		return {}
	if int(value.get("schema_version", 0)) != 1 or value.get("data") is not Dictionary or int(value.get("revision", 0)) < 1:
		return {}
	return value
