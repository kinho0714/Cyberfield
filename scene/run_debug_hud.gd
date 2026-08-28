extends CanvasLayer

@onready var status_label: Label = $Panel/Margin/VBox/Status
@onready var restart_button: Button = $Panel/Margin/VBox/Restart
@onready var room_title: Label = $RoomTitle
@onready var end_overlay: ColorRect = $EndOverlay
@onready var end_title: Label = $EndOverlay/Center/VBox/Title
@onready var end_restart: Button = $EndOverlay/Center/VBox/Restart
@onready var revive_panel: VBoxContainer = $RevivePanel
@onready var revive_progress: ProgressBar = $RevivePanel/Progress
@onready var players_status: Label = $PlayersStatus
@onready var waiting_label: Label = $WaitingLabel
@onready var back_to_mode: Button = $EndOverlay/Center/VBox/BackToMode
@onready var gameplay_hud: Control = $GameplayHUD
@onready var local_name: Label = $GameplayHUD/PlayerPanel/Margin/VBox/Name
@onready var local_health: ProgressBar = $GameplayHUD/PlayerPanel/Margin/VBox/Health
@onready var local_health_text: Label = $GameplayHUD/PlayerPanel/Margin/VBox/HealthText
@onready var local_stats: Label = $GameplayHUD/PlayerPanel/Margin/VBox/Stats
@onready var partner_panel: PanelContainer = $GameplayHUD/PartnerPanel
@onready var partner_name: Label = $GameplayHUD/PartnerPanel/VBox/Name
@onready var partner_health: ProgressBar = $GameplayHUD/PartnerPanel/VBox/Health
@onready var partner_status: Label = $GameplayHUD/PartnerPanel/VBox/Status
@onready var boss_panel: PanelContainer = $GameplayHUD/BossPanel
@onready var boss_name: Label = $GameplayHUD/BossPanel/VBox/Name
@onready var boss_health: ProgressBar = $GameplayHUD/BossPanel/VBox/Health
@onready var run_timer: Label = $GameplayHUD/RunTimer

var run_manager: Node
var local_settings: LocalSettings


func _ready() -> void:
	run_manager = get_parent().get_node("RunManager")
	local_settings = get_parent().get_node("LocalSettings")
	run_manager.state_changed.connect(_refresh)
	local_settings.settings_changed.connect(_apply_debug_visibility)
	restart_button.pressed.connect(get_parent().return_to_laboratory)
	$Panel/Margin/VBox/BackToMenu.pressed.connect(get_parent().return_to_main_menu)
	end_restart.pressed.connect(get_parent().return_to_laboratory)
	back_to_mode.pressed.connect(get_parent().return_to_main_menu)
	restart_button.text = "RETORNAR AO LABORATÓRIO"
	end_restart.text = "RETORNAR AO LABORATÓRIO"
	back_to_mode.text = "VOLTAR AO MENU"
	get_parent().coop_waiting_changed.connect(func(value: bool) -> void: waiting_label.visible = value)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_apply_debug_visibility()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F4:
		local_settings.set_debug_hud_visible(not local_settings.debug_hud_visible)


func _apply_debug_visibility() -> void:
	$Panel.visible = local_settings.debug_hud_visible
	room_title.visible = local_settings.debug_hud_visible
	players_status.visible = local_settings.debug_hud_visible
	for collider_visual in get_tree().get_nodes_in_group("procedural_debug_collider"):
		collider_visual.visible = local_settings.debug_hud_visible
	for debug_label in get_tree().get_nodes_in_group("procedural_debug_text"):
		debug_label.visible = local_settings.debug_hud_visible


func _apply_safe_area() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var safe_position := Vector2.ZERO
	var safe_end := viewport_size
	if OS.has_feature("mobile"):
		var display_size := Vector2(DisplayServer.screen_get_size())
		var display_safe_area := DisplayServer.get_display_safe_area()
		if display_size.x > 0.0 and display_size.y > 0.0 and display_safe_area.size.x > 0 and display_safe_area.size.y > 0:
			var display_to_viewport := viewport_size / display_size
			safe_position = Vector2(display_safe_area.position) * display_to_viewport
			safe_end = Vector2(display_safe_area.end) * display_to_viewport
	gameplay_hud.offset_left = clampf(safe_position.x, 0.0, viewport_size.x)
	gameplay_hud.offset_top = clampf(safe_position.y, 0.0, viewport_size.y)
	gameplay_hud.offset_right = clampf(safe_end.x, 0.0, viewport_size.x) - viewport_size.x
	gameplay_hud.offset_bottom = clampf(safe_end.y, 0.0, viewport_size.y) - viewport_size.y
	var result_center := $EndOverlay/Center as Control
	result_center.offset_left = clampf(safe_position.x, 0.0, viewport_size.x) + 24.0
	result_center.offset_top = clampf(safe_position.y, 0.0, viewport_size.y) + 18.0
	result_center.offset_right = clampf(safe_end.x, 0.0, viewport_size.x) - viewport_size.x - 24.0
	result_center.offset_bottom = clampf(safe_end.y, 0.0, viewport_size.y) - viewport_size.y - 18.0


