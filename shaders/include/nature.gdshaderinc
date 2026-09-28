// Shared world-state uniforms and ground colors used by terrain, grass and props.
#include "res://shaders/include/noise.gdshaderinc"

global uniform float snow_amount;
global uniform float autumn_amount;
global uniform float wind_strength;
global uniform float wetness;
global uniform float leaf_drop;

// Meadow color at a world XZ position. Terrain and grass blades both use it so the
// ground under the grass matches the blades.
vec3 grass_base_color(vec2 xz) {
	float n = fbm2(xz * 0.035);
	float n2 = vnoise2(xz * 0.21 + vec2(3.7, 1.3)) * 0.6 + vnoise2(xz * vec2(0.13, 0.17)) * 0.4;
	vec3 lush = srgb(vec3(0.27, 0.41, 0.14));
	vec3 fresh = srgb(vec3(0.38, 0.50, 0.18));
	vec3 dry = srgb(vec3(0.53, 0.52, 0.28));
	vec3 c = mix(lush, fresh, smoothstep(0.30, 0.60, n));
	c = mix(c, dry, smoothstep(0.62, 0.80, n) * 0.6);
	c *= 0.9 + 0.2 * n2;
	vec3 autumn = srgb(vec3(0.63, 0.57, 0.24));
	c = mix(c, autumn * (0.9 + 0.2 * n2), autumn_amount * 0.65);
	c *= 1.0 - wetness * 0.22;
	return c;
}

vec3 snow_color() {
	return srgb(vec3(0.93, 0.95, 0.99));
}
