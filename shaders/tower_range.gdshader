// Faint ground ring showing a nest's reach. Deliberately quiet: it is on
// screen for the whole run, so it reads as a marking on the grass rather than
// a UI element. `active` brightens it while the tower is actually firing.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

global uniform float game_time;
uniform vec4 color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float active = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	// A thin edge plus a barely-there fill, so it never fights the world.
	float edge = smoothstep(0.88, 0.97, r) * (1.0 - smoothstep(0.97, 1.03, r));
	float fill = (1.0 - smoothstep(0.2, 1.0, r)) * 0.035;
	// While firing, a slow sweep runs round the rim.
	float sweep = 0.5 + 0.5 * sin(atan(p.y, p.x) * 3.0 - game_time * 2.5);
	float a = edge * (0.34 + 0.40 * active * sweep) + fill * (1.0 + active);
	ALBEDO = color.rgb * a;
	ALPHA = clamp(a, 0.0, 1.0) * float(r < 1.02);
}
