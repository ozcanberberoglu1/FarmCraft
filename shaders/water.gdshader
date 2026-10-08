// Farm pond water: murky, tea-and-algae coloured, clear enough in the shallows to show
// the mud below and dark where deep (depth from the depth buffer). A still surface with
// fine wind ripples (and rain rings when it rains) mirrors the sky at grazing angles
// through low roughness, and the shore, reeds and treeline through a short screen-space
// reflection march (ssr_steps, 0 = off); the edge fades out where the water meets the shore.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"
// Rain falling right now (Weather.rain_fall), 0..1.
global uniform float rain_amount;

uniform vec3 shallow_color : source_color = vec3(0.26, 0.28, 0.18);
uniform vec3 deep_color : source_color = vec3(0.07, 0.095, 0.075);
uniform float depth_range = 1.1;
uniform float ripple_strength = 0.04;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// Reflection march steps (each one depth read); the ray reaches about 0.35 * 1.35^steps m.
uniform int ssr_steps = 16;
// The sun and the moon on the water as still water shows them: a small bright core and a
// soft streak the ripples break up (light(), the farm pond: Pond). Off: the earlier wide
// highlight.
uniform bool soft_sun = false;

varying vec3 v_wpos;
// How much the ripples' slope changes across this pixel, squared (fragment() to light()).
varying float v_slope_blur;

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

// The most a pixel's span of ripples widens the sun's sparkles (slope, squared).
const float SLOPE_BLUR_MAX = 0.004;
// Snow lying on the frozen pond: as rough as snow anywhere.
const float SNOW_ROUGHNESS = 0.5;

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
	// Drops ring the water only while rain is falling (the banks may stay wet for hours).
	if (rain_amount > 0.02) {
		float rh = rain_rings(p, t);
		grad += vec2(rain_rings(p + vec2(0.02, 0.0), t) - rh, rain_rings(p + vec2(0.0, 0.02), t) - rh) / 0.02
				* 0.012 * rain_amount;
	}
	vec3 n_world = normalize(vec3(-grad.x, 1.0, -grad.y));
	// Far off a pixel spans whole ripples: there the sun's sparkles blur into a smooth,
	// dimmer streak instead of flickering from frame to frame (light()).
	vec2 slope_step = fwidth(grad);
	v_slope_blur = min(0.25 * dot(slope_step, slope_step), SLOPE_BLUR_MAX);
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
	ROUGHNESS = mix(mix(0.03, 0.08, wetness), SNOW_ROUGHNESS, snow_amount);
	SPECULAR = 0.5 * (1.0 - refl.a * 0.85);
}


// A lamp on the water, and the sun and the moon where soft_sun is off. A pond's surface
// is close to a mirror (ROUGHNESS 0.03), and the engine's own highlight on a mirror is a
// pinpoint many times brighter than the sky: with the glow on it blew out into a white,
// blooming blob in the afternoon and at sunset. Here the highlight is a little wider
// than the mirror's (GLINT_ROUGHNESS) and never brighter than GLINT_MAX.
const float GLINT_ROUGHNESS = 0.075;
const float GLINT_MAX = 0.6;

// The sun and the moon with soft_sun. The wide highlight above is far over GLINT_MAX all
// through its middle, so the cap cut it off flat: the sun stood on the pond as flat white
// patches several degrees across (the sun's own disc is 0.66), which the glow then spread.
// Still water shows the sun's small image instead, and its ripples scatter sparkles of it
// in a path towards the eye. So here the highlight has two parts, each brightest at one
// point and falling off softly from it (no flat top):
//   the core: the sun's image, about SUN_CORE_SPREAD across in the water's slope (a
//     degree or so on screen), on a surface that follows the ripples only SUN_CORE_RIPPLE of
//     the way, so it wobbles and dents but stays in one piece; SUN_CORE_MAX at its centre
//     (as bright as the old cap, which the tonemapper keeps under white);
//   the streak: the shimmer where a ripple's own slope mirrors the sun (SUN_STREAK_SPREAD),
//     at most SUN_STREAK_MAX when the sun is low and the water mirrors strongly: there
//     it draws out into a path towards the eye by itself. Under a high sun only
//     SUN_STREAK_HIGH of that is left, a faint shimmer round the core (with more of it
//     a pale, smoky blotch as wide as the old disc stood there).
// Both follow the light's strength up to SUN_FULL (a third of the midday sun: a low or
// veiled sun and the moon shine weaker on the water) and take its colour.
// Snow on the ice mirrors nothing: the sun's image goes as the snow comes (gone at half
// cover, like the mirrored shore in fragment()), and what is left is the snow's own wide,
// dim sheen (the highlight above at SNOW_ROUGHNESS), not a bright point on the white.
const float SUN_CORE_SPREAD = 0.0065;
const float SUN_CORE_RIPPLE = 0.15;
const float SUN_CORE_MAX = 0.6;
const float SUN_STREAK_SPREAD = 0.045;
const float SUN_STREAK_MAX = 0.2;
const float SUN_STREAK_HIGH = 0.12;
const float SUN_FULL = 1.0;

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(VIEW + LIGHT);
	float f = 0.02 + 0.98 * pow(1.0 - clamp(dot(VIEW, h), 0.0, 1.0), 5.0);
	bool soft = soft_sun && LIGHT_IS_DIRECTIONAL;
	float open = soft ? clamp(1.0 - snow_amount * 2.0, 0.0, 1.0) : 0.0;
	if (open > 0.0) {
		vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		vec3 lit = ATTENUATION * LIGHT_COLOR / PI;
		float strength = max(lit.r, max(lit.g, lit.b));
		float height = dot(up, LIGHT);
		if (strength > 0.0001 && height > 0.0) {
			float level = min(strength / SUN_FULL, 1.0) * smoothstep(0.0, 0.04, height) * open;
			// The core, on the nearly flat surface.
			float c = max(dot(normalize(mix(up, NORMAL, SUN_CORE_RIPPLE)), h), 0.001);
			float cs = SUN_CORE_SPREAD * SUN_CORE_SPREAD;
			float cw = cs + v_slope_blur * SUN_CORE_RIPPLE * SUN_CORE_RIPPLE;
			float core = cs / cw * exp(-(1.0 - c * c) / (c * c * cw));
			// The sparkles, on the ripples themselves.
			float n = max(dot(NORMAL, h), 0.001);
			float ss = SUN_STREAK_SPREAD * SUN_STREAK_SPREAD;
			float sw = ss + v_slope_blur;
			float streak = ss / sw * exp(-(1.0 - n * n) / (n * n * sw))
					* SUN_STREAK_MAX * mix(SUN_STREAK_HIGH, 1.0, smoothstep(0.02, 0.3, f));
			SPECULAR_LIGHT += lit / strength * level * mix(streak, SUN_CORE_MAX, core);
		}
	}
	if (open < 1.0) {
		float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
		float a = soft ? SNOW_ROUGHNESS : max(ROUGHNESS, GLINT_ROUGHNESS);
		float a2 = a * a * a * a;
		float den = ndh * ndh * (a2 - 1.0) + 1.0;
		float d = a2 / (PI * den * den);
		vec3 glint = d * f * 0.25 * ndl * ATTENUATION * LIGHT_COLOR / PI;
		float peak = max(glint.r, max(glint.g, glint.b));
		if (peak > GLINT_MAX) {
			glint *= GLINT_MAX / peak;
		}
		SPECULAR_LIGHT += glint * (1.0 - open);
	}
}
