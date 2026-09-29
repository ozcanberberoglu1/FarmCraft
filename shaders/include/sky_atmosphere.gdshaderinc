// Physically based atmosphere after Hillaire, "A Scalable and Production Ready Sky
// and Atmosphere Rendering Technique" (2020): Rayleigh and Mie scattering and ozone
// absorption over a spherical Earth, single scattering raymarched per pixel with the
// transmittance and multiple-scattering LUTs baked by tools/bake_sky.py (the constants
// below must match it). Lengths in km; radiance for a sun of irradiance 1.

uniform sampler2D transmittance_lut : filter_linear, repeat_disable;
uniform sampler2D multiscatter_lut : filter_linear, repeat_disable;
// rgb: sky irradiance on level ground per sun height; a: log of the exposure that
// brings the physical sky to the brightness the game's lighting was tuned for.
uniform sampler2D sky_irradiance_lut : filter_linear, repeat_disable;

const float ATMO_PI = 3.14159265;
const float RG = 6360.0;
const float RT = 6460.0;
const vec3 RAY_S = vec3(5.802e-3, 13.558e-3, 33.1e-3);
const float RAY_H = 8.0;
const float MIE_S = 5.5944e-3;
const float MIE_A = 0.6216e-3;
const float MIE_H = 1.2;
const vec3 OZO_A = vec3(0.650e-3, 1.881e-3, 0.085e-3);
const float MIE_G = 0.8;
// The observer's height above the ground sphere (the farm's hills).
const float OBS_H = 0.3;
const float IRR_MIN = -0.3;

// LUT coordinates with the unit range mapped onto the first and last texel centres.
vec2 lut_uv(vec2 unit, vec2 size) {
	return (clamp(unit, 0.0, 1.0) * (size - 1.0) + 0.5) / size;
}

// Transmittance from radius r along zenith cosine mu to the top of the atmosphere.
vec3 transmittance(float r, float mu) {
	float H = sqrt(RT * RT - RG * RG);
	float rho = sqrt(max(0.0, r * r - RG * RG));
	float d = max(0.0, -r * mu + sqrt(max(r * r * (mu * mu - 1.0) + RT * RT, 0.0)));
	float d_min = RT - r;
	float d_max = rho + H;
	vec2 uv = vec2((d - d_min) / max(d_max - d_min, 1e-4), rho / H);
	return textureLod(transmittance_lut, lut_uv(uv, vec2(256.0, 64.0)), 0.0).rgb;
}

// Transmittance towards the sun, zero in the Earth's shadow (softened over the sun's size).
vec3 sun_transmittance(float r, float mu) {
	float s = RG / r;
	float mu_h = -sqrt(max(0.0, 1.0 - s * s));
	return transmittance(r, mu) * smoothstep(mu_h - 0.005, mu_h + 0.005, mu);
}

vec3 multiscatter(float r, float mu_s) {
	vec2 uv = vec2(mu_s * 0.5 + 0.5, (r - RG) / (RT - RG));
	return textureLod(multiscatter_lut, lut_uv(uv, vec2(32.0)), 0.0).rgb;
}

// rgb: sky irradiance on the ground, a: exposure (see sky_irradiance_lut).
vec4 sky_irradiance(float mu_s) {
	float u = (mu_s - IRR_MIN) / (1.0 - IRR_MIN);
	vec4 v = textureLod(sky_irradiance_lut, lut_uv(vec2(u, 0.5), vec2(128.0, 1.0)), 0.0);
	return vec4(v.rgb, exp(v.a));
}

float phase_rayleigh(float c) {
	return 3.0 / (16.0 * ATMO_PI) * (1.0 + c * c);
}

// Cornette-Shanks.
float phase_mie(float c, float g) {
	float k = 3.0 / (8.0 * ATMO_PI) * (1.0 - g * g) / (2.0 + g * g);
	return k * (1.0 + c * c) / pow(max(1.0 + g * g - 2.0 * g * c, 1e-4), 1.5);
}

// Sky radiance along dir (dir.y >= 0) seen from the observer, in `steps` samples that
// crowd towards the observer, where the air is densest.
vec3 atmosphere(vec3 dir, vec3 sun, int steps) {
	float r = RG + OBS_H;
	vec3 ro = vec3(0.0, r, 0.0);
	float mu = dir.y;
	float tmax = -r * mu + sqrt(max(r * r * (mu * mu - 1.0) + RT * RT, 0.0));
	float c = dot(dir, sun);
	float pr = phase_rayleigh(c);
	float pm = phase_mie(c, MIE_G);
	vec3 L = vec3(0.0);
	vec3 thr = vec3(1.0);
	float t0 = 0.0;
	float n = float(steps);
	for (int i = 0; i < steps; i++) {
		float f = (float(i) + 1.0) / n;
		float t1 = f * f * tmax;
		float dt = t1 - t0;
		vec3 p = ro + dir * (t0 + dt * 0.5);
		t0 = t1;
		float pr_len = length(p);
		float h = max(pr_len - RG, 0.0);
		float mus = dot(p, sun) / pr_len;
		float dr = exp(-h / RAY_H);
		float dm = exp(-h / MIE_H);
		float dz = max(0.0, 1.0 - abs(h - 25.0) / 15.0);
		vec3 ray = RAY_S * dr;
		float mie = MIE_S * dm;
		vec3 ext = ray + vec3(dm * (MIE_S + MIE_A)) + OZO_A * dz;
		vec3 S = sun_transmittance(pr_len, mus) * (ray * pr + mie * pm) + multiscatter(pr_len, mus) * (ray + mie);
		vec3 st = exp(-ext * dt);
		L += thr * S * (1.0 - st) / ext;
		thr *= st;
	}
	return L;
}
