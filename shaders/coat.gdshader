// Animal coats: short fur, Holstein patches, curly wool, feathers and long hair.
// Patterns are computed in the mesh's local space so they move with the animal.
// Vertex COLOR.rgb is the base color, COLOR.a masks where patterns may appear.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

// 0 short fur, 1 Holstein patches, 2 wool, 3 feathers, 4 long hair
// Curls per metre of the wool pattern (a sheep's coat; a hand-held fleece needs more).
uniform float curl_scale = 26.0;
uniform int pattern = 0;
uniform float fur_scale = 70.0;
uniform float fur_strength = 0.14;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.82;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.35;
instance uniform vec3 coat_tint : source_color = vec3(1.0);
instance uniform vec3 patch_color : source_color = vec3(0.07, 0.065, 0.06);
instance uniform float pattern_seed = 0.0;
instance uniform float wet = 0.0;
instance uniform float dirt = 0.0;

varying vec3 v_local;
varying vec3 v_local_n;

void vertex() {
	v_local = VERTEX;
	v_local_n = NORMAL;
}

float wool_height(vec3 p) {
	return vnoise3(p) * 0.6 + vnoise3(p * 2.1 + 3.7) * 0.3 + vnoise3(p * 4.3 + 7.1) * 0.1;
}

void fragment() {
	vec3 base = COLOR.rgb * coat_tint;
	float mask = COLOR.a;
	vec3 p = v_local;
	float fine = vnoise3(p * fur_scale) * 0.6 + vnoise3(p * fur_scale * 2.3 + 1.3) * 0.4;
	vec3 col = base * (1.0 + (fine - 0.5) * 2.0 * fur_strength);
	float rough = roughness_base;

	if (pattern == 1) {
		vec3 q = p * 2.4 + vec3(pattern_seed * 13.1, pattern_seed * 7.7, pattern_seed * 3.3);
		float n = vnoise3(q) * 0.55 + vnoise3(q * 2.2) * 0.3 + vnoise3(q * 5.1) * 0.15;
		float spots = smoothstep(0.5, 0.53, n) * mask;
		col = mix(col, patch_color * (1.0 + (fine - 0.5) * 0.3), spots);
	} else if (pattern == 2) {
		// Curly wool: bumpy normals and dark crevices.
		vec3 q = p * curl_scale + pattern_seed;
		float e = 0.08;
		float h = wool_height(q);
		vec3 grad = vec3(wool_height(q + vec3(e, 0.0, 0.0)) - h, wool_height(q + vec3(0.0, e, 0.0)) - h,
				wool_height(q + vec3(0.0, 0.0, e)) - h) / e;
		vec3 n_local = normalize(v_local_n - grad * 0.22 * mask);
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n_local, 0.0)).xyz);
		col *= mix(1.0, 0.62 + 0.5 * h, mask);
		rough = 0.95;
	} else if (pattern == 3) {
		// Overlapping feathers: stretched noise bands along the body.
		float f = vnoise3(p * vec3(30.0, 60.0, 20.0) + pattern_seed);
		float edge = smoothstep(0.2, 0.8, fract(p.z * 18.0 + p.y * 6.0 + f * 1.4));
		col *= mix(1.0, 0.9 + 0.14 * edge, mask);
		rough = 0.7;
	} else if (pattern == 4) {
		// Long hair strands along the mesh V direction.
		float s = vnoise2(vec2(UV.x * 90.0, UV.y * 3.0 + pattern_seed));
		col *= 0.7 + 0.5 * s;
		rough = 0.55;
	}

	col = mix(col, col * vec3(0.55, 0.45, 0.35), dirt * 0.6);
	col *= 1.0 - wet * 0.35;
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.35, wet);
	SPECULAR = mix(0.3, 0.6, wet);
	RIM = rim_amount * (1.0 - wet);
	RIM_TINT = 0.6;
	BACKLIGHT = col * 0.08;
}
