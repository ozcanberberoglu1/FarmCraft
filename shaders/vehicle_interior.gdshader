// Vehicle cab interior from the model's interior atlas (colour; roughness / metal in
// g / b). The atlas marks most of the dash and door cards as metal: here they are
// moulded plastic and vinyl with a little shine left, while the smooth metal texels
// (the rear-view mirror's glass, chrome stems and trim) stay mirrors. Plastic, vinyl
// and headliner cloth are never glossier than `min_rough` and carry a faint mottle; at
// full detail (High / Ultra) also a moulded grain a few millimetres across, faded out
// where it would shimmer. The body moves, so it stays out of SDFGI and the cab would
// get the open sky's bounce light as if it had no roof: `cab_ambient` is how much of
// it the windows let in.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/noise.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
// Metal left on the plastic and vinyl.
uniform float plastic_metal = 0.15;
uniform float min_rough = 0.6;
// Grain relief in metres.
uniform float grain_depth = 0.00025;
uniform float cab_ambient = 0.4;
// 1: full detail; 0 (Low / Medium quality): no grain relief.
uniform float detail = 1.0;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 orm = texture(orm_tex, UV).rgb;
	float mirror = 1.0 - smoothstep(0.14, 0.2, orm.g);
	float mottle = vnoise3(v_local * 14.0);
	vec3 g = v_local * 260.0;
	float grain = vnoise3(g) * 0.65 + vnoise3(g * 2.1 + 7.3) * 0.35;
	ALBEDO = texture(albedo_tex, UV).rgb * tint.rgb * mix(0.93 + 0.12 * mottle, 1.0, mirror);
	ROUGHNESS = mix(clamp(max(orm.g, min_rough) + 0.1 * (grain - 0.5) + 0.06 * (mottle - 0.5), 0.0, 1.0), orm.g, mirror);
	METALLIC = orm.b * mix(plastic_metal, 1.0, mirror);
	if (detail > 0.5) {
		// Bump from the grain's screen-space slope (surface gradient), none on mirrors
		// and none where a grain cell is smaller than a couple of pixels.
		float fade = (1.0 - mirror) * (1.0 - smoothstep(0.25, 0.6, length(fwidth(g * 2.1))));
		float h = grain * grain_depth * fade;
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);
	}
	AO = cab_ambient;
	AO_LIGHT_AFFECT = 0.0;
	SPECULAR = 0.5;
}
