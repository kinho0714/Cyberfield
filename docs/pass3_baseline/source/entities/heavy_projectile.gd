class_name HeavyProjectile
extends "res://entities/ranged_projectile.gd"


func _init() -> void:
	projectile_type = "heavy"
	speed = 300.0
	damage = CombatStats.HEAVY_PROJECTILE_BASE_DAMAGE
	maximum_lifetime = 4.0
