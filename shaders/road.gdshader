// Asphalt county road: Poly Haven asphalt, worn by traffic. Wheel paths are polished
// a shade darker with an oil-stained strip between them, repair patches of newer
// asphalt with tar-sealed seams sit here and there, a sealed crack wanders along the
// centre joint, the edges crumble into the gravel shoulder under a film of dust, and
// the painted lines are faded and scuffed where tyres cross them. Darker and glossier
// when wet, with water standing in the wheel paths. UV.x = metres across from the
// left edge (negative / past road_width on the shoulders), UV.y = metres along.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 0.25;
uniform float gravel_scale = 0.33;
uniform float road_width = 7.0;
uniform vec3 line_color : source_color = vec3(0.86, 0.85, 0.8);
uniform vec3 centre_color : source_color = vec3(0.86, 0.68, 0.22);
uniform vec3 dust_color : source_color = vec3(0.47, 0.42, 0.34);

float band(float x, float centre, float half_width, float aa) {
	return 1.0 - smoothstep(half_width - aa, half_width + aa, abs(x - centre));
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 albedo = texture(albedo_tex, uv).rgb;
	vec3 arm = texture(arm_tex, uv).rgb;
	vec3 nmap = texture(normal_tex, uv).rgb;
	float aa = fwidth(UV.x) * 1.5 + 0.004;
	float big = vnoise2(UV * vec2(0.09, 0.03));
	float fine = vnoise2(UV * vec2(1.7, 0.6));
	// Large-scale variation so the tiling doesn't show; weathered a shade darker.
	albedo *= (0.86 + 0.26 * big) * 0.88;

	// Traffic: two wheel paths per lane, polished and darker, oil between them.
	float lane_w = road_width * 0.5;
	float lx = mod(UV.x, lane_w);
	float wheels = band(lx, lane_w * 0.5 - 0.85, 0.3, 0.25) + band(lx, lane_w * 0.5 + 0.85, 0.3, 0.25);
	float oil = band(lx, lane_w * 0.5, 0.22, 0.2) * (0.6 + 0.4 * fine);
	albedo *= 1.0 - 0.1 * wheels - 0.14 * oil;

	// Repair patches: one cell every 19 m, a patch over part of one lane in about half.
	float cell = floor(UV.y / 19.0);
	float h = hash12(vec2(cell, 3.7));
	float y0 = cell * 19.0 + 2.0 + hash12(vec2(cell, 9.1)) * 8.0;
	float y1 = y0 + 1.6 + hash12(vec2(cell, 5.3)) * 5.0;
	float x0 = (h > 0.78 ? lane_w : 0.0) + 0.4 + hash12(vec2(cell, 1.9)) * 0.9;
	float x1 = min(x0 + 1.4 + hash12(vec2(cell, 7.7)) * 1.6, road_width - 0.3);
	float px_ = min(UV.x - x0, x1 - UV.x);
	float py_ = min(UV.y - y0, y1 - UV.y);
	float in_patch = step(0.55, h) * step(0.0, min(px_, py_));
	float seam = step(0.55, h) * (1.0 - smoothstep(0.02, 0.05, abs(min(px_, py_)))) * step(-0.05, min(px_, py_));
	albedo = mix(albedo, albedo * vec3(0.68, 0.69, 0.72), in_patch);
	// A sealed crack wandering along the centre joint, here and there.
	float crack_x = road_width * 0.5 + 0.18 + sin(UV.y * 0.13) * 0.12 + (fine - 0.5) * 0.12;
	float crack = band(UV.x, crack_x, 0.018, aa) * smoothstep(0.45, 0.6, vnoise2(vec2(UV.y * 0.05, 2.0)));
	float tar = clamp(seam + crack, 0.0, 1.0);
	albedo = mix(albedo, vec3(0.018, 0.018, 0.02), tar * 0.85);

	// Painted lines, faded and scuffed.
	float edges = band(UV.x, 0.35, 0.07, aa) + band(UV.x, road_width - 0.35, 0.07, aa);
	float dash = step(fract(UV.y / 9.0), 0.4);
	float centre = band(UV.x, road_width * 0.5, 0.06, aa) * dash;
	float wear = smoothstep(0.2, 0.8, vnoise2(UV * vec2(2.3, 0.7)) * 0.7 + fine * 0.3);
	edges *= 0.45 + 0.4 * wear;
	centre *= (0.5 + 0.4 * wear) * (1.0 - in_patch);
	albedo = mix(albedo, line_color * 0.82, clamp(edges, 0.0, 1.0));
	albedo = mix(albedo, centre_color * 0.8, clamp(centre, 0.0, 1.0));
	float paint = clamp(edges + centre, 0.0, 1.0);

	// Crumbling edges into the gravel shoulder, under dust blown off the verge.
	float edge_d = min(UV.x, road_width - UV.x);
	float asphalt = smoothstep(-0.02, 0.1, edge_d - 0.22 * (1.0 - fine) * (0.5 + big) + 0.12);
	vec3 gravel = texture(gravel_tex, UV * gravel_scale).rgb * vec3(0.7, 0.68, 0.66);
	vec3 gn = texture(gravel_nor, UV * gravel_scale).rgb;
	float dust = (1.0 - smoothstep(0.1, 0.9, edge_d + (big - 0.5) * 0.6)) * 0.45;
	albedo = mix(albedo, dust_color * (0.8 + 0.3 * fine), dust * (1.0 - paint * 0.5));
	albedo = mix(gravel, albedo, asphalt);

	// Rain: darker and glossier, water standing in the wheel paths.
	float puddle = wetness * smoothstep(0.55, 0.8, wheels * (0.55 + 0.6 * fine)) * asphalt;
	float snow = snow_amount * 0.85;
	albedo = mix(albedo, snow_color(), snow);
	ALBEDO = albedo * (1.0 - wetness * 0.35) * (1.0 - puddle * 0.25);
	float rough = mix(clamp(arm.g, 0.3, 1.0), 0.55, paint);
	rough = mix(rough, 0.62, in_patch);
	rough *= 1.0 - 0.12 * wheels;
	rough = mix(rough, 0.35, tar);
	rough = mix(0.95, rough, asphalt);
	ROUGHNESS = mix(rough * mix(1.0, 0.3, wetness), 0.04, puddle);
	AO = mix(1.0, arm.r, 0.6);
	NORMAL_MAP = mix(gn, nmap, asphalt);
	NORMAL_MAP_DEPTH = mix(1.0, 0.3, max(paint, in_patch * 0.6)) * (1.0 - puddle);
	SPECULAR = mix(0.4, 0.7, wetness);
}
