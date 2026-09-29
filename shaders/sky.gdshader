// Photographic day/night sky.
//
// Air: a physically based atmosphere (Rayleigh, Mie, ozone; shaders/include/
// sky_atmosphere.gdshaderinc) gives the deep blue zenith, the pale hazy horizon, the
// sun's aureole and the twilight colours, the Earth's shadow and the Belt of Venus. It
// is brought to the brightness the game's lighting was tuned for by an exposure per
// sun height (baked from the earlier hand-tuned sky, see tools/bake_sky.py), so the
// ambient light keeps its level. Below the horizon it carries on as haze over distant
// land, so fog, aerial perspective and reflections never turn black.
// Sun: a limb-darkened disc reddened by the air it shines through. Moon: the real
// near side (NASA LRO) lit by the sun, with phases. Night: moonlit blue, stars that
// twinkle near the horizon and a faint Milky Way.
// Clouds (shaders/include/sky_clouds.gdshaderinc): volumetric on HIGH and ULTRA (ULTRA
// with finer steps, more light samples and eroded detail), the flat 2D layer on LOW and
// MEDIUM and in the radiance map.
// Passes: the quarter-res pass draws the air, the half-res pass the volumetric clouds,
// the full-res pass adds the sun, moon and stars and composes.
// Sun/moon directions, sunlight colour and weather values are driven by DayNightCycle.
shader_type sky;
render_mode use_debanding, use_half_res_pass, use_quarter_res_pass;

#include "res://shaders/include/noise.gdshaderinc"
#include "res://shaders/include/sky_atmosphere.gdshaderinc"
#include "res://shaders/include/sky_clouds.gdshaderinc"

// Seconds for cloud drift and star twinkle, set by DayNightCycle each frame. Unlike
// TIME it does not re-render the radiance map every frame (only on-screen passes use it).
global uniform float sky_time;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
// Colour of direct sunlight after its path through the air (DayNightCycle.sunlight()),
// and its strength relative to an overhead sun (the 2D clouds' light).
uniform vec3 sun_color = vec3(1.0, 0.97, 0.92);
uniform float sun_strength = 1.0;
// Share of direct sun the weather lets through.
uniform float sun_intensity = 1.0;
uniform vec3 zenith_night : source_color = vec3(0.016, 0.028, 0.075);
uniform vec3 horizon_night : source_color = vec3(0.045, 0.066, 0.125);
uniform vec3 ground_color : source_color = vec3(0.42, 0.44, 0.35);
// Brightness of the whole daylit sky on top of the tuned exposure.
uniform float sky_exposure = 1.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_darkness : hint_range(0.0, 1.0) = 0.0;
uniform float overcast : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_speed = 0.0035;
// 0: flat 2D clouds (LOW, MEDIUM), 1: volumetric (HIGH), 2: volumetric with finer
// steps, more light samples and detail (ULTRA).
uniform int cloud_quality = 2;
// Angle between the moon and the sun that lights it (radians): pi is a full moon.
uniform float moon_phase = 3.14159;
uniform sampler2D moon_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float star_brightness = 1.0;
// Set with temporal anti-aliasing (HIGH, ULTRA; Settings.uses_temporal_aa): the clouds'
// ray-march dithering moves on every frame, so it averages out into smooth cloud edges
// instead of standing as a fixed grain.
uniform bool temporal_jitter = false;
uniform float flash = 0.0;

// The real sun is 0.53 degrees across; a touch larger reads better on screen.
const float SUN_RADIUS = 0.0058;
const float SUN_DISC = 42.0;
// The moon at about three times its true size, as the eye judges it.
const float MOON_RADIUS = 0.012;
const float MOON_BRIGHTNESS = 1.9;
// Light of the moon on the clouds, relative to the night sky.
const vec3 MOON_LIGHT = vec3(0.03, 0.04, 0.065);
// The 2D clouds' skylight: the earlier tuned zenith, sunset zenith and horizon (linear).
const vec3 AMB_ZENITH = vec3(0.0242, 0.1144, 0.552);
const vec3 AMB_SUNSET = vec3(0.0395, 0.1221, 0.3185);
const vec3 AMB_HORIZON = vec3(0.3916, 0.5711, 0.8308);

