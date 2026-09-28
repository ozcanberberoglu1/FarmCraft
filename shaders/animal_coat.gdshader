// Realistic animal coats for the sculpted skinned models.
// kind: 0 short fur, 1 wool, 2 feathers, 3 keratin (hooves, beak), 4 bare skin.
// Channels: COLOR rgb base / a pattern mask, UV x colour zone (points) / y fixed colour,
// UV2 x gloss / y fur, CUSTOM0 xyz rest position (patterns stay put while animating),
// w adult-only features (chicks show feathers there instead of a comb).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/animal_instance.gdshaderinc"
#include "res://shaders/include/nature.gdshaderinc"

uniform int kind = 0;

varying vec3 v_rest;
varying vec3 v_rest_n;
varying float v_adult;

void vertex() {
	v_rest = CUSTOM0.xyz;
	v_adult = CUSTOM0.w;
	v_rest_n = NORMAL;
	if (kind == 1) {
		// Shorn sheep: the fleece sinks toward the body.
		VERTEX -= NORMAL * (1.0 - wool_amount) * 0.075;
	}
}

float wool_h(vec3 p) {
	return vnoise3(p) * 0.55 + vnoise3(p * 2.3 + 1.7) * 0.3 + vnoise3(p * 5.1 + 4.2) * 0.15;
}

void fragment() {
	float points = UV.x;
	float fixed_col = UV.y;
	float gloss = UV2.x;
	float fur = UV2.y;
	vec3 tint = mix(coat_tint, points_tint, clamp(points, 0.0, 1.0));
	if (baby > 0.5 && kind == 2) {
		tint = baby_tint;
	}
	vec3 base = mix(COLOR.rgb * tint, COLOR.rgb, clamp(fixed_col, 0.0, 1.0));
	if (baby > 0.5 && v_adult > 0.5) {
		base = baby_tint;
	}
	vec3 p = v_rest;
	float rough = 0.78;
	float spec = 0.3;
	vec3 n_pert = vec3(0.0);

	if (patches > 0.5 && COLOR.a > 0.01) {
		vec3 q = p * 2.2 + vec3(pattern_seed * 13.1, pattern_seed * 7.7, pattern_seed * 3.3);
		float n = vnoise3(q) * 0.55 + vnoise3(q * 2.1) * 0.3 + vnoise3(q * 4.7) * 0.15;
		float edge = vnoise3(p * 40.0) * 0.03;
		float spots = smoothstep(0.505, 0.525, n + edge) * COLOR.a;
		base = mix(base, patch_color, spots);
	}

	if (kind == 0) {
		// Short hair: fine streaks along the body plus soft sheen.
		float s1 = vnoise3(p * vec3(420.0, 420.0, 70.0));
		float s2 = vnoise3(p * vec3(160.0, 60.0, 160.0));
		float streak = mix(s1, s2, clamp(abs(v_rest_n.y) * 0.0 + 0.3, 0.0, 1.0));
		base *= 1.0 + (streak - 0.5) * 0.22 * fur;
		base *= 0.92 + 0.16 * vnoise3(p * 6.0);
		rough = mix(0.62, 0.86, fur);
		n_pert = vec3(vnoise3(p * 300.0) - 0.5, 0.0, vnoise3(p * 300.0 + 9.1) - 0.5) * 0.35 * fur;
	} else if (kind == 1) {
		// Wool: curly locks with dark crevices.
		vec3 q = p * 55.0 + pattern_seed;
		float e = 0.12;
		float h = wool_h(q);
		vec3 grad = vec3(wool_h(q + vec3(e, 0, 0)) - h, wool_h(q + vec3(0, e, 0)) - h, wool_h(q + vec3(0, 0, e)) - h) / e;
		n_pert = -grad * 0.28;
		base *= 0.66 + 0.46 * h;
		base *= 0.93 + 0.1 * vnoise3(p * 7.0);
		rough = 0.96;
		spec = 0.2;
	} else if (kind == 2) {
		// Feathers: overlapping rows with lighter edges.
		float rows = fract(p.z * 45.0 + p.y * 18.0 + vnoise3(p * 60.0) * 0.8);
		float edge = smoothstep(0.55, 0.95, rows);
		base *= 0.86 + 0.2 * edge + (vnoise3(p * vec3(500.0, 200.0, 120.0)) - 0.5) * 0.12;
		rough = 0.66;
		spec = 0.35;
		n_pert = vec3(0.0, edge - 0.5, 0.0) * 0.2;
	} else if (kind == 3) {
		// Hooves and beaks: smooth keratin with growth lines.
		base *= 0.9 + 0.12 * vnoise3(vec3(p.x * 30.0, p.y * 400.0, p.z * 30.0));
		rough = mix(0.5, 0.25, gloss);
		spec = 0.5;
	} else {
		// Bare skin (muzzle, udder, comb): soft and slightly moist.
		base *= 0.92 + 0.12 * vnoise3(p * 120.0);
		rough = mix(0.6, 0.3, gloss);
		spec = 0.45;
	}

	if (length(n_pert) > 0.0) {
		vec3 wn = (VIEW_MATRIX * MODEL_MATRIX * vec4(n_pert, 0.0)).xyz;
		NORMAL = normalize(NORMAL + wn);
	}
	float wet_k = wet * (kind == 3 ? 0.3 : 1.0);
	base *= 1.0 - wet_k * 0.3;
	ALBEDO = base;
	ROUGHNESS = mix(rough, rough * 0.7, wet_k);
	SPECULAR = mix(spec, 0.45, wet_k);
	if (kind <= 2) {
		RIM = 0.32 * (1.0 - wet_k * 0.6);
		RIM_TINT = 0.7;
		BACKLIGHT = base * 0.06;
	}
}
