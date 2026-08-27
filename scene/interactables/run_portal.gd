extends Area2D

@onready var prompt: Label = $Prompt

var _used := false


func _process(_delta: float) -> void:
	_refresh_prompt()


func interact(interactor: Node2D = null) -> void:
	if _used:
		return
	var manager := get_tree().get_first_node_in_group("room_manager")
	if manager == null or manager.is_transitioning:
		return
	if not manager.can_start_run_from_hub(self, interactor):
		_refresh_prompt()
		return
	_used = true
	manager.request_start_run_from_hub(self, interactor)


func _refresh_prompt() -> void:
	var manager := get_tree().get_first_node_in_group("room_manager")
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if manager == null or run_manager == null:
		prompt.visible = true
		prompt.text = "PORTAL DA RUN"
		return
	var p1_ready := false
	var p2_ready := false
	for player in manager.get_players():
		var player_body := player as CharacterBody2D
		if player_body == null:
			continue
		var ready: bool = not bool(player_body.get("is_downed")) and overlaps_body(player_body)
		if StringName(player_body.get("participant_id")) == &"player_2":
			p2_ready = ready
		else:
			p1_ready = ready
	prompt.visible = p1_ready or p2_ready
	if not run_manager.is_coop():
		prompt.text = "PORTAL DA RUN\n[USAR] INICIAR RUN"
		return
	prompt.text = "PORTAL DA RUN\nP1: %s  //  P2: %s\n[USAR] INICIAR" % [
		"PRONTO" if p1_ready else "AGUARDANDO",
		"PRONTO" if p2_ready else "AGUARDANDO",
	]