// Brightness of the land below the horizon for the sun's height: it dims with the sun
// and fades out through twilight, holding until about -12 degrees.
float sky_brightness(float sun_h) {
	return sun_h >= 0.0 ? mix(0.3, 1.0, smoothstep(0.0, 0.6, sun_h)) : 0.3 * exp(sun_h * 14.0);
}

float day_weight(float sun_h) {
	return smoothstep(-0.25, -0.06, sun_h);
}

// The sky without sun disc, moon disc, stars or clouds.
vec3 base_sky(vec3 dir, vec3 sd, vec3 md, int steps) {
	float sun_h = sd.y;
	float day = day_weight(sun_h);
	float h = max(dir.y, 0.0);
	float below = smoothstep(-0.05, -0.35, dir.y);
	vec3 col = vec3(0.0);
	if (day > 0.0) {
		vec3 d = normalize(vec3(dir.x, h + 1e-4, dir.z));
		col = atmosphere(d, sd, steps) * sky_irradiance(sun_h).a * sky_exposure;
		// Below the horizon: the haze holds for the first degrees (aerial perspective
		// seen from a hilltop), then the dim land the sun and sky light.
		vec3 land = ground_color * sky_brightness(sun_h) * (0.5 + 0.9 * max(sun_h, 0.0));
		col = mix(col, land, below);
	}
	// Night sky under it all (moonlit blue, not black).
	vec3 night = mix(horizon_night, zenith_night, 1.0 - exp(-h * 2.5));
	col = mix(night * mix(0.7, 1.0, 1.0 - below), col, day);
	// The moon's aureole in the night haze.
	float mdot = max(dot(dir, md), 0.0);
	col += vec3(0.8, 0.86, 1.0) * (pow(mdot, 400.0) * 0.12 + pow(mdot, 30.0) * 0.015) * (1.0 - day) * (1.0 - overcast * 0.9);
	// Under a grey sky the air itself turns grey.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(col, vec3(lum) * mix(vec3(0.95, 0.97, 1.0), vec3(0.78), cloud_darkness) * 0.9, overcast * 0.85);
	return col;
}

// Light on the clouds: the sun (the moon once the sun is well down), the skylight
// above them and the light of the land below.
CloudLight cloud_light(vec3 sd, vec3 md, float height) {
	CloudLight lt;
	float sun_h = sd.y;
	float day = day_weight(sun_h);
	vec4 irr = sky_irradiance(sun_h);
	float scale = irr.a * sky_exposure;
	bool moonlit = sun_h < -0.12;
	lt.dir = moonlit ? md : sd;
	vec3 moon = MOON_LIGHT * smoothstep(-0.05, 0.1, md.y);
	lt.sun = moonlit ? moon : sun_transmittance(RG + height, sun_h) * scale;
	lt.sun_high = moonlit ? moon : sun_transmittance(RG + CIRRUS_H, sun_h) * scale;
	vec3 skylight = irr.rgb * scale / ATMO_PI;
	vec3 land = ground_color * (transmittance(RG + OBS_H, sun_h) * max(sun_h, 0.0) + irr.rgb) * scale / ATMO_PI;
	vec3 night = zenith_night * 3.0;
	lt.amb_top = mix(night, skylight, day) * CLOUD_AMB_GAIN;
	// Under a closed deck little light reaches the land and the cloud base.
	float shut = smoothstep(0.3, 0.85, overcast) * cloud_coverage;
	lt.amb_bottom = mix(night * 0.6, skylight * 0.45 + land * 0.55, day) * CLOUD_AMB_GAIN * (1.0 - 0.6 * shut);
	return lt;
}

// Volumetric clouds and cirrus for the camera at pos (m), premultiplied.
vec4 volumetric_clouds(vec3 dir, vec3 pos, vec3 sd, vec3 md, int steps, float fine, int lsteps, bool detail, float jitter) {
	CloudLayer c = cloud_layer(cloud_coverage, overcast, cloud_darkness, sky_time);
	CloudLight lt = cloud_light(sd, md, mix(c.base, c.top, 0.35));
	vec3 ro = vec3(pos.x, max(pos.y, 0.0), pos.z) * 0.001;
	vec4 cu = march_clouds(c, lt, ro, dir, steps, fine, lsteps, detail, jitter);
	// Cirrus on fair days, hidden once a deck closes in.
	vec4 ci = cirrus_layer(lt, ro, dir, 0.45 * (1.0 - c.strat), sky_time);
	vec4 res = vec4(cu.rgb + ci.rgb * (1.0 - cu.a), cu.a + ci.a * (1.0 - cu.a));
	// Storm clouds hang heavy and dark.
	res.rgb *= 1.0 - cloud_darkness * 0.3;
	return res;
}

