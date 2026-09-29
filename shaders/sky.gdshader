// Day/night sky tuned against photographs: a deep blue zenith over a bright, hazy
// horizon whose brightness follows the sun's height, a Mie glow around the sun,
// twilight colours (the warm glow over the setting sun, the pink Belt of Venus above
// the Earth's blue shadow opposite it), stars, moon and self-shadowed clouds.
// Below the horizon it carries on as haze over distant land instead of a dark ground,
// so fog, aerial perspective and reflections never turn black.
// Sun/moon directions, sunlight colour and weather values are driven by DayNightCycle.
shader_type sky;
render_mode use_debanding;

#include "res://shaders/include/noise.gdshaderinc"

// Seconds for cloud drift and star twinkle, set by DayNightCycle each frame. Unlike
// TIME it does not re-render the radiance map every frame (only on-screen passes use it).
global uniform float sky_time;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
// Colour of direct sunlight after its path through the air (DayNightCycle.sunlight()),
// and its strength relative to an overhead sun.
uniform vec3 sun_color = vec3(1.0, 0.97, 0.92);
uniform float sun_strength = 1.0;
uniform float sun_intensity = 1.0;
uniform vec3 zenith_day : source_color = vec3(0.17, 0.37, 0.77);
uniform vec3 horizon_day : source_color = vec3(0.66, 0.78, 0.92);
uniform vec3 zenith_night : source_color = vec3(0.016, 0.028, 0.075);
uniform vec3 horizon_night : source_color = vec3(0.045, 0.066, 0.125);
uniform vec3 sunset_glow : source_color = vec3(1.0, 0.5, 0.2);
uniform vec3 sunset_zenith : source_color = vec3(0.22, 0.38, 0.6);
// The low sky around a low sun, lit by reddened sunlight: pale gold.
uniform vec3 golden_horizon : source_color = vec3(0.98, 0.9, 0.64);
uniform vec3 belt_of_venus : source_color = vec3(0.8, 0.62, 0.64);
uniform vec3 earth_shadow : source_color = vec3(0.3, 0.36, 0.52);
uniform vec3 ground_color : source_color = vec3(0.42, 0.44, 0.35);
uniform float day_energy = 1.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_darkness : hint_range(0.0, 1.0) = 0.0;
uniform float overcast : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_speed = 0.0035;
uniform float star_brightness = 1.2;
uniform float flash = 0.0;

float cloud_density(vec2 uv) {
	float base = fbm2(uv * 1.1);
	float detail = fbm2(uv * 4.3 + vec2(3.1, 7.7));
	float d = base * 0.8 + detail * 0.28;
	return smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.22, d);
}

