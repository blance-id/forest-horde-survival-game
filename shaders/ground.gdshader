// Two-tone grass in world space with a dark band outside the playable square.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec4 color_a : source_color = vec4(0.36, 0.55, 0.28, 1.0);
uniform vec4 color_b : source_color = vec4(0.30, 0.48, 0.24, 1.0);
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float patch_size = 6.0;
uniform float arena_half = 22.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise, world_pos.xz / patch_size).r;
	float n2 = texture(noise, world_pos.xz / (patch_size * 0.23) + 0.5).r;
	// Broad soft patches plus a faint fine grain so the plain never looks flat.
	float mixv = smoothstep(0.35, 0.65, n);
	vec3 col = mix(color_a.rgb, color_b.rgb, mixv);
	col *= 0.96 + 0.08 * n2;
	// Fade to a darker tone past the arena edge so the boundary reads.
	float edge = max(abs(world_pos.x), abs(world_pos.z)) - arena_half;
	float outside = smoothstep(0.0, 1.5, edge);
	col = mix(col, col * 0.55, outside);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
