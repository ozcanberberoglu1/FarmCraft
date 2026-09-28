// Photo-textured terrain. Layers: meadow grass, hillside grass/rock mix, dirt path,
// dirt yard, pond sand and cliff rock. Placement comes from a world-space mask texture
// (R path, G dirt, B shore) and from slope; each layer is sampled at two scales and
// blended with noise to hide tiling. Normals are combined in world space.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D grass_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D hill_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D hill_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec3 grass_tint : source_color = vec3(0.68, 0.98, 0.5);
uniform float grass_scale = 0.33;
uniform float hill_scale = 0.11;
uniform float path_scale = 0.42;
uniform float dirt_scale = 0.4;
uniform float sand_scale = 0.35;
uniform float rock_scale = 0.12;
uniform float normal_strength = 0.9;
uniform float water_level = -0.55;
uniform vec2 map_min = vec2(-150.0);
uniform vec2 town_center = vec2(232.0, 14.0);
uniform float town_scale = 1.4;
uniform vec2 map_size = vec2(500.0, 300.0);

varying vec3 v_wpos;
varying vec3 v_wnormal;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 nxy(vec4 t) {
	return t.xy * 2.0 - 1.0;
}

// Two-scale sample with a rotated second layer to break up repetition.
vec4 sample2(sampler2D tex, vec2 xz, float scale, float blend) {
	vec2 uv1 = xz * scale;
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * xz * scale * 0.37 + vec2(0.31, 0.77);
	return mix(texture(tex, uv1), texture(tex, uv2), blend);
}

// sample2 for layers that only some pixels use: it runs inside branches, so it takes
// the screen-space gradients of xz (implicit ones are undefined there) and skips the
// tap whose blend weight is 0.
vec4 sample2g(sampler2D tex, vec2 xz, float scale, float blend, vec2 gx, vec2 gy) {
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec4 a = vec4(0.0);
	vec4 b = vec4(0.0);
	if (blend < 1.0) {
		a = textureGrad(tex, xz * scale, gx * scale, gy * scale);
	}
	if (blend > 0.0) {
		float s2 = scale * 0.37;
		b = textureGrad(tex, rot * xz * s2 + vec2(0.31, 0.77), rot * gx * s2, rot * gy * s2);
	}
	return mix(a, b, blend);
}

