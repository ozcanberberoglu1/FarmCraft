shader_type spatial;
// Photo-textured animal hair cards (manes, tails, feathers): alpha tested, two-sided.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/animal_photo.gdshaderinc"

uniform float alpha_cut = 0.4;

void fragment() {
	vec3 albedo;
	float alpha;
	float rough;
	float metal;
	shade(UV, albedo, alpha, rough, metal);
	ALBEDO = albedo;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA_ANTIALIASING_EDGE = 0.2;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = specular;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	// Light shining through thin hair.
	BACKLIGHT = albedo * 0.35;
}
