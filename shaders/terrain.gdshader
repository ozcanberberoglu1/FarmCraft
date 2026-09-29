// Photo-textured terrain. The meadow's colour comes from the ground fields shared with
// the grass (include/ground.gdshaderinc: damp hollows, trampled lanes and lots, dry
// patches), worked out per vertex; two different ground photos (leafy grass, and
// grass litter with twigs and dead grass) at different scales and angles give it its
// detail and hide each other's tiling. Past the valley the hills turn to forest floor.
// The mask texture (R path, G dirt yard, B pond shore, A closeness to a vehicle lane's
// centre) places gravel lanes with wheel ruts and a grassy middle strip, packed yard
// dirt and the pond's mud; lanes and yards meet the grass along its blades (height
// blend), not along a line. Normals are combined in world space.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"
#include "res://shaders/include/ground.gdshaderinc"

uniform sampler2D grass_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D litter_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D litter_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

// Average (linear) colours of the meadow photos: the photos only add detail around
// the meadow colour.
uniform vec3 grass_avg = vec3(0.321, 0.236, 0.102);
uniform vec3 litter_avg = vec3(0.293, 0.249, 0.115);
uniform float grass_scale = 0.31;
uniform float litter_scale = 0.12;
uniform float path_scale = 0.33;
uniform float dirt_scale = 0.3;
uniform float mud_scale = 0.45;
uniform float rock_scale = 0.12;
uniform vec3 path_tint = vec3(0.78, 0.74, 0.68);
uniform vec3 dirt_tint = vec3(1.15, 1.12, 1.08);
uniform vec3 forest_floor : source_color = vec3(0.3, 0.29, 0.19);
uniform float normal_strength = 0.9;
uniform vec2 town_center = vec2(232.0, 14.0);
uniform float town_scale = 1.4;

varying vec3 v_wpos;
varying vec3 v_wnormal;
varying vec4 v_fields;
varying vec3 v_meadow;
varying float v_hill;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 xz = v_wpos.xz;
	v_fields = ground_fields(xz, v_wpos.y);
	v_meadow = meadow_albedo(xz, v_fields);
	// Forest floor under the hill forest past the valleys, rough ground on steep slopes.
	float valley_d = min(length(xz), length(xz - town_center) * town_scale);
	float macro = vnoise2(xz * 0.03);
	v_hill = clamp(smoothstep(84.0, 100.0, valley_d + (macro - 0.5) * 16.0)
			+ smoothstep(0.25, 0.5, 1.0 - v_wnormal.y) * 0.6, 0.0, 1.0);
}

vec2 nxy(vec4 t) {
	return t.xy * 2.0 - 1.0;
}

// Photo detail around 1.0: the texture divided by its average colour, `k` = contrast.
vec3 detail(vec3 tex, vec3 avg, float k) {
	return mix(vec3(1.0), tex / avg, k);
}

