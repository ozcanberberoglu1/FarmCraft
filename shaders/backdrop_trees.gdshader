// Hill forest past the map edge (scripts/world/backdrop.gd): the same tree pictures as
// the hill forest's far trees (shaders/tree_impostor.gdshader: same atlas, instance data
// and fragment, shaders/include/tree_impostor.gdshaderinc), drawn with the backdrop's
// depth squeeze so the ones beyond the far plane are never clipped.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;

#include "res://shaders/include/nature.gdshaderinc"
#include "res://shaders/include/backdrop.gdshaderinc"
#include "res://shaders/include/tree_impostor.gdshaderinc"

void vertex() {
	IMPOSTOR_VERTEX;
	POSITION = backdrop_position(VERTEX, VIEW_MATRIX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
}

void fragment() {
	vec3 albedo;
	vec3 n;
	float a;
	vec3 back;
	impostor_fragment(UV, VIEW_MATRIX, v_right, v_to_cam, v_card, v_broad, v_tint, albedo, n, a, back);
	NORMAL = n;
	ALBEDO = albedo;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA_ANTIALIASING_EDGE = 0.0;
	ROUGHNESS = mix(0.78, 0.56, wetness);
	SPECULAR = 0.2;
	BACKLIGHT = back;
}
