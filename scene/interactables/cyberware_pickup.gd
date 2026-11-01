class_name CyberwarePickup
extends Area2D
## Cyberware encontrado na run (drop de elite/pesado/chefe, raro em inimigos comuns).
## [USAR] instala na hora se o slot estiver livre ou se for melhor; de qualquer forma o
## implante entra na lista da run (extraído em vitória, vira sucata em derrota).

var pickup_id: StringName
var room_id: StringName
var instance: Dictionary = {}
var _claimed := false
var _label: Label
var _bob := 0.0
var _icon: Sprite2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("cyberware_pickup")
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 40)
	collision.shape = shape
	add_child(collision)
	var tint := RarityTable.color(StringName(instance.get("rarity", &"common")))
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(0, -26), Vector2(22, -4), Vector2(0, 18), Vector2(-22, -4)])
	glow.color = Color(tint, 0.22)
	add_child(glow)
	_icon = Sprite2D.new()
	_icon.texture = CyberwareCatalog.icon(StringName(instance.get("line", &"strength")))
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.scale = Vector2(1.25, 1.25)
	_icon.position = Vector2(0, -6)
	add_child(_icon)
	_label = Label.new()
	_label.position = Vector2(-120, -78)
	_label.size = Vector2(240, 48)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", tint)
	_label.add_theme_font_size_override("font_size", 14)
	_label.text = "%s  //  %s\n[USAR] INSTALAR" % [CyberwareCatalog.display_name(instance), RarityTable.label(StringName(instance.get("rarity", &"common")))]
	_label.visible = false
	add_child(_label)
	body_entered.connect(func(body: Node) -> void: if body.is_in_group("player"): _label.visible = true)
	body_exited.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			_label.visible = get_overlapping_bodies().any(func(candidate: Node) -> bool: return candidate != body and candidate.is_in_group("player")))


func _process(delta: float) -> void:
	_bob += delta
	var near := false
	for player in get_tree().get_nodes_in_group("player"):
		if player is Node2D and (player as Node2D).global_position.distance_to(global_position) < 80.0:
			near = true
	_label.visible = near
	if _icon != null:
		_icon.position.y = -6.0 + sin(_bob * 3.0) * 2.0


func interact(player: Node2D = null) -> void:
	if _claimed or player == null or bool(player.get("is_downed")):
		return
	var lan_session := get_tree().get_first_node_in_group("lan_session")
	if lan_session != null and lan_session.is_client():
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager == null or not run_manager.collect_cyberware_drop(room_id, pickup_id):
		return
	_claimed = true
	var installed: bool = player.add_run_cyberware(instance) if player.has_method("add_run_cyberware") else false
	run_manager.record_cyberware_found(instance)
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null:
		audio.play_event(&"loot_open")
	if installed:
		CombatFx.heal(player)
	_float_text(player, "IMPLANTE INSTALADO" if installed else "IMPLANTE GUARDADO")
	queue_free()


func _float_text(player: Node2D, text: String) -> void:
	var floating := Label.new()
	floating.text = text
	floating.add_theme_color_override("font_color", RarityTable.color(StringName(instance.get("rarity", &"common"))))
	floating.add_theme_font_size_override("font_size", 14)
	floating.z_index = 30
	player.get_parent().add_child(floating)
	floating.global_position = player.global_position + Vector2(-70, -96)
	var tween := floating.create_tween()
	tween.tween_property(floating, "global_position:y", floating.global_position.y - 30.0, 1.0)
	tween.parallel().tween_property(floating, "modulate:a", 0.0, 1.0)
	tween.tween_callback(floating.queue_free)
