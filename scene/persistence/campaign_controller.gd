class_name CampaignController
extends Node
const STORE := preload("res://scene/persistence/campaign_store.gd")
const SNAPSHOT := preload("res://scene/persistence/session_snapshot.gd")
const WORLD := preload("res://scene/world/world_state.gd")
const TRACKER := preload("res://scene/world/world_tracker.gd")
var geography: Node
var private_session: Node
const PRIVATE_SESSION := preload("res://scene/network/private_session_client.gd")
var profile: Node
const PROFILE := preload("res://scene/social/local_profile.gd")
var services: CanvasLayer
const SERVICES := preload("res://scene/persistence/campaign_services.gd")
const PANEL := preload("res://scene/persistence/campaign_panel.gd")
const UI_KIT := preload("res://ui/cyber_ui.gd")
const SOCIAL_BRIDGE := preload("res://scene/social/social_bridge.gd")
const SOCIAL_PANEL := preload("res://scene/social/social_panel.gd")
const PRIVATE_PANEL := preload("res://scene/network/private_session_panel.gd")
var social: Node
var social_panel: CanvasLayer
var private_panel: CanvasLayer
var store := STORE.new()
var active: Dictionary = {}
var autosave_seconds := 30.0
var elapsed := 0.0
var dirty := false
var restoring := false
var last_error := ""
var recovery_status: Dictionary = {}
var save_status: Label
var panel: CanvasLayer
var game: Node


func _ready() -> void:
	game = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	private_session = PRIVATE_SESSION.new()
	private_session.name = "PrivateSession"
	add_child(private_session)
	profile = PROFILE.new()
	profile.name = "LocalProfile"
	add_child(profile)
	geography = TRACKER.new()
	geography.controller = self
	add_child(geography)
	services = SERVICES.new()
	services.controller = self
	add_child(services)
	panel = PANEL.new()
	panel.name = "CampaignPanel"
	panel.controller = self
	add_child(panel)
	social = SOCIAL_BRIDGE.new()
	social.name = "SocialBridge"
	add_child(social)
	social.setup(profile, private_session)
	social_panel = SOCIAL_PANEL.new()
	social_panel.name = "SocialPanel"
	social_panel.controller = self
	add_child(social_panel)
	private_panel = PRIVATE_PANEL.new()
	private_panel.name = "PrivateSessionPanel"
	private_panel.controller = self
	add_child(private_panel)
	# 03/11: o menu inicial é dono da navegação (JOGAR → CAMPANHA SOLO / COOPERATIVO,
	# SOCIAL); este controlador só atende às intenções. Nenhum botão é injetado.
	var menu: Node = game.mode_select
	menu.solo_state_provider = solo_menu_state
	menu.social_state_provider = social_menu_state
	menu.campaign_requested.connect(_on_campaign_requested)
	menu.social_requested.connect(func(tab: StringName) -> void: social_panel.open(String(tab), &"social", _social_focus(tab)))
	menu.private_session_requested.connect(func(tab: StringName) -> void:
		private_panel.open("room" if tab == &"create" and private_session.status not in ["offline", "error"] else String(tab), &"coop", _private_focus(tab)))
	var status_layer: CanvasLayer = CanvasLayer.new()
	status_layer.layer = 35
	add_child(status_layer)
	save_status = Label.new()
	save_status.position = Vector2(20, 8)
	save_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_layer.add_child(save_status)
	game.run_manager.state_changed.connect(func() -> void: dirty = true)


func _process(delta: float) -> void:
	if save_status != null:
		save_status.visible = not active.is_empty() and not last_error.is_empty()
		save_status.text = error_message(last_error)
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
	if restoring:
		return true
	if game.is_transitioning:
		return _save_permanent()
	if save_now():
		return true
	return _save_permanent()


## Estado da página CAMPANHA SOLO: campanha mais recente e se CONTINUAR é possível.
func solo_menu_state() -> Dictionary:
	# Uma leitura só: cada listagem decodifica as revisões de todos os slots.
	var summaries: Array[Dictionary] = store.list_campaigns()
	var latest := latest_campaign(summaries)
	if latest.is_empty():
		return {"continue": false, "status": "NENHUMA CAMPANHA SALVA" if summaries.is_empty() else "NENHUM SAVE ÍNTEGRO PARA CONTINUAR"}
	return {"continue": true, "status": "ÚLTIMA: %s • %s" % [String(latest.display_name).left(22), UI_KIT.local_time(String(latest.get("last_played_at", "")))]}


func social_menu_state() -> Dictionary:
	if not profile.initialize():
		return {"status": "PERFIL INDISPONÍVEL • ARQUIVOS PRESERVADOS"}
	var waiting: int = profile.data.incoming.size()
	var friends: int = profile.data.friends.size()
	var status := "%s • %s" % [String(profile.data.display_name).left(18), "1 AMIGO" if friends == 1 else "%d AMIGOS" % friends]
	if waiting > 0:
		status += " • 1 PEDIDO NOVO" if waiting == 1 else " • %d PEDIDOS NOVOS" % waiting
	return {"status": status}


## Campanha íntegra jogada por último (por `last_played_at`, carimbo UTC ISO).
func latest_campaign(summaries: Array[Dictionary] = []) -> Dictionary:
	if summaries.is_empty():
		summaries = store.list_campaigns()
	var best: Dictionary = {}
	for summary: Dictionary in summaries:
		if summary.has("error"):
			continue
		if best.is_empty() or String(summary.get("last_played_at", "")) > String(best.get("last_played_at", "")):
			best = summary
	return best


