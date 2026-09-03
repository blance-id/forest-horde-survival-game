// The forest floor: one tiling grass texture that never looks tiled.
//
// The texture is greyscale, so each chapter tints it with its own palette. It
// is sampled twice — at two scales, one of them rotated — and cross-faded by a
// very slow noise field, so the repeat never lines up with itself. That is the
// whole trick: a single cheap texture reads as unique ground across a 90-unit
// map, with no geometry and no atlas.
//
// On top of that sit the things a tiled texture cannot do on its own: broad
// colour drift across the whole map, rare worn dirt trails, and the wash-out
// past the arena edge that tells the player where the world stops.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec4 color_a : source_color = vec4(0.36, 0.55, 0.28, 1.0);
uniform vec4 color_b : source_color = vec4(0.30, 0.48, 0.24, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.5, 0.36, 0.22, 1.0);
uniform vec4 fog_tint : source_color = vec4(0.55, 0.67, 0.68, 1.0);
uniform sampler2D grass_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform sampler2D soft_noise : filter_linear, repeat_enable;
// World units one tile of the grass texture covers.
uniform float grass_scale = 2.4;
uniform float patch_size = 6.0;
uniform float arena_half = 22.0;
// Matches ArenaBounds.Shape: 0 square, 1 circle, 2 clover.
uniform int arena_shape = 1;
// 0 = a single texture sample, 1 = the two-sample anti-tiling blend.
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

vec2 rotate(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void fragment() {
	vec2 p = world_pos.xz;

	// Grass detail. The second sample is rotated and at an unrelated scale, so
	// wherever the blend favours it the tiling grid is somewhere else entirely.
	float grass = texture(grass_tex, p / grass_scale).r;
	if (detail > 0.5) {
		float blend = texture(soft_noise, p * 0.011 + vec2(0.21, 0.83)).r;
		float grass_b = texture(grass_tex, rotate(p, 1.13) / (grass_scale * 1.73) + vec2(0.37, 0.61)).r;
		grass = mix(grass, grass_b, smoothstep(0.3, 0.7, blend));
	}

	// Broad tone across the map, so it is not one flat green.
	float macro = texture(soft_noise, p / (patch_size * 3.1) + vec2(0.13, 0.61)).r;
	float mid = texture(noise, p / patch_size).r;
	vec3 col = mix(color_a.rgb, color_b.rgb, smoothstep(0.3, 0.7, mid));
	col *= 0.90 + 0.20 * macro;
	// The texture itself, kept gentle — this is ground, not a pattern to read.
	col *= 0.80 + 0.42 * grass;
	// Real grass shifts yellow where it is thin and blue-green where it is thick.
	col.r += (grass - 0.5) * 0.05;
	col.b -= (grass - 0.5) * 0.035;

	// Worn trails: narrow bands where a slow field crosses a threshold, with
	// trampled grass either side rather than a hard edge.
	float trail = texture(soft_noise, p / (patch_size * 2.4) + vec2(0.37, 0.71)).r;
	float dirt = smoothstep(0.70, 0.78, trail) * 0.75;
	float rim = smoothstep(0.62, 0.70, trail) * (1.0 - dirt);
	vec3 dirt_col = dirt_color.rgb * (0.86 + 0.28 * grass);
	col = mix(col, col * 0.86, rim);
	col = mix(col, dirt_col, dirt);

	// Past the arena edge the ground darkens and washes towards the fog, so
	// the boundary reads even from straight above, where the mist curtain
	// standing on it is edge-on and nearly invisible.
	float edge = length(p) - arena_radius(p);
	col = mix(col, mix(col * 0.42, fog_tint.rgb, 0.45), smoothstep(0.0, 3.0, edge));

	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
