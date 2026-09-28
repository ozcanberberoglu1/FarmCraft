// Generic vertex-colored surface with subtle world-space noise so large flat faces
// don't look plastic. Receives snow on upward faces when outdoors.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.0;
uniform float specular_val : hint_range(0.0, 1.0) = 0.35;
uniform float noise_strength = 0.08;
uniform vec3 noise_scale = vec3(1.5);
uniform float snow_accumulates : hint_range(0.0, 1.0) = 1.0;
uniform float emission_strength = 0.0;

varying vec3 v_wpos;
varying vec3 v_wnormal;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = v_wpos * noise_scale;
	float n = vnoise3(p) * 0.65 + vnoise3(p * 3.7) * 0.35;
	vec3 col = COLOR.rgb * (1.0 + (n - 0.5) * 2.0 * noise_strength);
	// Snow is 0 without snow cover or on materials that never take it: skip its noise.
	float snow = 0.0;
	if (snow_amount > 0.0 && snow_accumulates > 0.0) {
		snow = clamp((v_wnormal.y - 0.55) * 4.0, 0.0, 1.0) * snow_amount * snow_accumulates;
		snow *= smoothstep(0.35, 0.55, vnoise3(v_wpos * 2.0) + snow_amount * 0.3);
	}
	col = mix(col, snow_color(), snow);
	float wet = wetness * snow_accumulates;
	ALBEDO = col * (1.0 - wet * 0.25);
	ROUGHNESS = mix(roughness, 0.35, wet * 0.6) * (1.0 - snow * 0.2);
	METALLIC = metallic_val;
	SPECULAR = specular_val;
	EMISSION = COLOR.rgb * emission_strength;
}
