// Alpha-blended particles (smoke, dirt, ground splats).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/fx_particle.gdshaderinc"
