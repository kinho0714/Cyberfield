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

var run_manager: Node


func _ready() -> void:
	run_manager = get_parent().get_node("RunManager")
	run_manager.state_changed.connect(_refresh)
	restart_button.pressed.connect(run_manager.restart_run)
	$Panel/Margin/VBox/BackToMenu.pressed.connect(get_parent().return_to_main_menu)
	end_restart.pressed.connect(run_manager.restart_run)
	back_to_mode.pressed.connect(get_parent().return_to_main_menu)
	back_to_mode.text = "VOLTAR AO MENU"
	get_parent().coop_waiting_changed.connect(func(value: bool) -> void: waiting_label.visible = value)
	_refresh()


func _process(_delta: float) -> void:
	var downed_player: Node = null
	for player in get_tree().get_nodes_in_group("player"):
		if player.is_downed:
			downed_player = player
			break
	revive_panel.visible = downed_player != null and run_manager.run_active
	if downed_player:
		revive_progress.value = downed_player.revive_progress / downed_player.revive_duration * 100.0
	var lines: PackedStringArray = []
	var players := get_tree().get_nodes_in_group("player")
	players.sort_custom(func(a: Node, b: Node) -> bool: return String(a.participant_id) < String(b.participant_id))
	for player in players:
		if not player.visible:
			continue
		var label := "CAÍDO" if player.is_downed else "NORMAL"
		var potion_segments := "■".repeat(player.heal_doses) + "□".repeat(player.max_heal_doses - player.heal_doses)
		var healing := " // CURA %d%%" % int(player.heal_progress / player.heal_duration * 100.0) if player.is_healing else ""
		lines.append("%s HP: %d/%d // %s" % [String(player.participant_id).replace("player_", "P"), player.health, player.max_health, label])
		lines.append("Poção: %s%s" % [potion_segments, healing])
		lines.append("INT %d // SAÚDE %d // FORÇA %d // COMBO %d" % [player.intellect, player.health_attribute, player.strength, player.total_combo_hits])
		if player.input_profile == "p2":
			var connected := Input.get_connected_joypads().has(player.joypad_device_id)
			lines.append("P2 CONTROLE: %s // ID %d" % ["CONECTADO" if connected else "DESCONECTADO", player.joypad_device_id])
	players_status.text = "\n".join(lines)


func _refresh() -> void:
	var status := "ATIVA" if run_manager.run_active else "INATIVA"
	var completed := "\nRUN CONCLUÍDA" if run_manager.run_is_completed else ""
	var mode_label := "Co-op" if run_manager.is_coop() else "Solo"
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
		end_restart.grab_focus()
