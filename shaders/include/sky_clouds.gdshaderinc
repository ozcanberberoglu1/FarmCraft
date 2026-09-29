// Clouds of the sky shader. Needs sky_atmosphere.gdshaderinc and noise.gdshaderinc.
//
// Volumetric layer (HIGH and ULTRA): raymarched between two spheres around the Earth
// (so the deck curves down into the horizon), shaped like Schneider's Nubis clouds: a
// weather map says where clouds stand and how tall they grow, Perlin-Worley noise
// gives the billows and Worley detail erodes the edges (wispy at the base, cauliflower
// above). Lit by the sun (or the moon) through a short cone of light samples, with
// Wrenninge's octaves for multiple scattering, a forward lobe for the silver lining,
// "powder" darkening on lit faces turned away, and the sky's light as ambient. A
// cirrus sheet flies higher up. The weather decides the type: scattered cumulus on
// clear days, broken cumulus when cloudy, a low textured deck (stratocumulus to
// nimbostratus) under rain, snow and storms.
//
// All noise tiles over whole kilometres and drifts a whole number of tiles per wrap of
// sky_time (DayNightCycle.SKY_TIME_WRAP s), so the wrap never shows.

uniform sampler3D cloud_shape : filter_linear_mipmap, repeat_enable;
uniform sampler3D cloud_detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_weather : filter_linear_mipmap, repeat_enable;
// Where each pixel's ray starts (blue noise: an even grain rather than bands).
uniform sampler2D blue_noise : filter_nearest, repeat_enable;

const float SKY_TIME_WRAP = 3600.0;
// Tiles of the weather map, the shape and detail noise and the cirrus (km).
const float WEATHER_TILE = 30.0;
const float SHAPE_TILE = 5.0;
const float DETAIL_TILE = 0.5;
const float CIRRUS_TILE = 40.0;
const float CIRRUS_H = 8.5;
// Clouds farther than this (km) are left to the haze.
const float CLOUD_FAR = 60.0;
// Beyond this (km) a cloud is a few pixels across: no detail (and steps everywhere
// about two pixels wide).
const float CLOUD_DETAIL_FAR = 20.0;
// The longest stretch of the layer one ray marches through (km).
const float CLOUD_SPAN = 12.0;
// Aerial perspective: the haze between the camera and a cloud (1/e distance, km).
const float CLOUD_HAZE = 18.0;
// Light the clouds scatter on towards the eye relative to single scattering (their
// high albedo and many bounces), and the gain of the skylight on them.
const float CLOUD_SUN_GAIN = 2.0;
const float CLOUD_AMB_GAIN = 1.0;

struct CloudLayer {
	float base;
	float top;
	float cov;
	float strat;
	float sigma;
	vec2 drift;
	float evo;
};

struct CloudLight {
	vec3 dir;
	vec3 sun;
	vec3 sun_high;
	vec3 amb_top;
	vec3 amb_bottom;
};

// The layer for the weather: coverage 0..1, overcast 0..1 (turns cumulus into a deck),
// darkness 0..1 (thicker, darker cloud).
CloudLayer cloud_layer(float coverage, float overcast_amount, float darkness, float time) {
	CloudLayer c;
	c.strat = smoothstep(0.3, 0.85, overcast_amount);
	c.base = mix(1.5, 0.85, c.strat);
	c.top = mix(4.3, 2.7, c.strat);
	c.cov = coverage;
	c.sigma = mix(80.0, 130.0, darkness);
	c.drift = vec2(time * WEATHER_TILE / SKY_TIME_WRAP, 0.0);
	c.evo = time * SHAPE_TILE / SKY_TIME_WRAP;
	return c;
}

float cl_remap(float x, float a, float b, float c, float d) {
	return c + (x - a) / (b - a) * (d - c);
}

float hg_phase(float c, float g) {
	return (1.0 - g * g) / (4.0 * ATMO_PI * pow(max(1.0 + g * g - 2.0 * g * c, 1e-4), 1.5));
}

// Height above the ground sphere of a point relative to the camera's ground (km).
float cl_height(vec3 p) {
	return length(p + vec3(0.0, RG, 0.0)) - RG;
}

