// Stylized pond water: depth-tinted, transparent in the shallows, foam at the shore,
// animated ripples that pick up sky reflections.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform vec3 shallow_color : source_color = vec3(0.24, 0.38, 0.32);
uniform vec3 deep_color : source_color = vec3(0.05, 0.13, 0.15);
uniform float depth_range = 1.8;
uniform float foam_range = 0.25;
uniform float ripple_strength = 0.18;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 v_wpos;

float ripple(vec2 p, float t) {
	return vnoise2(p * 0.9 + vec2(t * 0.25, t * 0.1))
			+ vnoise2(p * 2.3 - vec2(t * 0.2, t * 0.33)) * 0.5
			+ vnoise2(p * 5.1 + vec2(t * 0.4, -t * 0.2)) * 0.2;
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec2 p = v_wpos.xz;
	float e = 0.06;
	float h = ripple(p, t);
	float hx = ripple(p + vec2(e, 0.0), t);
	float hz = ripple(p + vec2(0.0, e), t);
	float k = ripple_strength * (1.0 + wetness * 1.5);
	vec3 n_world = normalize(vec3((h - hx) / e * k, 1.0, (h - hz) / e * k));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float water_depth = max(VERTEX.z - view.z, 0.0);
	float d = clamp(water_depth / depth_range, 0.0, 1.0);

	vec3 col = mix(shallow_color, deep_color, d);
	float foam = 1.0 - smoothstep(0.0, foam_range, water_depth);
	foam *= 0.55 + 0.45 * vnoise2(p * 3.5 + vec2(t * 0.4, t * 0.3));
	col = mix(col, vec3(0.75, 0.78, 0.74), foam * 0.35);
	col = mix(col, snow_color() * 0.85, snow_amount * 0.9);

	ALBEDO = col;
	ALPHA = clamp(mix(0.35, 0.95, d) + foam * 0.2 + snow_amount, 0.0, 1.0);
	ROUGHNESS = mix(0.05, 0.5, snow_amount);
	SPECULAR = 0.6;
}
