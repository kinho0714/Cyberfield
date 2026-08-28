extends Area2D

@onready var prompt: Label = $Prompt


func _process(_delta: float) -> void:
	var nearby := false
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and not bool(body.get("is_downed")):
			nearby = true
			break
	prompt.visible = nearby


func interact(interactor: Node2D = null) -> void:
	if interactor == null or not overlaps_body(interactor):
		return
	var lan := get_tree().get_first_node_in_group("lan_session") as LanSession
	var participant_id := StringName(interactor.get("participant_id"))
	if lan != null and lan.is_host() and participant_id != lan.get_local_participant_id():
		lan.open_meta_terminal_for(participant_id)
		return
	var ui := get_tree().get_first_node_in_group("meta_lab_ui") as MetaLabUI
	if ui != null:
		ui.open_terminal(interactor)
