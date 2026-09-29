// Photo-scanned ferns and weeds: leaf cards cut out by their alpha map, lit on both
// sides (see shaders/include/nature_scan.gdshaderinc).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#define FOLIAGE
#include "res://shaders/include/nature_scan.gdshaderinc"
