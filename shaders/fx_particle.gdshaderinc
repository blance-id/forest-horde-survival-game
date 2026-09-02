// Shared body of the GPU-animated particle quads (fx_particle_add /
// fx_particle_mix). FxManager writes each particle ONCE into a MultiMesh
// instance and the shader replays its whole life from `game_time`, so a
// thousand live particles cost no CPU per frame.
//
// Instance packing (FxManager must sit at the world origin):
//   transform origin = spawn position
//   basis.x          = velocity (world units / s)
//   basis.y          = (size_start, size_end, gravity)
//   basis.z          = (spin rad/s, drag, spawn_time)
//   INSTANCE_CUSTOM  = (fade_in fraction, lifetime, atlas frame, ground flag)
//   COLOR            = tint (HDR allowed, alpha = peak opacity)
// spawn_time lives in the 32-bit transform: the Compatibility renderer packs
// INSTANCE_CUSTOM as 16-bit floats, too coarse for a timestamp late in a run.

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform float game_time = 0.0;
// Atlas grid (columns, rows); (1,1) for a single image.
uniform vec2 frames = vec2(1.0, 1.0);

varying float v_alpha;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 vel = MODEL_MATRIX[0].xyz;
	vec3 sg = MODEL_MATRIX[1].xyz;
	vec3 sd = MODEL_MATRIX[2].xyz;
	float t = game_time - sd.z;
	float life = max(INSTANCE_CUSTOM.y, 0.001);
	float u = clamp(t / life, 0.0, 1.0);
	float alive = step(0.0, t) * step(t, life);

	// Motion: velocity with exponential drag, gravity, never under the ground.
	float k = sd.y;
	float travel = k > 0.001 ? (1.0 - exp(-k * t)) / k : t;
	vec3 p = origin + vel * travel;
	p.y -= 0.5 * sg.z * t * t;
	p.y = max(p.y, 0.03);

	float size = mix(sg.x, sg.y, u) * alive;
	float ang = sd.x * t;
	float c = cos(ang);
	float s = sin(ang);
	vec2 q = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c) * size;

	vec3 right;
	vec3 up;
	if (INSTANCE_CUSTOM.w > 0.5) {
		// Ground decal: flat on the floor.
		right = vec3(1.0, 0.0, 0.0);
		up = vec3(0.0, 0.0, -1.0);
	} else {
		right = INV_VIEW_MATRIX[0].xyz;
		up = INV_VIEW_MATRIX[1].xyz;
	}
	vec3 world = p + right * q.x + up * q.y;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;

	float fade_in = max(INSTANCE_CUSTOM.x, 0.001);
	v_alpha = smoothstep(0.0, fade_in, u) * (1.0 - smoothstep(0.55, 1.0, u)) * alive;

	// Atlas frame selection.
	float frame = INSTANCE_CUSTOM.z;
	vec2 cell = vec2(mod(frame, frames.x), floor(frame / frames.x));
	UV = (UV + cell) / frames;
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = COLOR.rgb * c.rgb;
	ALPHA = COLOR.a * c.a * v_alpha;
}
