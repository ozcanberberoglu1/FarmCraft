// A bending fish's thin fins (see fish.gdshader): opaque and drawn from both sides.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/fish.gdshaderinc"
