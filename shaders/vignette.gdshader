// Screen-edge tint drawn over the HUD: `strength` is animated by the HUD for
// damage flashes and the low-health pulse. Aspect-corrected so the ring stays
// round in portrait.
shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.7, 0.04, 0.05, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float inner : hint_range(0.0, 1.5) = 0.75;
uniform float outer : hint_range(0.0, 2.0) = 1.45;

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 1.35);
	float r = length(d) * 2.0;
	float a = smoothstep(inner, outer, r) * strength;
	COLOR = vec4(color.rgb, color.a * a);
}