// Brightness of the daylit sky for the sun's height: it dims with the sun and fades
// out through twilight, holding a deep blue hour until about -12 degrees.
float sky_brightness(float sun_h) {
	return sun_h >= 0.0 ? mix(0.3, 1.0, smoothstep(0.0, 0.6, sun_h)) : 0.3 * exp(sun_h * 14.0);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sd = normalize(sun_dir);
	vec3 md = normalize(moon_dir);
	float sun_h = sd.y;
	float day = smoothstep(-0.25, -0.06, sun_h);
	// 1 while the sun is within a few degrees of the horizon: sunrise and sunset colours.
	float twilight = smoothstep(-0.22, -0.02, sun_h) * (1.0 - smoothstep(0.0, 0.12, sun_h));
	// Once the sun is down: the afterglow, the Earth's shadow and the Belt of Venus.
	float sundown = smoothstep(0.03, -0.02, sun_h);
	float dusk = sundown * (1.0 - smoothstep(-0.1, -0.18, sun_h));

	float h = max(dir.y, 0.0);
	float cos_sun = dot(dir, sd);
	vec2 flat_dir = normalize(dir.xz + vec2(1e-5));
	vec2 flat_sun = normalize(sd.xz + vec2(1e-5));
	float toward_sun = dot(flat_dir, flat_sun) * 0.5 + 0.5;

	// Daylit sky: zenith to horizon with an exponential falloff like real haze.
	vec3 zen = mix(zenith_day, sunset_zenith, twilight * 0.75);
	vec3 hor = horizon_day;
	// Opposite the low sun: the pink band above the Earth's blue shadow.
	float away = pow(1.0 - toward_sun, 2.0) * dusk;
	hor = mix(hor, earth_shadow, away * (1.0 - smoothstep(0.0, 0.1, h)) * 0.8);
	zen = mix(zen, belt_of_venus, away * smoothstep(0.03, 0.12, h) * (1.0 - smoothstep(0.12, 0.35, h)) * 0.55);
	vec3 col = mix(hor, zen, 1.0 - exp(-h * mix(3.4, 5.0, twilight)));
	// On the sun's side of a low sun the sky warms from the horizon up: orange hugging
	// the horizon at sunset, pale gold above it from golden hour on, fading into the
	// blue through a pale, whitish band. (Blending the orange straight into the blue
	// would pass through mauve, which a clear sky never shows there.)
	float side = pow(toward_sun, 3.0);
	float golden = (1.0 - smoothstep(0.03, 0.35, sun_h)) * smoothstep(-0.1, 0.02, sun_h);
	float glow_w = twilight * mix(0.25, 1.0, side);
	col = mix(col, golden_horizon, max(golden * side * 0.6, glow_w * 0.7) * exp(-h * 3.5));
	vec3 glow = sunset_glow * mix(0.6, 1.3, pow(toward_sun, 4.0));
	col = mix(col, glow, glow_w * exp(-h * 10.0));
	// Afterglow once the sun is down: peach low over where it set.
	col = mix(col, vec3(0.92, 0.62, 0.48), twilight * sundown * pow(toward_sun, 2.0) * exp(-h * 7.0) * 0.45);

	// Mie scattering around the sun: a tight aureole and a broad glow, stronger when the
	// sun is low and its light crosses more haze. The aureole takes the sunlight's
	// colour, gold with a low sun; the broad glow is paler, as more red over the blue
	// sky would turn it mauve.
	float cs = max(cos_sun, 0.0);
	float g = 0.78;
	float hg = (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cos_sun, 1.5);
	vec3 mie = sun_color * hg * 0.012 + mix(sun_color, vec3(1.0, 0.95, 0.82), 0.5) * pow(cs, 12.0) * 0.07;
	mie *= 1.0 + twilight * 0.6 + (1.0 - h) * 0.3;
	col += mie * smoothstep(-0.1, 0.02, sun_h) * sun_intensity;
	col *= day_energy * sky_brightness(sun_h);

	// Below the horizon: the haze holds for the first degrees (aerial perspective seen
	// from a hilltop), then the dim land the sun and sky light (its albedo's share).
	float below = smoothstep(-0.05, -0.35, dir.y);
	vec3 land = ground_color * day_energy * sky_brightness(sun_h) * (0.5 + 0.9 * max(sun_h, 0.0));
	col = mix(col, land, below);

	// Night sky under it all (moonlit blue, not black).
	vec3 night = mix(horizon_night, zenith_night, 1.0 - exp(-h * 2.5));
	col = mix(night * mix(0.7, 1.0, 1.0 - below), col, day);

	// Overcast flattens everything to grey.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(col, vec3(lum) * mix(vec3(0.95, 0.97, 1.0), vec3(0.78), cloud_darkness) * 0.9, overcast * 0.85);

	// Sun disc.
	float sun_disc = smoothstep(0.99988, 0.99994, cos_sun);
	col += sun_color * sun_disc * 40.0 * smoothstep(-0.015, 0.01, sun_h) * (1.0 - overcast * 0.97);

	// Moon.
	float mdot = dot(dir, md);
	float moon_disc = smoothstep(0.99955, 0.99970, mdot);
	float moon_glow = pow(max(mdot, 0.0), 400.0) * 0.12 + pow(max(mdot, 0.0), 30.0) * 0.015;
	col += vec3(0.8, 0.86, 1.0) * (moon_disc * 0.9 + moon_glow) * (1.0 - day) * (1.0 - overcast * 0.9);

	if (!AT_CUBEMAP_PASS && dir.y > 0.0) {
		float vis = (1.0 - day) * (1.0 - overcast) * smoothstep(0.03, 0.3, dir.y);
		if (vis > 0.0) {
			vec3 sp = dir * 300.0;
			vec3 cell = floor(sp);
			float r = hash13(cell);
			float star = step(0.9972, r) * (0.4 + 0.6 * hash13(cell + 7.0));
			float dist = length(fract(sp) - 0.5);
			float twinkle = 0.6 + 0.4 * sin(sky_time * (1.5 + r * 6.0) + r * 91.0);
			col += vec3(0.9, 0.94, 1.0) * star * smoothstep(0.3, 0.0, dist) * twinkle * star_brightness * vis;
		}
		vec2 uv = dir.xz / (dir.y + 0.08) * 0.75 + vec2(sky_time * cloud_speed, sky_time * cloud_speed * 0.4);
		float base = fbm2(uv * 1.1);
		float lo = 1.0 - cloud_coverage;
		// The detail layer adds at most 0.28 * 0.96875 (fbm2's maximum): below that the
		// density is exactly 0, so the rest of the cloud is skipped.
		if (base * 0.8 + 0.27125 > lo) {
			float shape = base * 0.8 + fbm2(uv * 4.3 + vec2(3.1, 7.7)) * 0.28;
			float dens = smoothstep(lo, lo + 0.22, shape);
			if (dens > 0.0) {
				// Light reaching this point through the cloud towards the sun (Beer-Lambert
				// on the density a step sunwards): sunny tops, grey undersides.
				float toward = cloud_density(uv + flat_sun * 0.05);
				float lit = exp(-max(toward - dens * 0.35, 0.0) * 1.8) * mix(1.0, 0.55, smoothstep(lo + 0.1, lo + 0.45, shape));
				// Clouds stand high and see a low sun through less air than the ground does:
				// lit by its colour at more of its strength.
				float sun_up = smoothstep(-0.1, 0.06, sun_h);
				vec3 sun_col = sun_color * sun_up * sun_intensity * sqrt(sun_strength);
				// Thin edges near the sun light up (forward scattering: the silver lining).
				float silver = pow(cs, 5.0) * (1.0 - dens) * 1.4;
				// Skylight on the cloud: mostly the bright low sky, a little of the blue.
				vec3 ambient = mix(zen, hor, 0.7) * sky_brightness(sun_h) * day_energy + night * (1.0 - day);
				vec3 cloud = ambient * mix(1.0, 0.72, dens) + sun_col * (lit * 1.05 + silver) * 1.6;
				cloud *= 1.0 - cloud_darkness * 0.55;
				cloud += vec3(0.2, 0.23, 0.3) * pow(max(mdot, 0.0), 8.0) * (1.0 - day) * 0.35;
				// Far clouds sink into the horizon haze.
				cloud = mix(cloud, col, (1.0 - smoothstep(0.02, 0.3, dir.y)) * 0.55);
				float fade = smoothstep(0.0, 0.14, dir.y);
				col = mix(col, cloud, dens * fade * 0.97);
			}
		}
	}
	// Lightning lights up the whole cloud deck.
	col += vec3(0.75, 0.8, 1.0) * flash * (0.4 + 0.6 * smoothstep(-0.05, 0.3, dir.y));
	COLOR = col;
}