// The flat 2D clouds over col (LOW, MEDIUM and the radiance map).
vec3 clouds_2d(vec3 col, vec3 dir, vec3 sd, vec3 md) {
	if (dir.y <= 0.0) {
		return col;
	}
	float sun_h = sd.y;
	float day = day_weight(sun_h);
	float twilight = smoothstep(-0.22, -0.02, sun_h) * (1.0 - smoothstep(0.0, 0.12, sun_h));
	vec2 flat_sun = normalize(sd.xz + vec2(1e-5));
	float cs = max(dot(dir, sd), 0.0);
	vec2 uv = dir.xz / (dir.y + 0.08) * 0.75 + vec2(sky_time * cloud_speed, sky_time * cloud_speed * 0.4);
	float base = fbm2(uv * 1.1);
	float lo = 1.0 - cloud_coverage;
	// The detail layer adds at most 0.28 * 0.96875 (fbm2's maximum): below that the
	// density is exactly 0, so the rest of the cloud is skipped.
	if (base * 0.8 + 0.27125 <= lo) {
		return col;
	}
	float shape = base * 0.8 + fbm2(uv * 4.3 + vec2(3.1, 7.7)) * 0.28;
	float dens = smoothstep(lo, lo + 0.22, shape);
	if (dens <= 0.0) {
		return col;
	}
	// Light reaching this point through the cloud towards the sun (Beer-Lambert on the
	// density a step sunwards): sunny tops, grey undersides.
	float toward = cloud_density_2d(uv + flat_sun * 0.05, cloud_coverage);
	float lit = exp(-max(toward - dens * 0.35, 0.0) * 1.8) * mix(1.0, 0.55, smoothstep(lo + 0.1, lo + 0.45, shape));
	// Clouds stand high and see a low sun through less air than the ground does.
	float sun_up = smoothstep(-0.1, 0.06, sun_h);
	vec3 sun_col = sun_color * sun_up * sun_intensity * sqrt(sun_strength);
	// Thin edges near the sun light up (forward scattering: the silver lining).
	float silver = pow(cs, 5.0) * (1.0 - dens) * 1.4;
	vec3 zen = mix(AMB_ZENITH, AMB_SUNSET, twilight * 0.75);
	vec3 night = mix(horizon_night, zenith_night, 1.0 - exp(-dir.y * 2.5));
	vec3 ambient = mix(zen, AMB_HORIZON, 0.7) * sky_brightness(sun_h) + night * (1.0 - day);
	vec3 cloud = ambient * mix(1.0, 0.72, dens) + sun_col * (lit * 1.05 + silver) * 1.6;
	cloud *= 1.0 - cloud_darkness * 0.55;
	cloud += vec3(0.2, 0.23, 0.3) * pow(max(dot(dir, md), 0.0), 8.0) * (1.0 - day) * 0.35;
	// Far clouds sink into the horizon haze.
	cloud = mix(cloud, col, (1.0 - smoothstep(0.02, 0.3, dir.y)) * 0.55);
	return mix(col, cloud, dens * smoothstep(0.0, 0.14, dir.y) * 0.97);
}

vec3 sun_disc(vec3 dir, vec3 sd, float px) {
	float c = dot(dir, sd);
	float rr = length(cross(dir, sd)) / SUN_RADIUS;
	if (c <= 0.0 || rr > 1.6) {
		return vec3(0.0);
	}
	float aa = max(px / SUN_RADIUS, 0.03);
	float edge = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, rr);
	// Limb darkening, stronger in blue.
	float mu = sqrt(max(0.0, 1.0 - min(rr * rr, 1.0)));
	vec3 limb = 1.0 - vec3(0.4, 0.5, 0.65) * (1.0 - mu);
	vec3 t = sun_transmittance(RG + OBS_H, sd.y);
	float peak = max(t.r, max(t.g, t.b));
	// Only half the dimming shows: the eye and the camera keep a low sun bright.
	return t * inversesqrt(max(peak, 1e-4)) * SUN_DISC * limb * edge;
}

