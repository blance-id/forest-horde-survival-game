// Real grass blades, as a field that follows the hero.
//
// A 90-unit map cannot afford dense grass everywhere, and it does not need to:
// the camera only ever sees a patch around the hero. So the MultiMesh is a
// fixed grid covering `patch` units, and this shader *wraps* each instance
// around the hero — a tuft that falls off the back edge reappears at the
// front. The field is therefore infinite, always dense where you are looking,
// and costs a fixed number of instances no matter how big the map gets.
//
// Everything else here follows from that: colour and height are hashed from
// the wrapped world position (not the instance index) so a tuft does not
// change identity when it wraps, and blades shrink to nothing at the patch rim
// and past the arena edge so nothing pops into view.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords, specular_disabled;

global uniform float game_time;

uniform vec2 hero = vec2(0.0);
uniform float patch = 26.0;
uniform vec4 color_a : source_color = vec4(0.33, 0.48, 0.20, 1.0);
uniform vec4 color_b : source_color = vec4(0.22, 0.36, 0.14, 1.0);
uniform vec4 dry_color : source_color = vec4(0.52, 0.50, 0.24, 1.0);
uniform float height_scale = 1.0;
uniform float wind = 1.0;
// Matches ArenaBounds.Shape: 0 square, 1 circle, 2 clover.
uniform int arena_shape = 1;
uniform float arena_half = 46.0;

varying vec3 blade_color;
varying float tip;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 local = VERTEX - origin;
	// Wrap this tuft into the patch centred on the hero.
	float half_patch = patch * 0.5;
	vec2 rel = origin.xz - hero;
	rel = mod(rel + vec2(half_patch), vec2(patch)) - vec2(half_patch);
	vec2 world = hero + rel;

	// `tip` is 0 at the root and 1 at the blade tip; only the tip moves.
	tip = clamp(local.y, 0.0, 1.0);

	float r = hash12(floor(world * 3.0));
	float r2 = hash12(floor(world * 3.0) + 17.0);
	// Fade out at the patch rim and past the arena edge, so nothing pops in
	// and no grass grows where the player cannot walk.
	float edge = 1.0 - smoothstep(half_patch * 0.82, half_patch * 0.99, length(rel));
	float outside = 1.0 - smoothstep(-1.0, 2.0, length(world) - arena_radius(world));
	float h = height_scale * (0.6 + 0.8 * r) * edge * outside;

	// Wind: a travelling wave, so the field ripples rather than shivering.
	float gust = sin(game_time * 1.6 + world.x * 0.35 + world.y * 0.22)
		+ 0.4 * sin(game_time * 3.1 + world.x * 0.9);
	vec2 sway = vec2(gust, gust * 0.4) * 0.14 * wind * tip * tip;

	vec3 p = vec3(world.x, 0.0, world.y) + local * vec3(1.0, h, 1.0);
	p.xz += sway;
	VERTEX = p;

	// Colour from the world position, so a tuft keeps its shade as it wraps.
	vec3 base = mix(color_a.rgb, color_b.rgb, r2);
	// A few patches burn dry, matching the worn trails in the ground shader.
	base = mix(base, dry_color.rgb, smoothstep(0.72, 0.95, hash12(floor(world * 0.35))));
	// Darker at the root, brighter at the tip: the cheapest possible AO.
	blade_color = base * (0.82 + 0.32 * tip);
	// Blades are thin, double-sided and vertical, so their own normals make
	// them go black whenever the sun is off to the side. Facing them all
	// straight up lights them exactly like the ground they grow out of, which
	// is what makes the field read as turf instead of dark spikes.
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = blade_color;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
