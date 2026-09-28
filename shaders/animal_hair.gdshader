// Hair and feather cards on the sculpted animals: alpha-tested strands with
// anisotropic highlights. Tinted by the instance hair colour (or the coat colour
// for feathers).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/animal_instance.gdshaderinc"

uniform sampler2D strands : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool use_coat_tint = false;
uniform float anisotropy = 0.6;
uniform float alpha_cut = 0.35;

void fragment() {
	vec4 t = texture(strands, UV);
	vec3 tint = use_coat_tint ? coat_tint : hair_tint;
	if (baby > 0.5 && use_coat_tint) {
		tint = baby_tint;
	}
	vec3 col = t.rgb * tint * COLOR.rgb;
	col *= 1.0 - wet * 0.3;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = col;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA_ANTIALIASING_EDGE = 0.25;
	ROUGHNESS = mix(0.5, 0.35, wet);
	SPECULAR = 0.4;
	ANISOTROPY = anisotropy;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	BACKLIGHT = col * 0.25;
}
