class_name WeaponDefinition
extends Resource

enum WeaponType { MELEE, RANGED }
enum Rarity { COMMON, UNCOMMON, RARE }

@export var weapon_id: StringName
@export var display_name := "ARMA"
@export var weapon_type := WeaponType.MELEE
@export var base_damage := 40
@export var cooldown := 0.2
@export var scaling_attribute: StringName = &"strength"
@export var attack_range := 30.0
@export var knockback := 1.0
@export var projectile_scene: PackedScene
@export var rarity := Rarity.COMMON
