// Farm pond water: murky, tea-and-algae coloured, clear enough in the shallows to show
// the mud below and dark where deep (depth from the depth buffer). A still surface with
// fine wind ripples (and rain rings when it rains) mirrors the sky at grazing angles
// through low roughness, and the shore, reeds and treeline through a short screen-space
// reflection march (ssr_steps, 0 = off); the edge fades out where the water meets the shore.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform vec3 shallow_color : source_color = vec3(0.26, 0.28, 0.18);
uniform vec3 deep_color : source_color = vec3(0.07, 0.095, 0.075);
uniform float depth_range = 1.1;
uniform float ripple_strength = 0.04;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// Reflection march steps (each one depth read); the ray reaches about 0.35 * 1.35^steps m.
uniform int ssr_steps = 16;

varying vec3 v_wpos;

float ripple(vec2 p, float t) {
	return vnoise2(p * 1.3 + vec2(t * 0.22, t * 0.08))
			+ vnoise2(p * 3.1 - vec2(t * 0.17, t * 0.29)) * 0.45
			+ vnoise2(p * 7.3 + vec2(t * 0.41, -t * 0.23)) * 0.18;
}

// Expanding rings of raindrops: one drop per 0.6 m cell, each at its own time.
float rain_rings(vec2 p, float t) {
	vec2 cell = floor(p / 0.6);
	vec2 local = p / 0.6 - cell;
	float h = hash12(cell);
	vec2 centre = vec2(hash12(cell + 11.3), hash12(cell + 27.1)) * 0.6 + 0.2;
	float age = fract(t * 0.9 + h);
	float r = length(local - centre);
	return sin(clamp((r - age * 0.45) * 40.0, -3.14159, 3.14159)) * (1.0 - age) * (1.0 - smoothstep(0.0, 0.08, abs(r - age * 0.45)));
}

// The scene colour the view-space ray from `pos` along `dir` reflects (rgb) and how sure
// the hit is (a): 0 where the ray leaves the screen or passes behind nothing.
vec4 screen_reflection(vec3 pos, vec3 dir, mat4 proj, mat4 inv_proj) {
	float t = 0.35;
	float prev_t = 0.0;
	for (int i = 0; i < ssr_steps; i++) {
		vec3 p = pos + dir * t;
		vec4 c = proj * vec4(p, 1.0);
		vec2 uv = c.xy / c.w * 0.5 + 0.5;
		if (p.z > -0.05 || any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
			break;
		}
		vec4 s = inv_proj * vec4(uv * 2.0 - 1.0, textureLod(depth_tex, uv, 0.0).r, 1.0);
		float behind = s.z / s.w - p.z;
		if (behind > 0.0) {
			if (behind > (t - prev_t) * 1.5 + 0.3) {
				// Passed behind something far in front of the ray (a reed, a post): no hit.
				return vec4(0.0);
			}
			// Home in on the surface between the last two steps.
			float lo = prev_t;
			float hi = t;
			for (int k = 0; k < 4; k++) {
				float mid = (lo + hi) * 0.5;
				vec4 cm = proj * vec4(pos + dir * mid, 1.0);
				vec2 um = cm.xy / cm.w * 0.5 + 0.5;
				vec4 sm = inv_proj * vec4(um * 2.0 - 1.0, textureLod(depth_tex, um, 0.0).r, 1.0);
				if (sm.z / sm.w - (pos.z + dir.z * mid) > 0.0) {
					hi = mid;
				} else {
					lo = mid;
				}
			}
			vec4 ch = proj * vec4(pos + dir * hi, 1.0);
			uv = ch.xy / ch.w * 0.5 + 0.5;
			// Fade toward the screen edges, where the reflected scene runs out.
			vec2 edge = smoothstep(vec2(0.0), vec2(0.06, 0.1), uv) * smoothstep(vec2(0.0), vec2(0.06, 0.02), 1.0 - uv);
			return vec4(textureLod(screen_tex, uv, 0.0).rgb, edge.x * edge.y);
		}
		prev_t = t;
		t *= 1.35;
	}
	return vec4(0.0);
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec2 p = v_wpos.xz;
	float e = 0.05;
	float k = ripple_strength * (0.6 + wind_strength * 0.6);
	float h = ripple(p, t);
	vec2 grad = vec2(ripple(p + vec2(e, 0.0), t) - h, ripple(p + vec2(0.0, e), t) - h) / e * k;
	if (wetness > 0.05) {
		float rh = rain_rings(p, t);
		grad += vec2(rain_rings(p + vec2(0.02, 0.0), t) - rh, rain_rings(p + vec2(0.0, 0.02), t) - rh) / 0.02
				* 0.012 * wetness;
	}
	vec3 n_world = normalize(vec3(-grad.x, 1.0, -grad.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float water_depth = max(VERTEX.z - view.z, 0.0);
	// Silt and weed make the bottom uneven: the depth tint wanders.
	float murk = vnoise2(p * 0.35 + vec2(2.3, 7.1));
	float d = clamp((water_depth + (murk - 0.5) * 0.6) / depth_range, 0.0, 1.0);

	vec3 col = mix(shallow_color, deep_color, sqrt(d));
	col *= 0.85 + 0.3 * vnoise2(p * 0.9 + vec2(5.0, 1.0));
	// Sediment stirred up at the edge.
	col = mix(col, shallow_color * vec3(1.25, 1.15, 0.9), (1.0 - smoothstep(0.0, 0.35, water_depth)) * 0.5);
	col = mix(col, snow_color() * 0.85, snow_amount * 0.9);

	// Mirrored shore and treeline, weighted by the water's Fresnel reflectance. Where
	// the march hits, it stands in for the sky reflection (SPECULAR drops so the two
	// don't add up); where it misses, the sky reflection stays.
	vec4 refl = vec4(0.0);
	float fresnel = 0.0;
	if (ssr_steps > 0 && snow_amount < 0.5) {
		vec3 v = normalize(VERTEX);
		// Ripples bend the mirror image only a little (they're shallow on a still pond).
		vec3 rn = normalize(mix((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, NORMAL, 0.45));
		float cos_v = clamp(dot(-v, rn), 0.0, 1.0);
		fresnel = 0.02 + 0.98 * pow(1.0 - cos_v, 5.0);
		refl = screen_reflection(VERTEX, reflect(v, rn), PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
		refl.a *= 1.0 - snow_amount * 2.0;
	}
	float mirror = fresnel * refl.a;
	ALBEDO = col * (1.0 - mirror);
	EMISSION = refl.rgb * mirror;
	// Clear in the shallows (the bottom shows), opaque where deep, and a soft edge
	// instead of a line where the water meets the shore.
	float edge = smoothstep(0.0, 0.08, water_depth);
	ALPHA = clamp((mix(0.45, 0.97, smoothstep(0.0, 1.0, d)) + snow_amount + mirror) * edge, 0.0, 1.0);
	ROUGHNESS = mix(mix(0.03, 0.08, wetness), 0.5, snow_amount);
	SPECULAR = 0.5 * (1.0 - refl.a * 0.85);
}
