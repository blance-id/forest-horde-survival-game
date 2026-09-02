// Painted-looking ground in world space: two grass tones in soft patches,
// brush-stroke grain, sparse worn dirt spots with a trampled rim, and a dark
// band outside the playable square so the boundary reads.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec4 color_a : source_color = vec4(0.36, 0.55, 0.28, 1.0);
uniform vec4 color_b : source_color = vec4(0.30, 0.48, 0.24, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.5, 0.36, 0.22, 1.0);
uniform sampler2D noise : filter_linear, repeat_enable;
uniform sampler2D soft_noise : filter_linear, repeat_enable;
uniform float patch_size = 6.0;
uniform float arena_half = 22.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = texture(noise, p / patch_size).r;
	float n2 = texture(noise, p / (patch_size * 0.23) + 0.5).r;
	float n3 = texture(soft_noise, p / (patch_size * 2.0) + vec2(0.37, 0.71)).r;
	// Stretched fine noise reads as short grass strokes rather than static.
	float n4 = texture(noise, p * vec2(0.9, 0.25) / patch_size * 4.0).r;

	// Broad soft grass patches with a faint mid-scale mottle.
	vec3 col = mix(color_a.rgb, color_b.rgb, smoothstep(0.35, 0.65, n));
	col *= 0.95 + 0.10 * n2;
	col *= 0.94 + 0.12 * n4;

	// Sparse worn spots where the low-frequency noise peaks, ringed by
	// slightly darker trampled grass.
	float dirt = smoothstep(0.66, 0.72, n3) * 0.9;
	float rim = smoothstep(0.58, 0.66, n3) * (1.0 - dirt);
	vec3 dirt_col = dirt_color.rgb * (0.9 + 0.2 * n2) * (0.92 + 0.16 * n4);
	col = mix(col, col * 0.82, rim);
	col = mix(col, dirt_col, dirt);

	// Fade to a darker tone past the arena edge so the boundary reads.
	float edge = max(abs(p.x), abs(p.y)) - arena_half;
	float outside = smoothstep(0.0, 1.5, edge);
	col = mix(col, col * 0.55, outside);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
