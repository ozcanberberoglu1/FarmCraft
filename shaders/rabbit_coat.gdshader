shader_type spatial;
// The wild rabbit's skin (RabbitRig): the painted coat under its shell fur (the
// instance's coat_shade darkens it a little where fur covers it, and varies rabbits),
// darker and glossier in the rain.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float roughness = 0.9;
global uniform float wetness;
instance uniform float coat_shade : instance_index(0) = 1.0;
instance uniform float skin_shade : instance_index(1) = 1.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * coat_shade * skin_shade;
	c *= 1.0 - 0.3 * wetness;
	ALBEDO = c;
	ROUGHNESS = mix(roughness, 0.45, wetness);
	SPECULAR = 0.3;
	BACKLIGHT = c * 0.12;
}
