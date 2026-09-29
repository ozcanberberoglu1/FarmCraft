// Ground fields shared by the terrain and the meadow grass (set by
// TerrainData.apply_ground_fields): where the meadow is damp, trampled or dry, and its
// colour there. Evaluated per vertex (terrain grid points, grass roots) so both agree
// and the pixel shaders stay cheap. Include after nature.gdshaderinc.

uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D height_tex : filter_linear_mipmap, repeat_disable;
uniform vec2 map_min = vec2(-150.0);
uniform vec2 map_size = vec2(500.0, 300.0);
uniform float water_level = -0.55;
uniform vec2 pond_center = vec2(-44.0, -4.0);
uniform float pond_radius = 11.0;
uniform float track_reach = 2.5;
// Garden lots (x0, z0, x1, z1): trampled between the beds.
uniform vec4 lots[4];

vec2 mask_uv(vec2 xz) {
	return (xz - map_min) / map_size;
}

// x = damp (hollows, the pond's surroundings), y = worn (near lanes, yards and in the
// garden lots), z = dry (sunny, well-drained patches), w = small-patch noise (clover,
// sparse spots). `h` is the ground height at xz.
vec4 ground_fields(vec2 xz, float h) {
	vec2 uv = mask_uv(xz);
	// Height grid: one texel per metre, texel centres on the grid points.
	vec2 huv = (xz - map_min + 0.5) / (map_size + 1.0);
	float around = textureLod(height_tex, huv, 3.3).r;
	float damp = smoothstep(0.06, 0.45, around - h);
	float pond = length(xz - pond_center) - pond_radius;
	damp = max(damp, 1.0 - smoothstep(0.5, 9.0, pond));
	damp = max(damp, 0.6 * (1.0 - smoothstep(water_level + 0.6, water_level + 1.6, h)));
	// The mask's mip levels blur paths and yards into a few metres of trampled grass.
	vec3 near = textureLod(mask_tex, uv, 3.2).rgb;
	float worn = smoothstep(0.04, 0.35, max(near.r, near.g));
	for (int i = 0; i < 4; i++) {
		vec4 r = lots[i];
		vec2 inside = min(xz - r.xy, r.zw - xz);
		worn = max(worn, smoothstep(-0.5, 1.0, min(inside.x, inside.y)) * 0.75);
	}
	float big = vnoise2(xz * 0.017) * 0.6 + vnoise2(xz * 0.061 + vec2(7.3, 1.9)) * 0.4;
	float dry = smoothstep(0.46, 0.76, big) * (1.0 - damp);
	float small = vnoise2(xz * 0.23 + vec2(3.1, 8.7));
	return vec4(damp, worn, dry, small);
}

// Sunlit meadow albedo (linear) for the ground fields `f` at xz. Targets sRGB about
// (0.30-0.42, 0.38-0.48, 0.14-0.22), darker and bluer where damp, straw where dry.
vec3 meadow_albedo(vec2 xz, vec4 f) {
	vec3 fresh = srgb(vec3(0.34, 0.42, 0.19));
	vec3 lush = srgb(vec3(0.23, 0.33, 0.14));
	vec3 clover = srgb(vec3(0.28, 0.39, 0.2));
	vec3 dry = srgb(vec3(0.47, 0.44, 0.22));
	vec3 worn = srgb(vec3(0.41, 0.40, 0.25));
	float mid = vnoise2(xz * 0.09 + vec2(1.7, 4.2));
	// Tussocks and thinner spots a few metres across: what keeps a pasture from reading
	// as a lawn once the single tufts are too small to see.
	float tussock = vnoise2(xz * 0.31 + vec2(5.2, 3.3));
	vec3 c = mix(fresh, clover, smoothstep(0.55, 0.8, f.w) * 0.8);
	c *= (0.8 + 0.4 * mid) * mix(0.8, 1.08, smoothstep(0.3, 0.7, tussock));
	c = mix(c, dry, f.z * 0.9);
	c = mix(c, lush, f.x);
	c = mix(c, worn, f.y * 0.6);
	vec3 autumn = srgb(vec3(0.55, 0.5, 0.24)) * (0.9 + 0.2 * mid);
	c = mix(c, autumn, autumn_amount * 0.7);
	return c;
}
