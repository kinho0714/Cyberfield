extends Area2D

const CHEST_TEXTURE := preload("res://assets/props/chests/loot_chest.png")

@export var loot_id: StringName
@export var amount := 20
## P1-B: arma guardada no baú (definida na geração pela WeaponLootTable; vazio = só loot).
@export var reward_weapon_id: StringName = &""
@export var reward_rarity: StringName = &""

var _collected := false

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group("biome_loot")
	collision_mask = 1
	visual.visible = false
	var sprite := Sprite2D.new()
	sprite.name = "TemporaryChestVisual"
	sprite.texture = CHEST_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE  # original chest art, drawn at final size
	sprite.position = Vector2(0.0, -3.0)
	add_child(sprite)
	var label := get_node_or_null("Label") as Label
	if label == null:
		return
	label.visible = false
	body_entered.connect(func(body: Node) -> void: if body.is_in_group("player"): label.visible = true)
	body_exited.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			label.visible = get_overlapping_bodies().any(func(candidate: Node) -> bool: return candidate != body and candidate.is_in_group("player")))


func interact(_interactor: Node2D = null) -> void:
	if _collected:
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager == null or not run_manager.collect_biome_loot(loot_id, amount):
		return
	_collected = true
	_play_audio_event(&"loot_open")
	release_contents()
	queue_free()


## Solta a arma do baú como pickup real. Também chamado no cliente LAN quando o snapshot
## do host marca o baú como coletado (mesma arma/id: decisão determinística da geração).
func release_contents() -> WeaponPickup:
	return spawn_weapon_reward(self, reward_weapon_id, reward_rarity, StringName("%s_weapon" % loot_id))


static func spawn_weapon_reward(source: Node2D, weapon_id: StringName, rarity: StringName, pickup_id: StringName) -> WeaponPickup:
	if weapon_id.is_empty() or source == null or source.get_parent() == null or not WeaponCatalog.has_weapon(weapon_id):
		return null
	var tree := source.get_tree()
	var run_manager := tree.get_first_node_in_group("run_manager") if tree != null else null
	if run_manager != null and run_manager.get_current_map_state().collected_weapon_ids.has(pickup_id):
		return null
	for existing in tree.get_nodes_in_group("weapon_pickup"):
		if StringName(existing.pickup_id) == pickup_id:
			return existing
	var pickup := WeaponPickup.new()
	pickup.pickup_id = pickup_id
	pickup.weapon_id = weapon_id
	pickup.rarity = rarity
	var parent_2d := source.get_parent() as Node2D
	pickup.position = parent_2d.to_local(source.global_position) if parent_2d != null else source.global_position
	source.get_parent().add_child(pickup)
	return pickup


func _play_audio_event(event_id: StringName) -> void:
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_event"):
		audio.play_event(event_id)
