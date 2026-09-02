// Horde enemy shader. A whole enemy type is one MultiMesh; every vertex knows
// which body part it belongs to (CUSTOM0.w) and where that part pivots
// (CUSTOM0.xyz, torso pivot in CUSTOM1.xyz), so walking, hit reactions and
// deaths are computed here instead of with per-enemy nodes or skinning.
//
// Part ids: 1 leg-left, 2 leg-right, 3 torso, 4 arm-left, 5 arm-right, 6 head.
// INSTANCE_CUSTOM: x = gait phase, y = gait speed factor (0 = standing),
//                  z = last hit time, w = death time (< 0 while alive).
shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

global uniform float game_time;

uniform sampler2D colormap : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform float stride_rate = 2.2;
uniform float leg_swing = 0.6;
uniform float arm_forward = 1.5;
uniform float arm_down = 0.0;
uniform float arm_swing = 0.2;
uniform float bob = 0.03;
uniform float lean = 0.14;
uniform float hit_flash_time = 0.12;
uniform float death_fall_time = 0.45;
uniform float death_sink_delay = 0.9;
uniform float death_sink_time = 0.6;

varying float flash;

mat3 rot_x(float a) {
	float c = cos(a), s = sin(a);
	return mat3(vec3(1, 0, 0), vec3(0, c, s), vec3(0, -s, c));
}

mat3 rot_y(float a) {
	float c = cos(a), s = sin(a);
	return mat3(vec3(c, 0, -s), vec3(0, 1, 0), vec3(s, 0, c));
}

mat3 rot_z(float a) {
	float c = cos(a), s = sin(a);
	return mat3(vec3(c, s, 0), vec3(-s, c, 0), vec3(0, 0, 1));
}

void vertex() {
	int part = int(CUSTOM0.w + 0.5);
	vec3 pivot = CUSTOM0.xyz;
	vec3 torso_pivot = CUSTOM1.xyz;
	float phase = INSTANCE_CUSTOM.x;
	float gait = INSTANCE_CUSTOM.y;
	float since_hit = game_time - INSTANCE_CUSTOM.z;
	float death = INSTANCE_CUSTOM.w;

	float t = (game_time * stride_rate * max(gait, 0.15) + phase) * TAU;
	float swing = sin(t) * gait;
	float breathe = sin(t * 0.5 + phase) * (1.0 - gait);

	vec3 p = VERTEX;
	vec3 n = NORMAL;
	mat3 r = mat3(1.0);

	if (part == 1) {
		r = rot_x(swing * leg_swing);
	} else if (part == 2) {
		r = rot_x(-swing * leg_swing);
	} else if (part == 4) {
		r = rot_x(-swing * arm_swing + breathe * 0.05) * rot_y(-arm_forward) * rot_z(-arm_down);
	} else if (part == 5) {
		r = rot_x(swing * arm_swing + breathe * 0.05) * rot_y(arm_forward) * rot_z(arm_down);
	} else if (part == 6) {
		r = rot_y(sin(t * 0.5) * 0.12 * gait) * rot_x(-0.1 * gait);
	}
	p = pivot + r * (p - pivot);
	n = r * n;

	// Torso carries arms and head: lean forward while moving, twist with the stride.
	if (part >= 3) {
		mat3 rt = rot_x(lean * gait + breathe * 0.02) * rot_y(swing * 0.08);
		p = torso_pivot + rt * (p - torso_pivot);
		n = rt * n;
	}
	p.y += abs(sin(t)) * bob * gait;

	// Hit: quick squash-and-stretch pop.
	if (since_hit >= 0.0 && since_hit < hit_flash_time) {
		float k = 1.0 - since_hit / hit_flash_time;
		p.xz *= 1.0 + 0.18 * k;
		p.y *= 1.0 - 0.12 * k;
		flash = k;
	} else {
		flash = 0.0;
	}

	// Death: topple backwards from the feet, then sink into the ground.
	if (death >= 0.0) {
		float since = game_time - death;
		float fall = smoothstep(0.0, 1.0, clamp(since / death_fall_time, 0.0, 1.0));
		mat3 rf = rot_x(-1.45 * fall);
		p = rf * p;
		n = rf * n;
		float sink = clamp((since - death_sink_delay) / death_sink_time, 0.0, 1.0);
		p.y -= sink * 0.6;
		flash = max(flash, (1.0 - fall) * 0.6);
	}

	VERTEX = p;
	NORMAL = n;
}

void fragment() {
	vec3 albedo = texture(colormap, UV).rgb * tint.rgb;
	ALBEDO = mix(albedo, vec3(1.0, 0.95, 0.9), flash);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
