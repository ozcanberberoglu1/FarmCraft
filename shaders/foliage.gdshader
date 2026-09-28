// Leaves and needles: wind sway (vertex alpha = sway weight), autumn tint, snow,
// and soft back-lighting. Renders both sides.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform float sway_amount = 0.09;
uniform float autumn_factor : hint_range(0.0, 1.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.78;
uniform float translucency : hint_range(0.0, 1.0) = 0.35;

varying vec3 v_wpos;
varying vec3 v_wnormal;
varying float v_rand;

void vertex() {
	// VERTEX and NORMAL are already in world space, so the wind offset is added as is.
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 wp = VERTEX;
	float sway = COLOR.a;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float t = TIME;
	vec3 offs = vec3(sin(t * 1.1 + phase), 0.0, cos(t * 0.87 + phase * 1.3)) * 0.8;
	offs += 0.3 * vec3(sin(t * 3.3 + wp.x * 1.7 + wp.y), 0.0, sin(t * 3.9 + wp.z * 1.9 + wp.y));
	offs *= sway * sway_amount * wind_strength;
	VERTEX += offs;
	v_wpos = wp;
	v_wnormal = normalize(NORMAL);
	v_rand = hash12(origin.xz * 0.731);
}

void fragment() {
	vec3 col = COLOR.rgb;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 autumn = mix(srgb(vec3(0.86, 0.36, 0.08)), srgb(vec3(0.96, 0.72, 0.16)), v_rand);
	col = mix(col, autumn * (0.55 + lum * 2.6), autumn_amount * autumn_factor);
	float up = FRONT_FACING ? v_wnormal.y : -v_wnormal.y;
	float snow = clamp((up - 0.25) * 3.0, 0.0, 1.0) * snow_amount;
	col = mix(col, snow_color(), snow);
	ALBEDO = col * (1.0 - wetness * 0.15);
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
	BACKLIGHT = col * translucency;
}
