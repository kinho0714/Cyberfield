extends SceneTree
const STORE := preload("res://scene/persistence/campaign_store.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var store := STORE.new()
	# Unique test namespace; never open or remove production campaigns/saves.
	store.root_path = "user://test_campaigns_" + store.new_id()
	var a := store.create_campaign("A", 1234, {"credits": 12})
	var b := store.create_campaign("B", 5678, {"credits": 90})
	check(not a.is_empty() and not b.is_empty(), "create two slots")
	check(a.campaign_id != b.campaign_id, "independent IDs")
	check(store.rename_campaign(b.campaign_id, "Renamed"), "rename selected slot")
	check(store.load_campaign(b.campaign_id).display_name == "Renamed", "renamed metadata persisted")
	b = store.load_campaign(b.campaign_id)
	check(store.load_campaign(a.campaign_id).permanent.credits == 12, "reopen")
	a.session = {"health": 23, "ammo": {&"pulse_carbine": 7}, "position": Vector2(12, 34)}
	check(store.save_campaign(a), "save real Variant types")
	var reopened := store.load_campaign(a.campaign_id)
	check(reopened.session.position == Vector2(12, 34), "Vector2 roundtrip")
	check(reopened.session.ammo[&"pulse_carbine"] == 7, "StringName roundtrip")
	check(store.record_event(a, "clue-test", {"clue": true}), "permanent story event")
	check(not store.record_event(a, "clue-test", {"clue": false}), "idempotent event")
	check(store.load_campaign(b.campaign_id).permanent.credits == 90, "slot isolation")
	var stale := reopened.duplicate(true)
	check(not store.save_campaign(stale) and store.last_error == "revision_conflict", "reject stale revision")
	var folder := store.root_path.path_join(a.campaign_id)
	var latest := folder.path_join("%012d.json" % int(a.revision))
	var file := FileAccess.open(latest, FileAccess.WRITE)
	file.store_string("{incomplete")
	file.close()
	var backup := store.load_campaign(a.campaign_id)
	check(not backup.is_empty() and backup.revision < a.revision, "recover previous complete snapshot")
	check(FileAccess.get_file_as_string(latest) == "{incomplete", "preserve damaged revision")
	check(store.save_campaign(backup), "save after recovery without overwriting damaged file")
	check(FileAccess.get_file_as_string(latest) == "{incomplete", "damaged bytes still retained")
	file = FileAccess.open(folder.path_join("999999999999.json.tmp"), FileAccess.WRITE)
	file.store_string("partial")
	file.close()
	check(not store.load_campaign(a.campaign_id).is_empty(), "ignore interrupted temporary write")
	var valid_path := folder.path_join("%012d.json" % int(backup.revision))
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(valid_path))
	envelope.payload = String(envelope.payload) + "tampered"
	file = FileAccess.open(valid_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	check(store.load_campaign(a.campaign_id).revision < backup.revision, "checksum mismatch rejected")
	file = FileAccess.open(folder.path_join("999999999999.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 999}))
	file.close()
	check(store.load_campaign(a.campaign_id).is_empty() and store.last_error == "future_schema", "future schema refused")
	check(not store.save_campaign(backup), "future schema never overwritten")
	check(not store.delete_campaign(b.campaign_id, "wrong"), "explicit confirmation")
	check(store.delete_campaign(b.campaign_id, b.campaign_id), "isolated deletion")
	check(store.load_campaign(b.campaign_id).is_empty(), "deleted slot hidden")
	check(DirAccess.dir_exists_absolute(folder), "other slot preserved")
	check(not store.valid_id("../escape"), "path traversal refused")
	check(not store.save_campaign({"campaign_id": store.new_id()}), "malformed data refused")
	var blocked_path: String = store.root_path.path_join("blocked")
	file = FileAccess.open(blocked_path, FileAccess.WRITE)
	file.store_string("sentinel")
	file.close()
	var denied := STORE.new()
	denied.root_path = blocked_path
	check(denied.create_campaign("Denied", 1, {}).is_empty(), "directory failure reported")
	check(FileAccess.get_file_as_string(blocked_path) == "sentinel", "failed write preserves existing bytes")
	var meta := MetaProgression.new()
	meta._reset_defaults()
	meta._apply_save({"version": 1, "money": 55, "blueprints": ["scrap_blade"]})
	check(meta.credits == 55 and meta.to_dictionary().version == 4, "legacy migration to current meta schema")
	meta.free()
	print("CAMPAIGN_STORE_REPORT failures=", failures, " test_namespace=", store.root_path)
	quit(0 if failures == 0 else 1)
