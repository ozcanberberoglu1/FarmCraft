shader_type spatial;
// Karamel's coat (DogRig, tools/blender/build_dog.py): the painted hair with its normal
// map, the roughness map's wet nose and glossy eyes, a little darker under the shell fur
// (skin_shade), darker and glossier in the rain.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float normal_strength = 0.7;
global uniform float wetness;
instance uniform float skin_shade : instance_index(0) = 1.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float rough = texture(orm_tex, UV).g;
	// The eyes and the nose are glossy anyway; the hair darkens and shines when wet.
	float hair = smoothstep(0.35, 0.6, rough);
	c *= mix(1.0, skin_shade * (1.0 - 0.3 * wetness), hair);
	ALBEDO = c;
	ROUGHNESS = mix(rough, min(rough, 0.45), wetness * hair);
	SPECULAR = mix(0.65, 0.3, hair);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	BACKLIGHT = c * 0.12 * hair;
}
