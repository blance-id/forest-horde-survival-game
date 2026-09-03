// Grass that never visibly repeats, built from a few octaves of one tiling
// noise texture sampled at unrelated scales and offsets. The goal is real
// ground rather than painted mud: broad colour drift you only notice across
// the whole map, a mid mottle, and — the part that actually sells it — fine
// blades that lie in a direction which itself wanders, so the eye reads texture
// instead of static. Dirt is rare and low-contrast: worn trails, not blobs.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec4 color_a : source_color = vec4(0.36, 0.55, 0.28, 1.0);
uniform vec4 color_b : source_color = vec4(0.30, 0.48, 0.24, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.5, 0.36, 0.22, 1.0);
uniform sampler2D noise : filter_linear, repeat_enable;
uniform sampler2D soft_noise : filter_linear, repeat_enable;
uniform float patch_size = 6.0;
uniform float arena_half = 22.0;
// Matches ArenaBounds.Shape: 0 square, 1 circle, 2 clover.
uniform int arena_shape = 1;
uniform vec4 fog_tint : source_color = vec4(0.55, 0.67, 0.68, 1.0);
// 0 = flat colour, 1 = full blade detail. Dropped by the low quality setting.
uniform float detail = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float arena_radius(vec2 p) {
	if (arena_shape == 1) {
		return arena_half;
	}
	if (arena_shape == 2) {
		return arena_half * (0.66 + 0.34 * abs(cos(2.0 * atan(p.y, p.x))));
	}
	vec2 a = abs(normalize(p + vec2(1e-5)));
	return arena_half / max(0.0001, max(a.x, a.y));
}

void fragment() {
	vec2 p = world_pos.xz;

	// Three unrelated scales: broad tone, mid mottle, and a slow field that
	// decides which way the blades lie here.
	float macro = texture(soft_noise, p / (patch_size * 3.1) + vec2(0.13, 0.61)).r;
	float mid = texture(noise, p / patch_size).r;
	float flow = texture(soft_noise, p / (patch_size * 4.5) + vec2(0.77, 0.29)).r;

	vec3 col = mix(color_a.rgb, color_b.rgb, smoothstep(0.3, 0.7, mid));
	// Broad drift keeps a 90-unit map from reading as one flat tone.
	col *= 0.90 + 0.20 * macro;

	if (detail > 0.5) {
		// Blades: high-frequency noise squashed along a direction that rotates
		// with `flow`, so neighbouring patches comb differently and the tiling
		// of the source texture never lines up with itself.
		float ang = flow * 6.2831;
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 across = vec2(-dir.y, dir.x);
		vec2 blade_uv = vec2(dot(p, dir) * 0.18, dot(p, across) * 3.0) / patch_size * 6.5;
		float blades = texture(noise, blade_uv).r;
		float fine = texture(noise, p * 1.9 + vec2(0.41, 0.87)).r;
		col *= 0.90 + 0.19 * blades;
		col *= 0.94 + 0.12 * fine;
		// A touch of colour variation, not just brightness: real grass shifts
		// yellow where it is thin and blue-green where it is thick.
		col.r += (blades - 0.5) * 0.035;
		col.b -= (blades - 0.5) * 0.030;
	}

	// Worn trails: narrow bands where the slow field crosses a threshold,
	// with trampled grass either side rather than a hard edge.
	float trail = texture(soft_noise, p / (patch_size * 2.4) + vec2(0.37, 0.71)).r;
	float dirt = smoothstep(0.70, 0.78, trail) * 0.75;
	float rim = smoothstep(0.62, 0.70, trail) * (1.0 - dirt);
	vec3 dirt_col = dirt_color.rgb * (0.90 + 0.20 * mid);
	col = mix(col, col * 0.86, rim);
	col = mix(col, dirt_col, dirt);

	// Past the arena edge the ground both darkens and washes out towards the
	// fog, so the boundary reads even from directly above where the curtain
	// standing on it is edge-on and nearly invisible.
	float edge = length(p) - arena_radius(p);
	float outside = smoothstep(0.0, 3.0, edge);
	col = mix(col, mix(col * 0.42, fog_tint.rgb, 0.45), outside);

	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
