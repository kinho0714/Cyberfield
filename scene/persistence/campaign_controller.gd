class_name CampaignController
extends Node
const STORE := preload("res://scene/persistence/campaign_store.gd")
const SNAPSHOT := preload("res://scene/persistence/session_snapshot.gd")
const PANEL := preload("res://scene/persistence/campaign_panel.gd")
var store := STORE.new()
var active: Dictionary = {}
var autosave_seconds := 30.0
var elapsed := 0.0
var dirty := false
var restoring := false
var last_error := ""
var panel: CanvasLayer
var game: Node


func _ready() -> void:
	game = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PANEL.new()
	panel.controller = self
	add_child(panel)
	var button := Button.new()
	button.name = "Campaigns"
	button.text = "CAMPANHAS SOLO"
	button.custom_minimum_size.y = 44
	game.mode_select.main_page.add_child(button)
	game.mode_select.main_page.move_child(button, 1)
	button.pressed.connect(panel.open)
	game.run_manager.state_changed.connect(func() -> void: dirty = true)


func _process(delta: float) -> void:
	if active.is_empty() or restoring:
		return
	elapsed += delta
	if not game.is_transitioning and ((dirty and elapsed >= 2.0) or elapsed >= maxf(autosave_seconds, 5.0)):
		save_now()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		save_now()


func meta_changed() -> bool:
	dirty = true
	# During transitions defer the complete transaction until the next stable frame.
	if game.is_transitioning or restoring:
		return _save_permanent()
	if save_now():
		return true
	return _save_permanent()


func save_now(clean_exit := false) -> bool:
	if active.is_empty() or restoring or not game.mode_selected or game.is_transitioning:
		return false
	var meta: Node = game.get_node("MetaProgression")
	if meta.dev_sandbox_active or game.run_manager.dev_session:
		return false
	var session := SNAPSHOT.capture(game)
	if session.is_empty():
		last_error = "waiting_for_consistent_frame"
		return false
	var next := active.duplicate(true)
	next.session = session
	next.permanent = meta.to_dictionary()
	next.interrupted = not clean_exit
	if not store.save_campaign(next):
		last_error = store.last_error
		return false
	active = next
	elapsed = 0.0
	dirty = false
	last_error = ""
	return true


func start_new(display_name: String, imported: Dictionary = {}) -> bool:
	if game.mode_selected or restoring:
		return false
	var defaults := MetaProgression.new()
	var permanent := defaults.to_dictionary() if imported.is_empty() else imported.duplicate(true)
	defaults.free()
	var created := store.create_campaign(display_name, int(Time.get_unix_time_from_system()) ^ randi(), permanent)
	if created.is_empty():
		last_error = store.last_error
		return false
	active = created
	game.run_manager.dev_session = false
	_apply_permanent(permanent)
	restoring = true
	await game.start_configured_run(&"solo", &"normal", -1)
	restoring = false
	if not game.mode_selected:
		_leave_without_save()
		return false
	return save_now()


func continue_campaign(id: String) -> bool:
	if game.mode_selected or restoring:
		return false
	var candidate := store.load_campaign(id)
	if candidate.is_empty() or candidate.get("mode", "") != "solo":
		last_error = store.last_error if candidate.is_empty() else "unsupported_mode"
		return false
	if not SNAPSHOT.valid(candidate.session) or candidate.session.players.size() != 1 or bool(candidate.session.run.get("dev_session", false)):
		last_error = "invalid_session"
		return false
	candidate.session.permanent = candidate.permanent.duplicate(true)
	restoring = true
	active = candidate
	_apply_permanent(candidate.permanent)
	await game.start_configured_run(&"solo", StringName(candidate.session.run.get("difficulty", "normal")), -1)
	game.is_transitioning = true
	var restored := game.mode_selected and SNAPSHOT.restore(game, candidate.session)
	game.is_transitioning = false
	restoring = false
	if not restored:
		last_error = "session_restore_failed"
		# Preserve every stored revision. Never save a failed reconstruction.
		active = {}
		await game._clear_run_and_show_menu()
		_apply_legacy()
		return false
	game._set_all_player_input(true)
	return save_now()


func leave() -> void:
	if active.is_empty():
		return
	var dev: Node = game.get_node("DevMode")
	if dev.is_sandbox_active():
		dev.end_session()
	if not save_now(true):
		push_warning("Campaign save pending: " + last_error)
	_leave_without_save()


func _leave_without_save() -> void:
	active = {}
	dirty = false
	_apply_legacy()


func _apply_legacy() -> void:
	game.get_node("MetaProgression").load_profile()


func _apply_permanent(data: Dictionary) -> void:
	var meta: Node = game.get_node("MetaProgression")
	meta._reset_defaults()
	meta._apply_save(data)
	meta.profile_changed.emit()


func import_legacy(display_name: String) -> bool:
	if game.mode_selected or restoring:
		return false
	var meta: Node = game.get_node("MetaProgression")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta.legit_save_path()))
	if parsed is not Dictionary or int(parsed.get("version", 1)) < 1 or int(parsed.get("version", 1)) > MetaProgression.SAVE_VERSION:
		last_error = "invalid_legacy_version"
		return false
	var copy := MetaProgression.new()
	copy._reset_defaults()
	copy._apply_save(parsed)
	var permanent := copy.to_dictionary()
	copy.free()
	return await start_new(display_name, permanent)


func _save_permanent() -> bool:
	if active.is_empty() or game.get_node("MetaProgression").dev_sandbox_active or game.run_manager.dev_session:
		return false
	var next := active.duplicate(true)
	next.permanent = game.get_node("MetaProgression").to_dictionary()
	if not next.session.is_empty():
		next.session.permanent = next.permanent.duplicate(true)
	if not store.save_campaign(next):
		last_error = store.last_error
		return false
	active = next
	return true