// Cloud density at p (km) and height fraction hf in the layer. `px` is the width of a
// pixel there (km): noise finer than that is blurred away (mipmaps), or far clouds
// would break up into speckles.
float cloud_density(CloudLayer c, vec3 p, float hf, bool detail, float px) {
	if (hf <= 0.0 || hf >= 1.0) {
		return 0.0;
	}
	vec2 wp = p.xz - c.drift;
	vec4 wm = textureLod(cloud_weather, wp / WEATHER_TILE, 0.0);
	// Local coverage: the weather's, gathered into clearer and cloudier stretches; a
	// deck closes it nearly everywhere.
	float cov = clamp(c.cov + (wm.r - 0.5) * 0.7, 0.0, 1.0);
	float deck = clamp(0.8 + 0.3 * (wm.a - 0.5), 0.0, 1.0) * smoothstep(0.55, 0.95, c.cov);
	cov = mix(cov, max(cov, deck), c.strat);
	if (cov <= 0.0) {
		return 0.0;
	}
	// Height profile: cumulus rise from a flat base to tops of varied height, a deck
	// is a band low in the layer with an undulating base.
	float tall = 0.15 + 0.8 * wm.g * sqrt(wm.g);
	float prof_cu = smoothstep(0.0, 0.05, hf) * (1.0 - smoothstep(tall * 0.2, tall, hf));
	float base_st = 0.02 + 0.2 * (1.0 - wm.a);
	float prof_st = smoothstep(base_st, base_st + 0.1, hf) * (1.0 - smoothstep(0.35, 0.8, hf));
	float prof = mix(prof_cu, prof_st, c.strat);
	if (prof <= 0.0) {
		return 0.0;
	}
	// Billows: Perlin-Worley eroded by Worley fbm, spread to about 0..1; the coverage
	// decides how much of it is cloud.
	vec3 sp = vec3(wp.x, p.y - c.evo, wp.y);
	vec4 n = textureLod(cloud_shape, sp / SHAPE_TILE, max(log2(px * 128.0 / SHAPE_TILE), 0.0));
	float wfbm = n.g * 0.5 + n.b * 0.3 + n.a * 0.2;
	float shape = clamp((cl_remap(n.r, wfbm - 1.0, 1.0, 0.0, 1.0) - 0.5) * 2.3, 0.0, 1.0);
	// A rain deck has no holes.
	shape = mix(shape, 0.3 + 0.7 * shape, c.strat * smoothstep(0.85, 0.95, c.cov));
	float d = clamp(cl_remap(shape * prof, 1.0 - cov, 1.0, 0.0, 1.0), 0.0, 1.0) * (0.5 + 0.5 * cov);
	if (detail && d > 0.0) {
		vec3 dp = vec3(wp.x, p.y - c.evo * (DETAIL_TILE / SHAPE_TILE), wp.y);
		vec3 dn = textureLod(cloud_detail, dp / DETAIL_TILE, max(log2(px * 32.0 / DETAIL_TILE), 0.0)).rgb;
		float dfbm = dn.r * 0.625 + dn.g * 0.25 + dn.b * 0.125;
		// Wispy at the base, billowy cauliflower above.
		float m = mix(dfbm, 1.0 - dfbm, clamp(hf * 6.0, 0.0, 1.0));
		d = clamp(cl_remap(d, m * 0.45, 1.0, 0.0, 1.0), 0.0, 1.0);
	}
	// Crisp edges: real cumulus thicken within metres of their surface.
	return pow(d, 0.7);
}

// Far intersection with a sphere of radius R around the Earth's centre (camera inside).
float sphere_exit(vec3 ro, vec3 rd, float R) {
	vec3 oc = ro + vec3(0.0, RG, 0.0);
	float b = dot(oc, rd);
	float cc = dot(oc, oc) - R * R;
	return -b + sqrt(max(b * b - cc, 0.0));
}

