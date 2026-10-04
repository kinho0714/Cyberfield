class_name ProjectileVisual
extends AnimatedSprite2D

@export_enum("ranged", "heavy") var projectile_type := "ranged"

const MOVEMENT_FPS := 16.0
const IMPACT_FPS := 18.0


func _ready() -> void:
	var path := "res://assets/enemies/%s/projectile/" % projectile_type
	var definitions := {
		&"movement": {
			"texture": load(path + "%s_projectile_movement_v1.png" % projectile_type) as Texture2D,
			"frames": 8, "fps": MOVEMENT_FPS, "loop": true,
		},
		&"impact": {
			"texture": load(path + "%s_projectile_impact_v1.png" % projectile_type) as Texture2D,
			"frames": 6, "fps": IMPACT_FPS, "loop": false,
		},
	}
	sprite_frames = VisualSpriteFactory.build_sprite_frames(definitions)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	play(&"movement")


func show_impact() -> void:
	play(&"impact")


func get_impact_duration() -> float:
	return 6.0 / IMPACT_FPS
