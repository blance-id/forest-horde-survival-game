// The bubble a SHIELD weapon holds up, drawn on a hemisphere so it reads as a
// wall around the hero rather than one more glowing circle on the grass — a
// ground disc is invisible the moment the horde stands on it.
//
// Most of the read is fresnel: the shell is nearly clear looking straight
// through it and bright at the silhouette, which is what makes it feel like
// glass instead of a dome-shaped light. Only the near face is drawn — an
// additive shell rendered twice doubles its brightness and bleaches whatever
// is standing inside it.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded, shadows_disabled;

global uniform float game_time;
uniform vec4 color : source_color = vec4(0.5, 0.9, 1.0, 1.0);
// Flashes to 1 each time the dome shoves the horde back.
uniform float pulse = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	// Faceted panels drifting round the shell, so it looks like it is holding.
	float band = 0.5 + 0.5 * sin(atan(local_pos.z, local_pos.x) * 10.0 + game_time * 0.7);
	// A brighter skirt where the dome meets the ground marks its footprint.
	float skirt = smoothstep(0.5, 0.0, local_pos.y) * 0.10;
	float a = fres * (0.26 + 0.18 * band + pulse * 0.6) + skirt + pulse * 0.08;
	ALBEDO = color.rgb * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
