// The wall of mist standing on the edge of the map.
//
// The ground shader already darkens past the boundary, but darker grass still
// looks like grass you could walk on. This is an actual curtain following the
// arena's shape: clear at the ground so props at the rim still read, thick
// above so the world visibly stops. Two drifting noise layers keep it from
// looking like a cylinder.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

global uniform float game_time;
uniform vec4 color : source_color = vec4(0.55, 0.67, 0.68, 1.0);
uniform float density = 0.92;

varying vec3 world_pos;
varying float rise;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// UV.y is 0 at the base of the curtain and 1 at the top.
	rise = UV.y;
}

void fragment() {
	// Thin at ankle height so the tree line is not cut off, solid above.
	float body = smoothstep(0.05, 0.75, rise);
	// Slow horizontal drift at two scales: mist, not a painted band.
	float drift = 0.5 + 0.5 * sin(world_pos.x * 0.12 + world_pos.z * 0.09 + game_time * 0.25);
	float curl = 0.5 + 0.5 * sin(world_pos.x * 0.31 - world_pos.z * 0.27 - game_time * 0.4);
	float a = body * density * (0.72 + 0.2 * drift + 0.12 * curl);
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
