// Vehicle glass, dry: dusty panes with wiped arcs and a stone chip (see
// include/vehicle_glass.gdshaderinc). While rain water sits on a vehicle's panes
// VehicleWipers gives them vehicle_glass_wet.gdshader instead.
shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/vehicle_glass.gdshaderinc"
