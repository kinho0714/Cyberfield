extends Node
## Read-only economy adapter + empty extensible cargo model. No extraction/save rules.
## Future collectors must own authority/replication before populating participant cargo.
var _cargo: Dictionary = {}
signal cargo_changed


func replace_participant_cargo(participant_id: StringName, items: Array[Dictionary]) -> void:
	# No producer is wired yet. Future host-side collectors supply actual item IDs.
	var lan := get_tree().get_first_node_in_group("lan_session")
	if lan != null and lan.is_client():
		return
	var accepted: Array[Dictionary] = []
	for item: Dictionary in items:
		var id := StringName(item.get("id", ""))
		var quantity := int(item.get("quantity", 0))
		if id.is_empty() or quantity <= 0:
			continue
		accepted.append({"id": id, "quantity": quantity,
			"name_key": String(item.get("name_key", id))})
	_cargo[participant_id] = accepted
	cargo_changed.emit()


func _ready() -> void:
	get_parent().state_changed.connect(_on_run_state_changed)


func snapshot(participant_id: StringName) -> Dictionary:
	var run := get_parent()
	return {"team_dirty_money": maxi(int(run.dirty_money), 0),
		"items": (_cargo.get(participant_id, []) as Array).duplicate(true)}


func _on_run_state_changed() -> void:
	var run := get_parent()
	if run.run_state in [run.RunState.MENU, run.RunState.HUB, run.RunState.PREPARING]:
		_cargo.clear()
		cargo_changed.emit()
