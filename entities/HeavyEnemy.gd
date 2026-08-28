class_name HeavyEnemy
extends "res://entities/Enemy.gd"


func _ready() -> void:
	enemy_role = EnemyRole.HEAVY
	var temporary_visual := get_node_or_null("TempPixelVisual") as TempPixelVisual
	if temporary_visual != null:
		temporary_visual.set_character_kind(&"heavy")
	super._ready()