func _process(_delta: float) -> void:
	run_timer.text = run_manager.format_run_time()
	var downed_player: Node = null
	for player in get_tree().get_nodes_in_group("player"):
		if player.is_downed:
			downed_player = player
			break
	revive_panel.visible = downed_player != null and run_manager.run_active
	if downed_player:
		revive_progress.value = downed_player.revive_progress / downed_player.revive_duration * 100.0
	var players: Array[Node] = []
	players.assign(get_tree().get_nodes_in_group("player"))
	players.sort_custom(func(a: Node, b: Node) -> bool: return String(a.participant_id) < String(b.participant_id))
	var local_player := _get_local_player(players)
	var partner_player := _get_partner_player(players, local_player)
	gameplay_hud.visible = run_manager.is_gameplay_context_active() and local_player != null and not end_overlay.visible
	if end_overlay.visible:
		revive_panel.visible = false
		$Panel.visible = false
		room_title.visible = false
		players_status.visible = false
	if local_player != null:
		_update_local_player_hud(local_player)
	_update_partner_hud(partner_player)
	_update_boss_hud()
	var lines: PackedStringArray = []
	for player in players:
		if not player.visible:
			continue
		lines.append("%s // HP %d/%d // COMBO %d // PERFIL %s" % [String(player.participant_id).replace("player_", "P"), player.health, player.max_health, player.total_combo_hits, player.input_profile])
		if local_settings.debug_hud_visible and player.input_profile == "p2":
			var lan_session := get_tree().get_first_node_in_group("lan_session")
			if lan_session != null and lan_session.is_network_game():
				lines.append("P2 REDE: %s // %d/2" % [lan_session.get_role_label(), lan_session.get_player_count()])
			else:
				var connected := Input.get_connected_joypads().has(player.joypad_device_id)
				lines.append("P2 CONTROLE: %s // ID %d" % ["CONECTADO" if connected else "DESCONECTADO", player.joypad_device_id])
	players_status.text = "\n".join(lines)


func _get_local_player(players: Array[Node]) -> Node:
	var local_participant := &"player_1"
	var lan_session := get_tree().get_first_node_in_group("lan_session")
	if lan_session != null and lan_session.is_client():
		local_participant = &"player_2"
	for player in players:
		if player.participant_id == local_participant and player.visible:
			return player
	return players[0] if not players.is_empty() else null


func _get_partner_player(players: Array[Node], local_player: Node) -> Node:
	for player in players:
		if player != local_player and player.visible:
			return player
	return null


func _update_local_player_hud(player: Node) -> void:
	local_name.text = "%s%s" % [String(player.participant_id).replace("player_", "P"), " — CAÍDO" if player.is_downed else ""]
	local_health.max_value = player.max_health
	local_health.value = player.health
	local_health_text.text = "%d / %d" % [player.health, player.max_health]
	var potion_segments := "■".repeat(player.heal_doses) + "□".repeat(player.max_heal_doses - player.heal_doses)
	var weapon_name := WeaponCatalog.get_display_name(player.get_active_weapon_id())
	local_stats.text = "POÇÃO %s  |  I %d  S %d  F %d  |  $%d\nARMA %d: %s" % [potion_segments, player.intellect, player.health_attribute, player.strength, run_manager.dirty_money, player.active_weapon_slot + 1, weapon_name]


func _update_partner_hud(player: Node) -> void:
	partner_panel.visible = player != null and run_manager.is_coop()
	if player == null:
		return
	partner_name.text = String(player.participant_id).replace("player_", "P")
	partner_health.max_value = player.max_health
	partner_health.value = player.health
	partner_status.text = "CAÍDO" if player.is_downed else "%d / %d" % [player.health, player.max_health]


func _update_boss_hud() -> void:
	var active_boss: Node = null
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("is_boss") and enemy.is_boss() and enemy.health > 0:
			active_boss = enemy
			break
	boss_panel.visible = active_boss != null and run_manager.run_active
	if active_boss == null:
		return
	boss_name.text = "BOSS PLACEHOLDER"
	boss_health.max_value = active_boss.max_health
	boss_health.value = active_boss.health


