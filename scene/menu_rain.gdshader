shader_type canvas_item;
render_mode unshaded;
varying vec4 particle_tint;
void vertex() {
	particle_tint = COLOR;
}
void fragment() {
	// Use the supplied drop unchanged. Only attenuate opacity, never erase the right.
	COLOR = texture(TEXTURE, UV) * particle_tint;
	COLOR.a *= mix(1.0, 0.55, smoothstep(0.38, 0.88, SCREEN_UV.x));
}
