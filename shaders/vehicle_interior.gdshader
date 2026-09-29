// Vehicle cab interior from the model's interior atlas (colour; roughness / metal in
// g / b). The atlas marks most of the dash and door cards as metal: here they are
// moulded plastic and vinyl with a little shine left, while the smooth metal texels
// (the rear-view mirror's glass, chrome stems and trim) stay mirrors. The body moves,
// so it stays out of SDFGI and the cab would get the open sky's bounce light as if it
// had no roof: `cab_ambient` is how much of it the windows let in.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
// Metal left on the plastic and vinyl.
uniform float plastic_metal = 0.15;
uniform float cab_ambient = 0.4;

void fragment() {
	vec3 orm = texture(orm_tex, UV).rgb;
	ALBEDO = texture(albedo_tex, UV).rgb * tint.rgb;
	ROUGHNESS = orm.g;
	METALLIC = orm.b * mix(plastic_metal, 1.0, 1.0 - smoothstep(0.14, 0.2, orm.g));
	AO = cab_ambient;
	AO_LIGHT_AFFECT = 0.0;
	SPECULAR = 0.5;
}
