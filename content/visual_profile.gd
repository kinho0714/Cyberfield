class_name ContentVisualProfile
extends Resource
## Presentation only. Never supplies collision, damage, AI or network identity.
@export var profile_id: StringName
@export_file("*.tres", "*.res") var sprite_frames_path := ""
@export var asset_paths: Dictionary = {}
@export var animation_offsets: Dictionary = {}


func asset(slot: String, fallback: Resource = null) -> Resource:
	var path := String(asset_paths.get(slot, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return fallback
	var resource := load(path)
	if resource == null:
		return fallback
	return resource


func texture(slot: String, fallback: Texture2D = null) -> Texture2D:
	var result := asset(slot, fallback) as Texture2D
	return result if result != null and result.get_width() > 0 and result.get_height() > 0 else fallback


func merge_frames(fallback: SpriteFrames) -> SpriteFrames:
	if sprite_frames_path.is_empty() or not ResourceLoader.exists(sprite_frames_path):
		return fallback
	var supplied := load(sprite_frames_path) as SpriteFrames
	if supplied == null:
		return fallback
	var result := fallback.duplicate() as SpriteFrames
	for state in fallback.get_animation_names():
		# Existing visual state machines index air/dash/etc by fixed frame counts.
		# Partial packages fall back per animation; never mutate shared resources.
		if not supplied.has_animation(state) or supplied.get_frame_count(state) != fallback.get_frame_count(state):
			continue
		var valid := supplied.get_frame_count(state) > 0
		for index in supplied.get_frame_count(state):
			var frame_texture := supplied.get_frame_texture(state, index)
			valid = valid and frame_texture != null
			if frame_texture != null:
				valid = valid and frame_texture.get_width() > 0 and frame_texture.get_height() > 0
		if not valid:
			continue
		result.clear(state)
		# Keep current presentation timing and loops, including death/telegraphs.
		for index in supplied.get_frame_count(state):
			result.add_frame(state, supplied.get_frame_texture(state, index), fallback.get_frame_duration(state, index))
	return result


func alignment(state: StringName, fallback: Vector2) -> Vector2:
	var value: Variant = animation_offsets.get(String(state))
	return value if value is Vector2 else fallback