// The moon's near side lit by the sun at the phase angle, Lommel-Seeliger shaded (the
// flat look of a full moon), with a trace of earthshine on its dark part.
vec3 moon_disc(vec3 dir, vec3 md, vec3 sd, float px) {
	if (dot(dir, md) <= 0.0) {
		return vec3(0.0);
	}
	vec3 side = cross(md, vec3(0.0, 1.0, 0.0));
	side = dot(side, side) < 1e-6 ? vec3(1.0, 0.0, 0.0) : normalize(side);
	vec3 up = cross(side, md);
	vec2 q = vec2(dot(dir, side), dot(dir, up)) / MOON_RADIUS;
	float rr = length(q);
	if (rr > 1.3) {
		return vec3(0.0);
	}
	float aa = max(px / MOON_RADIUS, 0.03);
	float edge = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, rr);
	float z = sqrt(max(0.0, 1.0 - min(rr * rr, 1.0)));
	vec3 n = side * q.x + up * q.y - md * z;
	// The light's direction: turned from the moon by the phase angle, towards the sun.
	vec3 perp = sd - md * dot(sd, md);
	perp = dot(perp, perp) < 1e-6 ? up : normalize(perp);
	float eps = min(acos(clamp(dot(md, sd), -1.0, 1.0)), moon_phase);
	vec3 L = md * cos(eps) + perp * sin(eps);
	float mu0 = max(dot(n, L), 0.0);
	float lit = 2.0 * mu0 / (mu0 + z + 1e-3);
	vec3 alb = texture(moon_albedo, vec2(q.x * 0.5 + 0.5, 0.5 - q.y * 0.5)).rgb;
	return alb * (lit + 0.015) * MOON_BRIGHTNESS * edge;
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// One layer of stars on a cube-sphere grid: n cells per face edge, a star in a share
// `prob` of them, brightness lo..hi (few bright, many faint), about a pixel wide.
vec3 star_layer(vec3 dir, float n, float prob, float lo, float hi, float px, float seed, float twinkle) {
	vec3 a = abs(dir);
	vec2 uv;
	float face;
	if (a.x >= a.y && a.x >= a.z) {
		uv = dir.zy / a.x;
		face = dir.x > 0.0 ? 0.0 : 1.0;
	} else if (a.y >= a.z) {
		uv = dir.xz / a.y;
		face = dir.y > 0.0 ? 2.0 : 3.0;
	} else {
		uv = dir.xy / a.z;
		face = dir.z > 0.0 ? 4.0 : 5.0;
	}
	vec2 g = (uv * 0.5 + 0.5) * n;
	vec2 cell = floor(g);
	float s = max(px * (1.0 + dot(uv, uv)) * 0.5 * n * 0.55, 0.02);
	vec3 col = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cc = cell + vec2(float(x), float(y));
			vec3 hh = hash33(vec3(cc, face * 7.0 + seed));
			if (hh.z < prob) {
				vec2 sp = cc + 0.1 + 0.8 * hh.xy;
				vec2 dd = (g - sp) / s;
				float r = hash12(cc + vec2(face * 31.0 + seed, seed));
				float b = mix(lo, hi, pow(r, 7.0));
				vec3 tint = mix(vec3(0.74, 0.84, 1.0), vec3(1.0, 0.8, 0.6), smoothstep(0.2, 1.0, hh.x * hh.y * 2.0));
				float tw = 1.0 + twinkle * sin(sky_time * (2.0 + 7.0 * r) + r * 71.0 + hh.x * 13.0);
				col += tint * b * tw * exp(-dot(dd, dd));
			}
		}
	}
	return col;
}

