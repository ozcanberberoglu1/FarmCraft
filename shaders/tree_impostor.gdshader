// Distant forest: camera-facing pictures of the photo trees from eight sides
// (see shaders/include/tree_impostor.gdshaderinc), lit with their normal maps; autumn,
// falling leaves, snow and rain follow the same world globals as the near trees.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"
#include "res://shaders/include/tree_impostor.gdshaderinc"

void vertex() {
	// VERTEX is already in world space; rebuilt from the card corner (UV).
	IMPOSTOR_VERTEX;
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
	ROUGHNESS = mix(0.78, 0.4, wetness);
	SPECULAR = 0.2;
	BACKLIGHT = back;
}
