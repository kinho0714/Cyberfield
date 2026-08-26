extends Area2D

@export_enum("challenge", "paid") var chest_type := "challenge"
@export var chest_id: StringName = &"attribute_chest"
@export var cost := 50
var room_id: StringName
var feedback := ""

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label

func _ready() -> void:
	var manager := get_tree().get_first_node_in_group("run_manager")
	if manager:
		room_id = manager.get_current_room_id()
		manager.state_changed.connect(_refresh)
	_refresh()

func interact(player: Node2D = null) -> void:
	if player == null or player.is_downed:
		return
	var manager := get_tree().get_first_node_in_group("run_manager")
	if manager == null or manager.has_chest_choice(room_id, chest_id, player.participant_id):
		return
	if chest_type == "challenge":
		if not manager.room_states[room_id].custom_state.get("challenge_activated", false):
			var room_manager := get_tree().get_first_node_in_group("room_manager")
			manager.activate_challenge(room_id, room_manager.current_room)
			return
		if not manager.is_challenge_completed(room_id):
			return
	else:
		if not manager.room_states[room_id].completed:
			feedback = "LIMPE A SALA PRIMEIRO"
			_refresh()
			return
		if not manager.try_pay_chest(room_id, chest_id, cost):
			feedback = "NECESSÁRIO $%d // ATUAL $%d" % [cost, manager.dirty_money]
			_refresh()
			return
	var choice_ui := get_tree().get_first_node_in_group("attribute_choice_ui")
	if choice_ui:
		choice_ui.open_for(self, player, manager.get_chest_options(chest_id, chest_type == "challenge"))

func apply_choice(player: Node, attribute: StringName) -> bool:
	var manager := get_tree().get_first_node_in_group("run_manager")
	if manager == null or player.is_downed:
		return false
	if not manager.record_chest_choice(room_id, chest_id, player.participant_id, attribute):
		return false
	player.add_attribute(attribute)
	_refresh()
	return true

func _refresh() -> void:
	if not is_node_ready():
		return
	var manager := get_tree().get_first_node_in_group("run_manager")
	if manager == null or not manager.room_states.has(room_id):
		return
	if chest_type == "challenge":
		var state: Dictionary = manager.room_states[room_id].custom_state
		if not state.get("challenge_activated", false):
			label.text = "[E] ATIVAR DESAFIO OPCIONAL"
			visual.color = Color(0.9, 0.55, 0.12)
		elif not state.get("challenge_completed", false):
			label.text = "BAÚ BLOQUEADO // DERROTE A HORDA"
			visual.color = Color(0.35, 0.35, 0.35)
		else:
			label.text = "[E] ESCOLHER ATRIBUTO"
			visual.color = Color(0.2, 0.9, 0.45)
	else:
		label.text = feedback if not feedback.is_empty() else "[E] BAÚ DE ATRIBUTO // $%d" % cost
		visual.color = Color(0.2, 0.7, 1.0) if manager.room_states[room_id].completed else Color(0.3, 0.3, 0.3)