// Premultiplied cloud colour (rgb) and opacity (a) along rd from ro (km), with the
// haze in front of far clouds already taken out (it shows the sky behind instead).
// Empty air is crossed in long steps (at most `steps` of them over the layer); on
// touching a cloud the ray finds its surface by bisection and walks through it in
// `fine` km steps, so cloud edges come out crisp and free of grain.
vec4 march_clouds(CloudLayer c, CloudLight lt, vec3 ro, vec3 rd, int steps, float fine, int lsteps, bool detail, float jitter) {
	if (rd.y < 0.0) {
		return vec4(0.0);
	}
	float t0 = sphere_exit(ro, rd, RG + c.base);
	if (t0 > CLOUD_FAR) {
		return vec4(0.0);
	}
	float t1 = min(sphere_exit(ro, rd, RG + c.top), t0 + CLOUD_SPAN);
	float coarse = max((t1 - t0) / float(steps), fine * 2.0);
	float t = t0 + coarse * jitter;
	float cos_t = dot(rd, lt.dir);
	// Phase per octave: a strong forward lobe (silver lining) and a backward one.
	float ph0 = mix(hg_phase(cos_t, 0.7), hg_phase(cos_t, -0.3), 0.35);
	float ph1 = mix(hg_phase(cos_t, 0.4), hg_phase(cos_t, -0.15), 0.35);
	float ph2 = hg_phase(cos_t, 0.2);
	float powder_w = 0.5 - 0.5 * cos_t;
	float thick = c.top - c.base;
	float T = 1.0;
	vec3 acc = vec3(0.0);
	float alpha = 0.0;
	// Light samples reach this far through the cloud (km), crowded near the sample.
	const float LIGHT_REACH = 1.6;
	float lnorm = LIGHT_REACH / (pow(2.0, float(lsteps)) - 1.0);
	float lj = 0.5;
	bool inside = false;
	int empty = 0;
	for (int i = 0; i < steps * 4 && t < t1; i++) {
		vec3 p = ro + rd * t;
		float hf = (cl_height(p) - c.base) / thick;
		// About the width of a half-resolution pixel there.
		float px = t * 0.003;
		if (!inside) {
			// The coarse probe skips the detail: erosion only ever takes cloud away.
			if (cloud_density(c, p, hf, false, px) > 0.0) {
				// Home in on the cloud's surface between the last empty probe and this
				// one, so neighbouring pixels start on the same surface (no grain).
				float ta = max(t - coarse, t0);
				float tb = t;
				for (int k = 0; k < 6; k++) {
					float tm = 0.5 * (ta + tb);
					vec3 pm = ro + rd * tm;
					if (cloud_density(c, pm, (cl_height(pm) - c.base) / thick, false, px) > 0.0) {
						tb = tm;
					} else {
						ta = tm;
					}
				}
				t = tb;
				inside = true;
				empty = 0;
			} else {
				t += coarse;
			}
			continue;
		}
		bool near = detail && t < CLOUD_DETAIL_FAR;
		float step_len = max(fine, px * 2.0);
		float d = cloud_density(c, p, hf, near, px);
		if (d > 0.0) {
			empty = 0;
			// Far clouds are a pixel or two across: thinned, they fade in softly instead
			// of popping in whole pixels.
			float ext = d * c.sigma * mix(1.0, 0.3, smoothstep(6.0, 30.0, t));
			float tau = 0.0;
			float s0 = 0.0;
			for (int j = 0; j < lsteps; j++) {
				float s1 = lnorm * (pow(2.0, float(j + 1)) - 1.0);
				vec3 q = p + lt.dir * mix(s0, s1, lj);
				float qf = (cl_height(q) - c.base) / thick;
				tau += cloud_density(c, q, qf, near && j < 2, px) * (s1 - s0);
				s0 = s1;
			}
			tau *= c.sigma;
			float lum = ph0 * exp(-tau) + 0.6 * ph1 * exp(-tau * 0.25) + 0.35 * ph2 * exp(-tau * 0.0625);
			// Powder: light builds up only a little way into a lit face.
			lum *= mix(1.0, 1.0 - exp(-ext * 0.25), powder_w);
			// Skylight is shaded by the cloud above: dark bases under thick towers and
			// decks, bright small puffs.
			float up = cloud_density(c, p + vec3(0.0, 0.1, 0.0), hf + 0.1 / thick, false, px) * 0.1
					+ cloud_density(c, p + vec3(0.0, 0.4, 0.0), hf + 0.4 / thick, false, px) * 0.3;
			vec3 amb = mix(lt.amb_bottom, lt.amb_top, clamp(hf, 0.0, 1.0)) * mix(exp(-up * c.sigma * 0.3), 1.0, 0.2);
			vec3 S = lt.sun * lum * CLOUD_SUN_GAIN + amb;
			float Ts = exp(-ext * step_len);
			float keep = exp(-t / CLOUD_HAZE);
			acc += T * S * (1.0 - Ts) * keep;
			alpha += T * (1.0 - Ts) * keep;
			T *= Ts;
			if (T < 0.015) {
				break;
			}
		} else if (++empty > 6) {
			inside = false;
		}
		t += step_len;
	}
	return vec4(acc, alpha);
}

// The cirrus sheet high above: thin, fibrous, lit through by the sun.
vec4 cirrus_layer(CloudLight lt, vec3 ro, vec3 rd, float amount, float time) {
	if (amount <= 0.0 || rd.y <= 0.0) {
		return vec4(0.0);
	}
	float t = sphere_exit(ro, rd, RG + CIRRUS_H);
	vec3 p = ro + rd * t;
	vec2 uv = (p.xz - vec2(time * 2.0 * CIRRUS_TILE / SKY_TIME_WRAP, 0.0)) / CIRRUS_TILE;
	float lod = log2(max(t / CIRRUS_H, 1.0)) * 1.4;
	// Fibres only in some stretches of the sky.
	float patches = smoothstep(0.5, 0.85, textureLod(cloud_weather, uv * 0.23 + 0.61, 0.0).g);
	float v = textureLod(cloud_weather, uv * 1.7, lod).b;
	float d = smoothstep(1.0 - amount, 1.0 - amount + 0.55, v) * patches;
	d *= 0.35 + 0.65 * textureLod(cloud_weather, uv * 6.1 + 0.37, lod).a;
	float cos_t = dot(rd, lt.dir);
	vec3 col = lt.sun_high * (hg_phase(cos_t, 0.75) * 0.8 + 0.12) * 2.0 + lt.amb_top * 1.2;
	float a = d * 0.3 * exp(-t / (CLOUD_HAZE * 2.0));
	return vec4(col * a, a);
}

// The flat 2D clouds of LOW and MEDIUM (and of the radiance map): one fbm layer seen
// through a flattened dome, self-shadowed a step towards the sun.
float cloud_density_2d(vec2 uv, float coverage) {
	float base = fbm2(uv * 1.1);
	float detail = fbm2(uv * 4.3 + vec2(3.1, 7.7));
	float d = base * 0.8 + detail * 0.28;
	return smoothstep(1.0 - coverage, 1.0 - coverage + 0.22, d);
}