vec3 night_sky(vec3 dir, vec3 md, float px) {
	vec3 gal = normalize(vec3(0.35, 0.62, -0.7));
	float b = dot(dir, gal);
	float band = exp(-b * b * 28.0);
	float twinkle = mix(0.12, 0.55, 1.0 - smoothstep(0.05, 0.6, dir.y));
	vec3 col = star_layer(dir, 40.0, 0.035, 0.7, 4.0, px, 1.0, twinkle);
	col += star_layer(dir, 150.0, 0.03 + 0.08 * band, 0.06, 0.4, px, 2.0, twinkle);
	// The Milky Way: a faint glow along the band, broken by dust lanes.
	if (band > 0.02) {
		vec4 nz = textureLod(cloud_shape, dir * 0.8 + vec3(0.31, 0.17, 0.53), 0.0);
		vec4 nd = textureLod(cloud_shape, dir * 2.3 + vec3(0.7, 0.2, 0.9), 0.0);
		float dust = smoothstep(0.45, 0.8, nd.b) * exp(-b * b * 160.0);
		float glow = band * (0.3 + 0.7 * nz.r) * (1.0 - 0.75 * dust);
		col += vec3(1.0, 0.93, 0.84) * glow * 0.006;
	}
	// The moon's glare hides the stars around it.
	col *= 1.0 - 0.85 * pow(max(dot(dir, md), 0.0), 6.0);
	return col;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sd = normalize(sun_dir);
	vec3 md = normalize(moon_dir);
	if (AT_CUBEMAP_PASS) {
		// The radiance map: the air and the 2D clouds (the lighting only needs their
		// share of the sky), no discs.
		if (AT_HALF_RES_PASS || AT_QUARTER_RES_PASS) {
			COLOR = vec3(0.0);
		} else {
			COLOR = clouds_2d(base_sky(dir, sd, md, 12), dir, sd, md);
		}
	} else if (AT_QUARTER_RES_PASS) {
		COLOR = base_sky(dir, sd, md, 24);
	} else if (AT_HALF_RES_PASS) {
		vec4 cl = vec4(0.0);
		if (cloud_quality > 0) {
			vec2 cell = FRAGCOORD.xy;
			float turn = 0.0;
			if (temporal_jitter) {
				float frame = floor(sky_time * 60.0);
				cell += floor(fract(frame * vec2(0.7548777, 0.5698403)) * 64.0);
				turn = frame * 0.618034;
			}
			float jitter = fract(texelFetch(blue_noise, ivec2(mod(cell, 64.0)), 0).r + turn);
			if (cloud_quality >= 2) {
				cl = volumetric_clouds(dir, POSITION, sd, md, 48, 0.035, 6, true, jitter);
			} else {
				cl = volumetric_clouds(dir, POSITION, sd, md, 40, 0.05, 4, false, jitter);
			}
		}
		COLOR = cl.rgb;
		ALPHA = cl.a;
	} else {
		float px = length(fwidth(dir));
		vec4 q = QUARTER_RES_COLOR;
		float day = day_weight(sd.y);
		// Discs and stars, behind the clouds.
		vec3 behind = sun_disc(dir, sd, px) * mix(1.0, 1.0 - overcast * 0.97, cloud_quality == 0 ? 1.0 : 0.4);
		vec3 moon = moon_disc(dir, md, sd, px);
		behind += moon * mix(1.0, 0.12, day) * (1.0 - overcast * (cloud_quality == 0 ? 0.9 : 0.5));
		float star_vis = (1.0 - day) * smoothstep(0.0, 0.22, dir.y) * star_brightness
				* (1.0 - overcast * (cloud_quality == 0 ? 1.0 : 0.6));
		if (star_vis > 0.0 && moon == vec3(0.0)) {
			behind += night_sky(dir, md, px) * star_vis;
		}
		vec3 col;
		float cloud_a = 0.0;
		if (cloud_quality > 0) {
			vec4 hc = HALF_RES_COLOR;
			col = (q.rgb + behind) * (1.0 - hc.a) + hc.rgb;
			cloud_a = hc.a;
		} else {
			col = clouds_2d(q.rgb + behind, dir, sd, md);
			cloud_a = cloud_coverage * overcast;
		}
		// Lightning lights up the whole cloud deck.
		col += vec3(0.75, 0.8, 1.0) * flash * (0.4 + 0.6 * smoothstep(-0.05, 0.3, dir.y)) * (0.5 + 0.5 * cloud_a);
		COLOR = col;
	}
}