func _refresh() -> void:
	var status := "ATIVA" if run_manager.run_active else "INATIVA"
	var completed := "\nRUN CONCLUÍDA" if run_manager.run_is_completed else ""
	var mode_label := "Co-op" if run_manager.is_coop() else "Solo"
	restart_button.disabled = run_manager.is_in_hub()
	if run_manager.is_in_hub():
		status_label.text = "Laboratório\nRun: INATIVA\nModo: %s\nDificuldade preparada: %s\nJogadores: %d" % [mode_label, run_manager.get_difficulty_label(), run_manager.player_count]
		room_title.text = "LABORATÓRIO // HUB"
		end_overlay.visible = false
		return
	if not run_manager.current_biome_id.is_empty():
		var lan_session := get_tree().get_first_node_in_group("lan_session")
		var network_text := "\nREDE: %s // PEER %d // %d/2" % [lan_session.get_role_label(), multiplayer.get_unique_id(), lan_session.get_player_count()] if lan_session != null and lan_session.is_network_game() else ""
		var fallback_text := "\nGENERATION FALLBACK: %s" % run_manager.generation_failure_reason if run_manager.generation_fallback else ""
		var exit_text := "\nSAÍDA: %s → %s" % [run_manager.selected_exit_id, run_manager.selected_exit_destination] if not run_manager.selected_exit_id.is_empty() else ""
		status_label.text = (
			"Run: %s\nModo: %s\nDificuldade: %s\nDinheiro Sujo: $%d\nSTAGE: %d/6\nBIOMA: %s\nSEED: %d\nMÓDULOS: %d\nInimigos vivos: %d%s%s%s"
			% [status, mode_label, run_manager.get_difficulty_label(), run_manager.dirty_money, mini(run_manager.stage_index + 1, 6), run_manager.current_biome_name, run_manager.seed_value, run_manager.generated_module_count, run_manager.get_alive_enemy_count(), fallback_text, exit_text, network_text]
		)
		room_title.text = "BIOMA // %s" % run_manager.current_biome_name
		end_overlay.visible = run_manager.run_is_completed or run_manager.run_is_lost
		if run_manager.run_is_lost:
			end_title.text = _build_run_summary(false)
		elif run_manager.run_is_completed:
			end_title.text = _build_run_summary(true)
		if end_overlay.visible:
			gameplay_hud.visible = false
			end_restart.grab_focus()
		return
	status_label.text = (
		"Run: %s\nModo: %s\nDificuldade: %s\nJogadores: %d\nDinheiro Sujo: $%d\nSala: %d/%d\nTipo: %s\nInimigos vivos: %d\nChefes vivos: %d\nConcluídas: %d%s"
		% [status, mode_label, run_manager.get_difficulty_label(), run_manager.player_count, run_manager.dirty_money, run_manager.current_room_index + 1, run_manager.RUN_SEQUENCE.size(), run_manager.get_current_room_type(), run_manager.get_alive_enemy_count(), run_manager.get_alive_boss_count(), run_manager.get_completed_room_count(), completed]
	)
	room_title.text = "SALA %02d // %s" % [run_manager.current_room_index + 1, run_manager.get_current_room_type().to_upper()]
	end_overlay.visible = run_manager.run_is_completed or run_manager.run_is_lost
	if run_manager.run_is_lost:
		end_title.text = "RUN PERDIDA"
	elif run_manager.run_is_completed:
		end_title.text = "RUN CONCLUÍDA"
	if end_overlay.visible:
		gameplay_hud.visible = false
		end_restart.grab_focus()


func _build_run_summary(completed: bool = true) -> String:
	var route_parts: PackedStringArray = []
	for stage: Dictionary in run_manager.stage_history:
		route_parts.append(String(stage.get("exit_id", "?")).to_upper())
	var route_text := " → ".join(route_parts) if not route_parts.is_empty() else "DIRETA"
	var summary: PackedStringArray = [
		"RUN CONCLUÍDA" if completed else "RUN PERDIDA",
		"TEMPO: %s // DIFICULDADE: %s" % [run_manager.format_run_time(float(run_manager.last_run_results.get("elapsed_time", run_manager.run_elapsed_time))), run_manager.get_difficulty_label()],
		"DINHEIRO OBTIDO: $%d // RESTANTE: $%d" % [run_manager.total_money_earned, run_manager.dirty_money],
		"STAGES: %d/6 // ROTA: %s" % [mini(run_manager.stage_index + 1, 6), route_text],
	]
	for player in get_parent().get_players():
		var weapons := "%s / %s" % [WeaponCatalog.get_display_name(player.equipped_weapons[0]), WeaponCatalog.get_display_name(player.equipped_weapons[1]) if not player.equipped_weapons[1].is_empty() else "VAZIO"]
		summary.append("%s — INT %d // SAÚDE %d // FORÇA %d\nARMAS: %s" % [String(player.participant_id).replace("player_", "P"), player.intellect, player.health_attribute, player.strength, weapons])
	return "\n".join(summary)
