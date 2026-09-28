shader_type spatial;
// Photo-textured animal body (downloaded models): opaque, see the include.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/animal_photo.gdshaderinc"

void fragment() {
	vec3 albedo;
	float alpha;
	float rough;
	float metal;
	shade(UV, albedo, alpha, rough, metal);
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = specular;
	if (has_ao) {
		AO = texture(ao_tex, UV).r;
		AO_LIGHT_AFFECT = 0.3;
	}
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
}