void fragment() {
	vec2 xz = v_wpos.xz;
	// Taken here, in uniform control flow, for the samples inside branches below.
	vec2 gx = dFdx(xz);
	vec2 gy = dFdy(xz);
	vec3 px = dFdx(v_wpos);
	vec3 py = dFdy(v_wpos);
	vec3 geo_n = normalize(v_wnormal);
	vec3 m = texture(mask_tex, (xz - map_min) / map_size).rgb;
	float macro = fbm2(xz * 0.03);
	float blend = smoothstep(0.35, 0.65, vnoise2(xz * 0.09));
	float slope = 1.0 - geo_n.y;

	// Meadow grass, tinted toward a fresh green and varied at a large scale.
	vec3 grass = sample2(grass_diff, xz, grass_scale, blend).rgb * grass_tint;
	grass = mix(grass, grass * grass_base_color(xz) * 3.2, 0.35);
	grass *= 0.85 + 0.3 * macro;
	vec2 n_grass = nxy(sample2(grass_nor, xz, grass_scale, blend));
	// Hillside mix: rougher grass with rock showing through, more of it on slopes.
	float valley_d = min(length(xz), length(xz - town_center) * town_scale);
	float hill_w = clamp(smoothstep(0.2, 0.45, macro + slope * 1.6) * 0.8 + smoothstep(60.0, 95.0, valley_d) * 0.5, 0.0, 1.0);
	vec3 hill = texture(hill_diff, xz * hill_scale).rgb * vec3(0.95, 1.0, 0.9);
	vec2 n_hill = nxy(texture(hill_nor, xz * hill_scale));
	vec3 col = mix(grass, hill, hill_w * 0.75);
	vec2 n = mix(n_grass, n_hill, hill_w * 0.75);
	float rough = 0.88;

	// Each layer below is only sampled where its weight can be above 0: the noise that
	// breaks up its edge moves the mask by at most ±0.15 (dirt), ±0.06 (path) and
	// ±0.07 (rock), so outside these ranges the weight is exactly 0.
	float dirt = 0.0;
	if (m.g > 0.15) {
		dirt = smoothstep(0.3, 0.7, m.g + (vnoise2(xz * 0.45) - 0.5) * 0.3);
	}
	if (dirt > 0.0) {
		col = mix(col, sample2g(dirt_diff, xz, dirt_scale, blend, gx, gy).rgb, dirt);
		n = mix(n, nxy(sample2g(dirt_nor, xz, dirt_scale, blend, gx, gy)), dirt);
	}

	float path = 0.0;
	if (m.r > 0.26) {
		path = smoothstep(0.32, 0.62, m.r + (vnoise2(xz * 1.3) - 0.5) * 0.12);
	}
	if (path > 0.0) {
		col = mix(col, sample2g(path_diff, xz, path_scale, blend, gx, gy).rgb, path);
		n = mix(n, nxy(sample2g(path_nor, xz, path_scale, blend, gx, gy)), path);
	}
	rough = mix(rough, 0.92, path);

	float shore = 0.0;
	if (m.b > 0.1) {
		float shore_mask = smoothstep(0.1, 0.9, m.b);
		shore = shore_mask * (1.0 - smoothstep(water_level + 0.3, water_level + 0.95, v_wpos.y));
		col = mix(col, textureGrad(sand_diff, xz * sand_scale, gx * sand_scale, gy * sand_scale).rgb, shore);
		col = mix(col, col * 0.5, shore_mask * (1.0 - smoothstep(water_level - 0.6, water_level + 0.02, v_wpos.y)));
	}

	// Cliffs: biplanar rock projection on steep slopes.
	float rock = 0.0;
	if (slope > 0.35) {
		rock = smoothstep(0.42, 0.6, slope + (vnoise2(xz * 0.4) - 0.5) * 0.14);
	}
	if (rock > 0.001) {
		bool side = abs(geo_n.x) > abs(geo_n.z);
		vec2 uv_side = side ? v_wpos.zy : v_wpos.xy;
		vec2 side_gx = (side ? px.zy : px.xy) * rock_scale;
		vec2 side_gy = (side ? py.zy : py.xy) * rock_scale;
		vec3 rock_col = mix(textureGrad(rock_diff, uv_side * rock_scale, side_gx, side_gy).rgb,
				textureGrad(rock_diff, xz * rock_scale, gx * rock_scale, gy * rock_scale).rgb, geo_n.y);
		col = mix(col, rock_col, rock);
		n = mix(n, nxy(textureGrad(rock_nor, uv_side * rock_scale, side_gx, side_gy)), rock);
	}

	float snow = 0.0;
	if (snow_amount > 0.0) {
		snow = clamp(snow_amount * (1.35 + (vnoise2(xz * 1.7) - 0.5) * 0.4) - slope * 2.2, 0.0, 1.0);
	}
	col = mix(col, snow_color(), snow);
	float grassiness = clamp(1.0 - path - dirt - rock - shore, 0.0, 1.0);
	col = mix(col, col * vec3(1.18, 0.95, 0.55), autumn_amount * 0.55 * grassiness);

	// Tangent-space XY (U = +X, image-up = -Z) to a world-space normal on the terrain.
	vec3 world_n = normalize(geo_n + vec3(n.x, 0.0, -n.y) * normal_strength * (1.0 - snow * 0.7));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);
	ALBEDO = col * (1.0 - wetness * 0.28 * (1.0 - snow));
	ROUGHNESS = mix(mix(rough, 0.5, wetness * 0.6), 0.7, snow);
	SPECULAR = 0.3;
}
