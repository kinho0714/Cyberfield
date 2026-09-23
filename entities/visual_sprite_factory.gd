class_name VisualSpriteFactory
extends RefCounted


static func build_sprite_frames(definitions: Dictionary) -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	for animation_value: Variant in definitions:
		var animation_name := StringName(animation_value)
		var definition := definitions[animation_value] as Dictionary
		add_sheet_animation(
			result,
			animation_name,
			definition.get("texture") as Texture2D,
			int(definition.get("frames", 1)),
			float(definition.get("fps", 8.0)),
			bool(definition.get("loop", true))
		)
	return result


static func add_sheet_animation(frames: SpriteFrames, animation_name: StringName, texture: Texture2D, frame_count: int, fps: float, loops: bool) -> void:
	if texture == null or frame_count <= 0:
		return
	var texture_width := texture.get_width()
	if texture_width % frame_count != 0:
		push_error("Visual sheet %s width %d is not divisible by %d frames" % [texture.resource_path, texture_width, frame_count])
		return
	var cell_width := texture_width / frame_count
	var cell_height := texture.get_height()
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for frame_index in frame_count:
		var atlas_frame := AtlasTexture.new()
		atlas_frame.atlas = texture
		atlas_frame.region = Rect2(frame_index * cell_width, 0, cell_width, cell_height)
		frames.add_frame(animation_name, atlas_frame)
