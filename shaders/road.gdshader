// Asphalt road ribbon: Poly Haven asphalt, painted edge lines and a dashed centre
// line, darker and glossier when wet. UV.x = metres across from the left edge,
// UV.y = metres along the road.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 0.25;
uniform float road_width = 7.0;
uniform vec3 line_color : source_color = vec3(0.92, 0.9, 0.84);
uniform vec3 centre_color : source_color = vec3(0.95, 0.76, 0.22);

float band(float x, float centre, float half_width, float aa) {
	return 1.0 - smoothstep(half_width - aa, half_width + aa, abs(x - centre));
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 albedo = texture(albedo_tex, uv).rgb;
	vec3 arm = texture(arm_tex, uv).rgb;
	// Large-scale variation so the tiling doesn't show.
	albedo *= 0.88 + 0.24 * vnoise2(UV * 0.07);
	float aa = fwidth(UV.x) * 1.5 + 0.004;
	float edges = band(UV.x, 0.35, 0.07, aa) + band(UV.x, road_width - 0.35, 0.07, aa);
	float dash = step(fract(UV.y / 9.0), 0.4);
	float centre = band(UV.x, road_width * 0.5, 0.06, aa) * dash;
	// Worn paint: noisy and thinner where tyres run.
	float wear = smoothstep(0.25, 0.75, vnoise2(UV * vec2(2.0, 0.6)));
	edges *= 0.55 + 0.45 * wear;
	centre *= 0.6 + 0.4 * wear;
	albedo = mix(albedo, line_color * 0.85, clamp(edges, 0.0, 1.0));
	albedo = mix(albedo, centre_color * 0.8, clamp(centre, 0.0, 1.0));
	float paint = clamp(edges + centre, 0.0, 1.0);
	float snow = snow_amount * 0.85;
	albedo = mix(albedo, snow_color(), snow);
	ALBEDO = albedo * (1.0 - wetness * 0.35);
	ROUGHNESS = mix(clamp(arm.g, 0.3, 1.0), 0.55, paint) * mix(1.0, 0.25, wetness);
	AO = mix(1.0, arm.r, 0.6);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = mix(1.0, 0.3, paint);
	SPECULAR = mix(0.4, 0.7, wetness);
}
