// The stones ringing a campfire (CampfireModel): a photo-scanned rock's maps, blackened
// with soot on the faces turned to the fire and low down where the flames lick, soil
// splashed up their feet. The fire's centre is the instance's custom data (the ring is
// a MultiMesh), or the mesh's own origin when drawn whole (the item, the preview).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// ARM (R ambient occlusion, G roughness) or, when `arm` is off, a grey roughness map.
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool arm = true;
uniform vec3 tint : source_color = vec3(0.8);
uniform float soot_amount : hint_range(0.0, 1.0) = 0.85;
// Takes the scans' warm cast down towards plain field-stone grey.
uniform float desaturate : hint_range(0.0, 1.0) = 0.45;

varying vec3 v_wpos;
varying vec3 v_wnormal;
varying vec3 v_center;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_center = INSTANCE_CUSTOM.w > 0.5 ? INSTANCE_CUSTOM.xyz : MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb * tint;
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), desaturate);
	vec3 rm = texture(rough_tex, UV).rgb;
	float rough = rm.g;
	vec3 wn = normalize(v_wnormal);
	vec3 rel = v_wpos - v_center;
	float n = vnoise3(v_wpos * 13.0) * 0.6 + vnoise3(v_wpos * 31.0) * 0.4;
	// Soot: on what faces the fire, thickest low down and on the rim the flames reach.
	vec2 inward = -normalize(rel.xz + vec2(1e-4));
	float facing = smoothstep(-0.15, 0.7, dot(normalize(wn.xz + vec2(1e-4)), inward) * length(wn.xz) + wn.y * 0.25);
	float low = 1.0 - smoothstep(0.04, 0.3, rel.y);
	float soot = clamp(facing * (0.45 + low * 0.7) + (n - 0.5) * 0.45, 0.0, 1.0) * soot_amount;
	vec3 soot_col = srgb(vec3(0.075, 0.068, 0.062)) * (0.7 + n * 0.6);
	col = mix(col, soot_col, soot);
	rough = mix(rough, 0.95, soot);
	// Soil splashed up the feet of the stones.
	float foot = 1.0 - smoothstep(0.0, 0.06, rel.y + 0.02 + (n - 0.5) * 0.04);
	col = mix(col, col * srgb(vec3(0.6, 0.52, 0.42)), foot * 0.6);
	float snow = clamp((wn.y - 0.45) * 4.0, 0.0, 1.0) * snow_amount * (1.0 - soot);
	col = mix(col, snow_color(), snow);
	ALBEDO = col * (1.0 - wetness * 0.3);
	ROUGHNESS = clamp(rough, 0.05, 1.0) * mix(1.0, 0.55, wetness * (1.0 - snow));
	if (arm) {
		AO = rm.r;
		AO_LIGHT_AFFECT = 0.2;
	}
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	SPECULAR = 0.4;
}
