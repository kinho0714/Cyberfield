extends SceneTree
## Character presentation audit in the REAL player scene (entities/player.tscn):
## every animation frame of every playable character, drawn with the gameplay collision
## capsule and the floor line, at the in-game scale. Presentation only; gameplay off.
## Run (needs a display, e.g. xvfb-run):
##   godot --path . --script res://tests/character_lineup_capture.gd -- <out_dir>
## Writes <out_dir>/lineup_<character>.png and prints CHARACTER_LINEUP lines with the
## lowest opaque row of every frame relative to the capsule bottom (0 = feet on floor).

const PLAYER_SCENE := preload("res://entities/player.tscn")
const PARTICIPANTS := {&"jhon": &"player_1", &"jackson": &"player_2", &"kai": &"player_3", &"spark": &"player_4"}
const CELL := Vector2(132.0, 150.0)
const ORDER: Array[StringName] = [&"idle", &"walk", &"air", &"dash", &"attack", &"ground_slam",
	&"hurt", &"downed", &"revive", &"wall_slide", &"wall_climb"]

var out_dir := "user://character_lineup"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(int(CELL.x * 6.0) + 120, int(CELL.y * ORDER.size()) + 20)
	RenderingServer.set_default_clear_color(Color(0.16, 0.13, 0.22))
	for character: StringName in PARTICIPANTS:
		var board := Node2D.new()
		root.add_child(board)
		var missing: Array[String] = []
		for row in ORDER.size():
			var state: StringName = ORDER[row]
			var label := Label.new()
			label.text = String(state)
			label.position = Vector2(4.0, CELL.y * row + 4.0)
			board.add_child(label)
			var frames := _frame_count(character, state)
			if frames == 0:
				missing.append(String(state))
			for column in frames:
				var origin := Vector2(120.0 + CELL.x * column + CELL.x * 0.5, CELL.y * row + 112.0)
				var player: CharacterBody2D = PLAYER_SCENE.instantiate()
				player.set("participant_id", PARTICIPANTS[character])
				player.process_mode = Node.PROCESS_MODE_DISABLED
				player.position = origin
				board.add_child(player)
				var visual: AnimatedSprite2D = player.get_node("PlayerCharacterVisual")
				visual._ensure_character(PARTICIPANTS[character])
				visual.visible = true
				player.get_node("TempPixelVisual").visible = false
				player.get_node("AnimatedSprite2D").visible = false
				visual.animation = state
				visual.frame = column
				visual._apply_frame_alignment(state)
				_draw_guides(board, origin, player)
				print("CHARACTER_LINEUP %s %s %d feet=%s" % [character, state, column, _feet_gap(visual, player)])
		if not missing.is_empty():
			print("CHARACTER_LINEUP_MISSING %s %s" % [character, missing])
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("lineup_%s.png" % character))
		board.queue_free()
		await process_frame
	print("CHARACTER_LINEUP_OK")
	quit()


func _frame_count(character: StringName, state: StringName) -> int:
	var probe: CharacterBody2D = PLAYER_SCENE.instantiate()
	var visual: AnimatedSprite2D = probe.get_node("PlayerCharacterVisual")
	probe.set("participant_id", PARTICIPANTS[character])
	probe.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(probe)
	visual._ensure_character(PARTICIPANTS[character])
	var count := visual.sprite_frames.get_frame_count(state) if visual.sprite_frames.has_animation(state) else 0
	probe.free()
	return count


func _draw_guides(board: Node2D, origin: Vector2, player: CharacterBody2D) -> void:
	var capsule := (player.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	var outline := Line2D.new()
	outline.width = 1.0
	outline.default_color = Color(0.2, 1.0, 0.5, 0.8)
	var half := capsule.height * 0.5
	outline.points = PackedVector2Array([Vector2(-capsule.radius, -half), Vector2(capsule.radius, -half),
		Vector2(capsule.radius, half), Vector2(-capsule.radius, half), Vector2(-capsule.radius, -half)])
	outline.position = origin
	board.add_child(outline)
	var floor_line := Line2D.new()
	floor_line.width = 1.0
	floor_line.default_color = Color(1.0, 0.75, 0.2, 0.6)
	floor_line.points = PackedVector2Array([Vector2(-CELL.x * 0.45, half), Vector2(CELL.x * 0.45, half)])
	floor_line.position = origin
	board.add_child(floor_line)


func _feet_gap(visual: AnimatedSprite2D, player: CharacterBody2D) -> float:
	# Lowest opaque texel of the current frame, in player space, minus the capsule bottom.
	var texture := visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
	var image := texture.get_image()
	var lowest := -1
	for y in range(image.get_height() - 1, -1, -1):
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				lowest = y
				break
		if lowest >= 0:
			break
	var capsule := (player.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	var local_y := (float(lowest) + 1.0 - image.get_height() * 0.5 + visual.offset.y) * visual.scale.y + visual.position.y
	return snappedf(local_y - capsule.height * 0.5, 0.1)
