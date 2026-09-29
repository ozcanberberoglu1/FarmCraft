// Shared by the photo-scanned nature models (Poly Haven rocks, ferns, nettles, fallen
// wood; NatureModels.scan_material): the scan's albedo, normal and roughness (or ARM)
// maps, plus the world around it: soil splashed up and damp moss near the ground
// (vertex colour alpha = height above the ground / 4 m, baked by NatureModels), moss
// in patches on what faces up, snow on top, darker and glossier when wet.
// FOLIAGE (defined by nature_scan_foliage): cut out by `alpha_tex`, sways in the wind,
// browns in autumn and is buried under snow.

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// ARM (R ambient occlusion, G roughness) or, when `arm` is off, a grey roughness map.
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool arm = true;
uniform vec3 tint : source_color = vec3(1.0);
uniform float normal_strength = 1.0;
uniform float roughness_mult = 1.0;
uniform float moss_amount : hint_range(0.0, 1.0) = 0.0;
// How high (m) soil splashes up from the ground.
uniform float soil_height = 0.22;
// Forest-floor clutter shrinks away into the ground towards this distance (0 = off),
// just before its view range ends.
uniform float fade_end = 0.0;
#ifdef FOLIAGE
uniform sampler2D alpha_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float alpha_cut = 0.45;
// Sway at 1 m above the ground (m), growing with height.
uniform float sway = 0.05;
uniform float translucency : hint_range(0.0, 1.0) = 0.4;
#endif

varying vec3 v_wpos;
varying vec3 v_wnormal;
varying float v_ground;
varying float v_rand;

void vertex() {
	v_rand = hash12(MODEL_MATRIX[3].xz * 0.37);
	v_ground = COLOR.a * 4.0;
	if (fade_end > 0.0) {
		VERTEX *= 1.0 - smoothstep(fade_end * 0.8, fade_end, distance(MODEL_MATRIX[3].xyz, INV_VIEW_MATRIX[3].xyz));
	}
#ifdef FOLIAGE
	// Model space: the instance's turn only changes which way it sways.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float gust = 0.6 + 0.4 * sin(TIME * 0.4 + phase * 0.2);
	float h = max(VERTEX.y, 0.0);
	VERTEX.xz += vec2(sin(TIME * 1.7 + phase), cos(TIME * 1.3 + phase * 1.3)) * sway * wind_strength * gust * h * h;
#endif
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb * tint;
	vec3 rm = texture(rough_tex, UV).rgb;
	float rough = rm.g * roughness_mult;
	vec3 wn = normalize(v_wnormal);
#ifdef FOLIAGE
	ALPHA = texture(alpha_tex, UV).r;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA_ANTIALIASING_EDGE = 0.0;
	if (!FRONT_FACING) {
		wn = -wn;
	}
	// Autumn: browning and dying back; under snow only the tops show.
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 autumn = mix(srgb(vec3(0.55, 0.4, 0.18)), srgb(vec3(0.7, 0.52, 0.22)), v_rand);
	col = mix(col, autumn * (0.5 + lum * 2.0), autumn_amount * 0.8);
#endif
	float near_ground = 0.0;
	if (soil_height > 0.0) {
		near_ground = 1.0 - smoothstep(0.0, soil_height, v_ground + (vnoise3(v_wpos * 4.0) - 0.5) * 0.1);
	}
	// Soil splashed up the base, and damp moss just above it.
	col = mix(col, col * srgb(vec3(0.6, 0.52, 0.42)), near_ground * 0.75);
	if (moss_amount > 0.0) {
		// In damp patches on what faces up, and in a band close to the ground.
		float up = smoothstep(0.3, 0.85, wn.y + (vnoise3(v_wpos * 1.3) - 0.5) * 0.7);
		float patches = smoothstep(0.42, 0.7, vnoise3(v_wpos * 0.9) * 0.7 + vnoise3(v_wpos * 3.7) * 0.3);
		float damp = (1.0 - smoothstep(soil_height, soil_height + 0.35, v_ground)) * (1.0 - near_ground * 0.6);
		float moss = clamp(up * patches + damp * patches * 0.8, 0.0, 1.0) * moss_amount;
		col = mix(col, srgb(vec3(0.2, 0.25, 0.1)) * (0.7 + 0.5 * vnoise3(v_wpos * 9.0)), moss);
		rough = mix(rough, 1.0, moss);
	}
	float snow = clamp((wn.y - 0.45) * 4.0, 0.0, 1.0) * snow_amount;
#ifdef FOLIAGE
	snow = max(snow, snow_amount * 0.7);
#endif
	col = mix(col, snow_color(), snow);
	ALBEDO = col * (1.0 - wetness * 0.3);
	ROUGHNESS = clamp(rough, 0.05, 1.0) * mix(1.0, 0.55, wetness * (1.0 - snow));
	if (arm) {
		AO = rm.r;
		AO_LIGHT_AFFECT = 0.2;
	}
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	SPECULAR = 0.4;
#ifdef FOLIAGE
	BACKLIGHT = col * translucency;
#endif
}
