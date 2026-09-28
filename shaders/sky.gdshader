// Day/night sky with realistic tuning: deep blue zenith fading to a pale hazy horizon,
// Mie-style glow around the sun, warm sunsets, stars, moon and self-shadowed clouds.
// Sun/moon directions and weather values are driven by DayNightCycle.
shader_type sky;
render_mode use_debanding;

#include "res://shaders/include/noise.gdshaderinc"

// Seconds for cloud drift and star twinkle, set by DayNightCycle each frame. Unlike
// TIME it does not re-render the radiance map every frame (only on-screen passes use it).
global uniform float sky_time;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float sun_intensity = 1.0;
uniform vec3 zenith_day : source_color = vec3(0.18, 0.38, 0.72);
uniform vec3 horizon_day : source_color = vec3(0.66, 0.78, 0.9);
uniform vec3 zenith_night : source_color = vec3(0.01, 0.016, 0.04);
uniform vec3 horizon_night : source_color = vec3(0.035, 0.05, 0.09);
uniform vec3 sunset_horizon : source_color = vec3(0.98, 0.52, 0.26);
uniform vec3 sunset_zenith : source_color = vec3(0.32, 0.34, 0.55);
uniform vec3 ground_color : source_color = vec3(0.3, 0.3, 0.27);
uniform float day_energy = 1.1;
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
	return smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.3, d);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sd = normalize(sun_dir);
	vec3 md = normalize(moon_dir);
	float sun_h = sd.y;
	float day = smoothstep(-0.14, 0.12, sun_h);
	float twilight = smoothstep(-0.3, -0.02, sun_h) * (1.0 - smoothstep(0.02, 0.3, sun_h));

	float h = clamp(dir.y, 0.0, 1.0);
	float cos_sun = dot(dir, sd);
	vec2 flat_dir = normalize(dir.xz + vec2(1e-5));
	vec2 flat_sun = normalize(sd.xz + vec2(1e-5));
	float toward_sun = max(dot(flat_dir, flat_sun), 0.0);

	// Gradient: zenith -> horizon with an exponential falloff like real haze.
	vec3 zen = mix(zenith_night, zenith_day, day);
	vec3 hor = mix(horizon_night, horizon_day, day);
	zen = mix(zen, sunset_zenith, twilight * 0.7);
	hor = mix(hor, sunset_horizon, twilight * (0.35 + 0.65 * pow(toward_sun, 2.0)));
	vec3 col = mix(hor, zen, 1.0 - exp(-h * 3.2));
	col *= mix(0.2, day_energy, day) + twilight * 0.3;

	// Mie scattering glow around the sun, stronger when the sun is low.
	float mie = pow(max(cos_sun, 0.0), 12.0) * 0.35 + pow(max(cos_sun, 0.0), 180.0) * 1.2;
	vec3 sun_tint = mix(vec3(1.0, 0.55, 0.25), vec3(1.0, 0.93, 0.8), smoothstep(0.0, 0.35, sun_h));
	col += sun_tint * mie * smoothstep(-0.08, 0.05, sun_h) * (0.6 + twilight) * sun_intensity;
	float sun_disc = smoothstep(0.99955, 0.99975, cos_sun);
	col += sun_tint * sun_disc * 30.0 * smoothstep(-0.02, 0.02, sun_h) * (1.0 - overcast * 0.95);

	// Below the horizon: fade to a dim ground color.
	col = mix(col, ground_color * (0.06 + 0.5 * day), smoothstep(0.0, -0.15, dir.y));

	// Overcast flattens everything to grey.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(col, vec3(lum) * mix(vec3(0.95, 0.97, 1.0), vec3(0.8), cloud_darkness) * 0.9, overcast * 0.85);

	// Moon.
	float mdot = dot(dir, md);
	float moon_disc = smoothstep(0.99955, 0.99970, mdot);
	float moon_glow = pow(max(mdot, 0.0), 400.0) * 0.12 + pow(max(mdot, 0.0), 30.0) * 0.012;
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
			float dens = smoothstep(lo, lo + 0.3, base * 0.8 + fbm2(uv * 4.3 + vec2(3.1, 7.7)) * 0.28);
			if (dens > 0.0) {
				float toward = cloud_density(uv + flat_sun * 0.05);
				float lit = clamp(1.0 - (toward - dens) * 1.8 - dens * 0.3, 0.3, 1.0);
				vec3 sun_col = sun_tint * smoothstep(-0.12, 0.08, sun_h) * sun_intensity;
				vec3 ambient = mix(zen, hor, 0.5) * 0.9;
				vec3 cloud = ambient * 0.7 + sun_col * lit * mix(0.25, 1.05, day);
				cloud = mix(cloud, sunset_horizon * 1.1 * lit, twilight * 0.5 * pow(toward_sun, 1.5));
				cloud *= 1.0 - cloud_darkness * 0.55;
				cloud += vec3(0.2, 0.23, 0.3) * pow(max(mdot, 0.0), 8.0) * (1.0 - day) * 0.35;
				float fade = smoothstep(0.0, 0.16, dir.y);
				col = mix(col, cloud, dens * fade * 0.97);
			}
		}
	}
	// Lightning lights up the whole cloud deck.
	col += vec3(0.75, 0.8, 1.0) * flash * (0.4 + 0.6 * smoothstep(-0.05, 0.3, dir.y));
	COLOR = col;
}
