extends SceneTree
## Run after import using --headless --path . --script and this resource path.
## Frame anchors of every playable character: the horizontal correction mirrors with the
## sprite (AnimatedSprite2D mirrors the texture inside its rect but not `offset`; measured
## in Godot 4.7.2), and idle/walk keep the torso within 1.5 texture px of the collision
## centre in both facings, so the body neither drifts in the loop nor jumps on turning.

const PLAYER_SCENE := preload("res://entities/player.tscn")
const PARTICIPANTS := [&"player_1", &"player_2", &"player_3", &"player_4"]
const MEASURED_STATES: Array[StringName] = [&"idle", &"walk"]
const ANCHORED_STATES: Array[StringName] = [&"idle", &"walk", &"air", &"downed", &"revive", &"attack", &"dash", &"ground_slam", &"hurt"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var checked := 0
	for participant: StringName in PARTICIPANTS:
		var player: CharacterBody2D = PLAYER_SCENE.instantiate()
		player.set("participant_id", participant)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(player)
		var visual: AnimatedSprite2D = player.get_node("PlayerCharacterVisual")
		visual._ensure_character(participant)
		for state: StringName in ANCHORED_STATES:
			for frame_index in visual.sprite_frames.get_frame_count(state):
				visual.animation = state
				visual.frame = frame_index
				var offsets: Array[float] = []
				for flipped in [false, true]:
					visual.flip_h = flipped
					visual._apply_frame_alignment(state)
					offsets.append(visual.offset.x)
				# The correction mirrors with the sprite, so turning never shifts the body.
				assert(is_equal_approx(offsets[0], -offsets[1]), "%s %s %d not mirrored" % [participant, state, frame_index])
				if MEASURED_STATES.has(state):
					var torso := _torso_centre(visual.sprite_frames.get_frame_texture(state, frame_index).get_image())
					for side in 2:
						var centre := (torso if side == 0 else -torso) + (offsets[0] if side == 0 else offsets[1])
						assert(absf(centre) <= 1.5, "%s %s frame %d side %d torso at %.1f" % [participant, state, frame_index, side, centre])
				checked += 1
		player.free()
	print("PLAYER_FRAME_ANCHOR_SMOKE_TEST_OK checked=%d" % checked)
	quit()


## Torso centre (middle band of the opaque silhouette), in texture pixels from the cell
## centre, before flip and offset.
func _torso_centre(image: Image) -> float:
	var used := image.get_used_rect()
	var total := 0.0
	var count := 0
	for y in range(used.position.y + int(used.size.y * 0.3), used.position.y + int(used.size.y * 0.7)):
		for x in range(used.position.x, used.end.x):
			if image.get_pixel(x, y).a > 0.5:
				total += x
				count += 1
	return total / maxf(count, 1.0) + 0.5 - image.get_width() * 0.5
