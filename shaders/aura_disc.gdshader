// Glowing ring on the ground for AURA weapons. Unit quad (2x2) scaled by the
// weapon system to the damage radius; `pulse` flashes the disc on each tick.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

global uniform float game_time;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float pulse = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = smoothstep(0.86, 0.96, r) * (1.0 - smoothstep(0.96, 1.0, r));
	float fill = (1.0 - smoothstep(0.0, 1.0, r)) * 0.12;
	float rays = 0.5 + 0.5 * sin(atan(p.y, p.x) * 8.0 + game_time * 2.0);
	float a = ring * (0.55 + 0.25 * rays) + fill + pulse * (1.0 - r) * 0.6;
	ALBEDO = color.rgb * a;
	ALPHA = clamp(a, 0.0, 1.0) * float(r < 1.0);
}
