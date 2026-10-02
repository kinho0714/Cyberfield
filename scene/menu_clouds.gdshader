shader_type canvas_item;
render_mode unshaded;
uniform float scroll = 0.0;
uniform bool localized = false;
uniform float event_x = 0.5;
// Local contrast preserves the silhouette/alpha instead of making the whole layer opaque.
uniform float definition : hint_range(1.0, 2.0) = 1.0;
uniform float density_curve : hint_range(1.0, 2.0) = 1.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
float weight(float x) {
	return smoothstep(0.0, 0.15, x) * (1.0 - smoothstep(0.85, 1.0, x));
}
void fragment() {
	// Two overlapping phases: the non-seam sample covers each texture boundary.
	float u = fract(UV.x - scroll);
	float v = fract(u + 0.5);
	float a = weight(u);
	float b = weight(v);
	vec4 c = texture(TEXTURE, vec2(u, UV.y));
	vec4 d = texture(TEXTURE, vec2(v, UV.y));
	// Mix premultiplied samples to avoid halos at transparent cloud edges.
	float alpha = (c.a * a + d.a * b) / (a + b);
	vec3 rgb = (c.rgb * c.a * a + d.rgb * d.a * b) / max(c.a * a + d.a * b, 0.00001);
	float luminance = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	rgb *= clamp(1.0 + (luminance - 0.22) * (definition - 1.0), 0.7, 1.3);
	// Thin wisps recede; dense masses remain. No threshold edge or extra sample.
	alpha *= mix(1.0 / density_curve, density_curve, smoothstep(0.10, 0.42, alpha));
	COLOR = vec4(rgb, alpha) * tint;
	if (localized) {
		COLOR.a *= 1.0 - smoothstep(0.08, 0.42, abs(UV.x - event_x));
	}
}