func continue_latest() -> bool:
	var latest := latest_campaign()
	if latest.is_empty() or game.mode_selected or restoring:
		return false
	game.mode_select.requesting_run = true
	game.mode_select.solo_status.text = "CARREGANDO %s…" % String(latest.display_name).left(22)
	var restored: bool = await continue_campaign(String(latest.campaign_id))
	if not restored and not game.mode_selected:
		game.mode_select.return_to(&"solo", &"Continue")
		game.mode_select.solo_status.text = error_message(last_error).to_upper()
	game.mode_select.requesting_run = false
	return restored


func _on_campaign_requested(action: StringName) -> void:
	match action:
		&"continue":
			continue_latest()
		&"create":
			panel.open("create")
		&"manage":
			panel.open("slots")


func _social_focus(tab: StringName) -> StringName:
	return {&"profile": &"Profile", &"friends": &"Friends", &"requests": &"Requests", &"blocked": &"Blocked"}.get(tab, &"Profile")


func _private_focus(tab: StringName) -> StringName:
	return {&"create": &"PrivateCreate", &"join": &"PrivateJoin", &"invites": &"Invites"}.get(tab, &"PrivateCreate")


func save_now(clean_exit := false) -> bool:
	if active.is_empty() or restoring or not game.mode_selected or game.is_transitioning:
		return false
	var meta: Node = game.get_node("MetaProgression")
	if meta.dev_sandbox_active or game.run_manager.dev_session:
		return false
	var session: Dictionary = SNAPSHOT.capture(game)
	if session.is_empty():
		last_error = "waiting_for_consistent_frame"
		return false
	geography.sample()
	var next: Dictionary = active.duplicate(true)
	session.geographic_location = next.world.location.duplicate(true)
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
	var permanent: Dictionary = defaults.to_dictionary() if imported.is_empty() else imported.duplicate(true)
	defaults.free()
	var created: Dictionary = store.create_campaign(display_name, int(Time.get_unix_time_from_system()) ^ randi(), permanent)
	if created.is_empty():
		last_error = store.last_error
		return false
	if not WORLD.ensure(created):
		last_error = "invalid_world_catalog"
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
	var revisions: Array[Dictionary] = store.load_revisions(id)
	if revisions.is_empty():
		last_error = store.last_error
		return false
	var newest: Dictionary = revisions[0]
	if not WORLD.ensure(newest):
		last_error = "invalid_world_catalog"
		return false
	if newest.get("mode", "") != "solo":
		last_error = "unsupported_mode"
		return false
	autosave_seconds = clampf(float(newest.get("autosave_seconds", 30.0)), 5.0, 300.0)
	recovery_status = store.recovery_info.duplicate(true)
	restoring = true
	active = newest.duplicate(true)
	_apply_permanent(newest.permanent)
	await game.start_configured_run(&"solo", &"normal", -1)
	var restored: bool = false
	for candidate: Dictionary in revisions:
		if not SNAPSHOT.valid(candidate.session) or candidate.session.players.size() != 1 or bool(candidate.session.run.get("dev_session", false)):
			continue
		# Keep the latest permanent ledger even when recovering an older run snapshot.
		var session: Dictionary = candidate.session.duplicate(true)
		session.permanent = newest.permanent.duplicate(true)
		if session.get("geographic_location") is Dictionary:
			active.world.location = session.geographic_location.duplicate(true)
		game.is_transitioning = true
		restored = bool(game.mode_selected) and SNAPSHOT.restore(game, session)
		game.is_transitioning = false
		if restored:
			if session.get("geographic_location") is Dictionary:
				active.world.location = session.geographic_location.duplicate(true)
			recovery_status.restored_revision = candidate.revision
			recovery_status.used_backup = int(candidate.revision) != int(newest.revision) or int(recovery_status.get("damaged_revisions", 0)) > 0
			break
	restoring = false
	if not restored:
		last_error = "session_restore_failed"
		active = {}
		await game._clear_run_and_show_menu()
		_apply_legacy()
		return false
	game._set_all_player_input(true)
	save_now()
	return true


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
	var permanent: Dictionary = copy.to_dictionary()
	copy.free()
	return await start_new(display_name, permanent)


func _save_permanent() -> bool:
	if active.is_empty() or game.get_node("MetaProgression").dev_sandbox_active or game.run_manager.dev_session:
		return false
	var next: Dictionary = active.duplicate(true)
	next.permanent = game.get_node("MetaProgression").to_dictionary()
	if not next.session.is_empty():
		next.session.permanent = next.permanent.duplicate(true)
	if not store.save_campaign(next):
		last_error = store.last_error
		return false
	active = next
	return true


func set_autosave_interval(seconds: float) -> bool:
	if active.is_empty() or restoring:
		return false
	var next: Dictionary = active.duplicate(true)
	next.autosave_seconds = clampf(seconds, 5.0, 300.0)
	if not store.save_campaign(next):
		last_error = store.last_error
		return false
	active = next
	autosave_seconds = next.autosave_seconds
	return true


static func error_message(code: String) -> String:
	var messages: Dictionary = {
		"": "", "waiting_for_consistent_frame": "Salvamento aguardando fim do combate/efeito.",
		"future_schema": "Save de uma versão mais nova. Atualize o jogo.",
		"no_valid_snapshot": "Nenhuma revisão íntegra disponível. Os arquivos foram preservados.",
		"session_restore_failed": "Não foi possível reconstruir esta sessão. Saves preservados.",
		"invalid_session": "Snapshot incompatível. Saves preservados.",
		"revision_conflict": "O save mudou desde a leitura. Reabra a campanha.",
		"invalid_legacy_version": "Perfil legado ausente, inválido ou de versão mais nova.",
		"unsupported_mode": "Este tipo de campanha ainda não pode ser continuado aqui.",
	}
	return String(messages.get(code, "Falha ao gravar/acessar o save. Verifique o armazenamento; revisões anteriores preservadas."))
