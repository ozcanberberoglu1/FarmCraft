// Vehicle glass in the rain: vehicle_glass.gdshader with raindrops that bead up, run
// down and show the view behind turned over in each of them, cleared by the wipers
// (see include/vehicle_glass.gdshaderinc; swapped in by VehicleWipers only while the
// panes are wet: it reads the screen behind the glass).
shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#define GLASS_RAIN
#include "res://shaders/include/vehicle_glass.gdshaderinc"
