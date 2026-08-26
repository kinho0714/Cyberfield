extends CanvasLayer

@onready var panel: PanelContainer = $Panel
var enemies_paused := false


func _ready() -> void:
	visible = OS.is_debug_build()
	panel.visible = false
	$Panel/Margin/VBox/DamageP1.pressed.connect(func() -> void: _call_player(&"player_1", "take_damage", [1]))
	$Panel/Margin/VBox/DamageP2.pressed.connect(func() -> void: _call_player(&"player_2", "take_damage", [1]))
	$Panel/Margin/VBox/DownP1.pressed.connect(func() -> void: _call_player(&"player_1", "enter_downed"))
	$Panel/Margin/VBox/DownP2.pressed.connect(func() -> void: _call_player(&"player_2", "enter_downed"))
	$Panel/Margin/VBox/TeleportP2.pressed.connect(_teleport_p2)
	$Panel/Margin/VBox/PauseEnemies.pressed.connect(_toggle_enemies)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()


func _player(id: StringName) -> Node:
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate.participant_id == id:
			return candidate
	return null


func _call_player(id: StringName, method: StringName, args: Array = []) -> void:
	var candidate := _player(id)
	if candidate:
		candidate.callv(method, args)


func _teleport_p2() -> void:
	var p1 := _player(&"player_1")
	var p2 := _player(&"player_2")
	if p1 and p2:
		p2.global_position = p1.global_position + Vector2(28, 0)


func _toggle_enemies() -> void:
	enemies_paused = not enemies_paused
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(not enemies_paused)
	$Panel/Margin/VBox/PauseEnemies.text = "Reativar inimigos" if enemies_paused else "Pausar inimigos"
