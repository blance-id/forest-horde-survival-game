// Additive particles (sparks, flashes, glows) — bright enough to bloom.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/fx_particle.gdshaderinc"