void fragment() {
	vec2 xz = v_wpos.xz;
	// Taken here, in uniform control flow, for the samples inside branches below.
	vec2 gx = dFdx(xz);
	vec2 gy = dFdy(xz);
	vec3 px = dFdx(v_wpos);
	vec3 py = dFdy(v_wpos);
	vec3 geo_n = normalize(v_wnormal);
	vec4 m = texture(mask_tex, mask_uv(xz));
	vec4 f = v_fields;
	float slope = 1.0 - geo_n.y;
	float blotch = vnoise2(xz * 0.45);

	// Meadow: leafy grass, with litter (dead grass, twigs) in blotches, trampled and
	// dry spots and all over the forest floor.
	vec4 ga = texture(grass_diff, xz * grass_scale);
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec2 lxz = rot * xz * litter_scale + vec2(0.31, 0.77);
	vec4 gb = texture(litter_diff, lxz);
	float litter = clamp(smoothstep(0.45, 0.85, blotch) * 0.6 + f.y * 0.7 + f.z * 0.35 + v_hill, 0.0, 1.0);
	vec3 det = mix(detail(ga.rgb, grass_avg, 1.4), detail(gb.rgb, litter_avg, 1.3), litter);
	// "Height" of the grass photo: blades are its bright parts.
	float blade = clamp(dot(ga.rgb / grass_avg, vec3(0.3, 0.59, 0.11)) - 0.5, 0.0, 1.0);
	// A sward shades itself: darker mottling where the grass is thick, at a few scales.
	float mottle = vnoise2(xz * 0.9 + vec2(4.1, 0.7)) * 0.55 + vnoise2(xz * 2.6) * 0.45;
	vec3 meadow = v_meadow * det * (0.56 + 0.44 * mottle);
	vec3 floor_col = forest_floor * (0.85 + 0.3 * blotch);
	floor_col = mix(floor_col, v_meadow * 0.8, smoothstep(0.55, 0.9, f.w) * 0.5);
	vec3 col = mix(meadow, floor_col * detail(gb.rgb, litter_avg, 1.0), v_hill);
	vec2 n = mix(nxy(texture(grass_nor, xz * grass_scale)), nxy(texture(litter_nor, lxz)), litter);
	float rough = 0.9;
	float grassiness = 1.0;

	// Each layer below is only sampled where its weight can be above 0: the noise that
	// breaks up its edge moves the mask by at most the amounts noted, so outside these
	// ranges the weight is exactly 0.
	float dirt = 0.0;
	if (m.g > 0.12) {
		// ±0.18 noise, then the blades of the grass photo reach over the edge.
		float e = (blotch - 0.5) * 0.24 + (vnoise2(xz * 1.6) - 0.5) * 0.12;
		dirt = smoothstep(0.3, 0.7, m.g + e);
		dirt = clamp((dirt - 0.5) * 2.4 + 0.5 - blade * 0.9, 0.0, 1.0);
	}
	if (dirt > 0.0) {
		vec3 d = textureGrad(dirt_diff, xz * dirt_scale, gx * dirt_scale, gy * dirt_scale).rgb * dirt_tint;
		d *= 0.9 + 0.2 * blotch;
		col = mix(col, d, dirt);
		n = mix(n, nxy(textureGrad(dirt_nor, xz * dirt_scale, gx * dirt_scale, gy * dirt_scale)), dirt);
		rough = mix(rough, 0.93, dirt);
	}

	float path = 0.0;
	float rut = 0.0;
	if (m.r > 0.2) {
		float e = (vnoise2(xz * 1.3) - 0.5) * 0.14 + (blotch - 0.5) * 0.12;
		path = smoothstep(0.32, 0.62, m.r + e);
		path = clamp((path - 0.5) * 2.2 + 0.5 - blade * 0.8, 0.0, 1.0);
		// Vehicle lanes: two wheel ruts of bare packed dirt and a grassy strip between.
		float td = (1.0 - m.a) * track_reach;
		float on_track = step(0.004, m.a);
		rut = (1.0 - smoothstep(0.1, 0.3, abs(td - 0.8))) * on_track;
		float strip = (1.0 - smoothstep(0.2, 0.45, td)) * on_track;
		strip *= smoothstep(0.25, 0.6, vnoise2(xz * vec2(0.9, 0.9) + vec2(9.1, 2.3)) + blade * 0.4);
		path *= 1.0 - strip * 0.9;
	}
	if (path > 0.0) {
		vec3 g = textureGrad(path_diff, xz * path_scale, gx * path_scale, gy * path_scale).rgb * path_tint;
		g *= 0.88 + 0.24 * blotch;
		// Flattened: pebbles in packed dirt, not a rubble field (a low sun would black it out).
		vec2 gn = nxy(textureGrad(path_nor, xz * path_scale, gx * path_scale, gy * path_scale)) * 0.55;
		if (rut > 0.0) {
			// Compacted: gravel pressed into darker dirt, smoother.
			vec3 d = textureGrad(dirt_diff, xz * dirt_scale, gx * dirt_scale, gy * dirt_scale).rgb * dirt_tint;
			g = mix(g, mix(g, d, 0.4) * 0.82, rut * 0.85);
			gn = mix(gn, gn * 0.4, rut);
		}
		col = mix(col, g, path);
		n = mix(n, gn, path);
		rough = mix(rough, mix(0.92, 0.8, rut), path);
	}
	rut *= path;

	float shore = 0.0;
	if (m.b > 0.1) {
		float shore_mask = smoothstep(0.1, 0.9, m.b);
		float hw = v_wpos.y - water_level;
		// Mud from under the water up to about a metre above it, ragged at the top.
		float ragged = (vnoise2(xz * 0.3 + vec2(3.3, 9.9)) - 0.5) * 1.1 + (blotch - 0.5) * 0.4;
		shore = shore_mask * (1.0 - smoothstep(0.12, 0.7, hw + ragged));
		shore = clamp((shore - 0.5) * 2.0 + 0.5 - blade * 0.6 * step(0.25, hw), 0.0, 1.0);
		vec3 mud = textureGrad(mud_diff, xz * mud_scale, gx * mud_scale, gy * mud_scale).rgb;
		col = mix(col, mud * 1.1, shore);
		n = mix(n, nxy(textureGrad(mud_nor, xz * mud_scale, gx * mud_scale, gy * mud_scale)), shore);
		// A dark wet band where the water laps, and the bottom darker and greener with depth.
		float lap = shore_mask * (1.0 - smoothstep(0.0, 0.3, hw + (blotch - 0.5) * 0.12));
		col *= 1.0 - 0.4 * lap;
		rough = mix(mix(rough, 0.8, shore), 0.35, lap);
		float under = 1.0 - smoothstep(-0.8, 0.0, hw);
		col = mix(col, col * vec3(0.5, 0.58, 0.45), under * shore_mask);
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
		col = mix(col, rock_col * 0.85, rock);
		n = mix(n, nxy(textureGrad(rock_nor, uv_side * rock_scale, side_gx, side_gy)), rock);
	}

	float snow = 0.0;
	if (snow_amount > 0.0) {
		snow = clamp(snow_amount * (1.35 + (vnoise2(xz * 1.7) - 0.5) * 0.4) - slope * 2.2, 0.0, 1.0);
	}
	grassiness = clamp(1.0 - path - dirt - rock - shore, 0.0, 1.0);
	col = mix(col, col * vec3(1.12, 0.95, 0.62), autumn_amount * 0.4 * grassiness * (1.0 - v_hill));

	// Rain: darker, glossier ground; puddles gather in the ruts and in damp hollows on bare ground.
	float wet = wetness * (1.0 - snow);
	float puddle = 0.0;
	if (wet > 0.3) {
		float low = max(rut, f.x * (1.0 - grassiness) * 0.8);
		puddle = smoothstep(0.55, 0.75, low * (0.6 + 0.6 * vnoise2(xz * 0.8)) * smoothstep(0.3, 0.8, wet) * 1.3);
	}
	col = mix(col, snow_color(), snow);
	col *= 1.0 - wet * 0.3;
	col = mix(col, col * 0.55, puddle);

	// Tangent-space XY (U = +X, image-up = -Z) to a world-space normal on the terrain.
	vec3 world_n = normalize(geo_n + vec3(n.x, 0.0, -n.y) * normal_strength * (1.0 - snow * 0.7) * (1.0 - puddle));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = mix(mix(mix(rough, 0.5, wet * 0.6), 0.05, puddle), 0.7, snow);
	// Grass keeps little sheen (it turns milky at grazing angles); bare ground more.
	SPECULAR = mix(mix(0.3, 0.12, grassiness * (1.0 - v_hill)), 0.5, puddle);
}
