// Wild berries on their bushes and in the hand (BerryModels): the colour is in the
// vertices (ripe, and a few still unripe); a glossy skin with light shining through
// it, the blueberry's waxy bloom (a pale, dull film rubbed off in places), darker and
// glossier when wet. On the bush they sway with the leaves (the same wind as
// nature_scan_foliage, from the same origin and height).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform float roughness : hint_range(0.0, 1.0) = 0.3;
// The blueberry's bloom (0 none .. 1 a full dusty film).
uniform float bloom : hint_range(0.0, 1.0) = 0.0;
// Sway at 1 m above the ground (m), growing with height; 0 in the hand.
uniform float sway = 0.05;
uniform float translucency : hint_range(0.0, 1.0) = 0.5;
// New berries after picking are hard and green (BerryBush); 1 = as coloured.
instance uniform float ripeness : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_local;
varying vec3 v_wnormal;

void vertex() {
	v_local = VERTEX;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float gust = 0.6 + 0.4 * sin(TIME * 0.4 + phase * 0.2);
	float h = max(VERTEX.y, 0.0);
	VERTEX.xz += vec2(sin(TIME * 1.7 + phase), cos(TIME * 1.3 + phase * 1.3)) * sway * wind_strength * gust * h * h;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = mix(srgb(vec3(0.52, 0.6, 0.3)), COLOR.rgb, ripeness);
	// A little mottling through the skin.
	float n = vnoise3(v_local * 260.0);
	col *= 0.9 + 0.2 * n;
	float rough = roughness;
	if (bloom > 0.0 && ripeness > 0.5) {
		// Dusty blue-white film, rubbed thin in patches.
		float film = bloom * smoothstep(0.25, 0.75, vnoise3(v_local * 90.0 + 3.1) * 0.8 + 0.3);
		col = mix(col, col * 0.7 + srgb(vec3(0.4, 0.43, 0.52)) * 0.35, film);
		rough = mix(rough, 0.78, film);
	}
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	ALBEDO = col * (1.0 - wetness * 0.25);
	ROUGHNESS = clamp(rough * mix(1.0, 0.45, wetness), 0.05, 1.0);
	SPECULAR = 0.55;
	// Light glows through thin, juicy skins (reds more than the dark ones).
	BACKLIGHT = col * translucency * (0.4 + lum);
	RIM = 0.15;
	RIM_TINT = 0.6;
}
