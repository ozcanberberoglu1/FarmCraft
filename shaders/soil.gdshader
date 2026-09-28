// Garden bed soil with a per-plot wetness value: wet soil is darker and glossier.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 0.6;
uniform vec3 tint : source_color = vec3(1.0);
instance uniform float wet = 0.0;

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 col = texture(albedo_tex, uv).rgb * tint;
	float w = clamp(max(wet, wetness), 0.0, 1.0);
	col *= mix(1.0, 0.52, w);
	col = mix(col, col * vec3(0.95, 0.9, 0.85), w);
	col = mix(col, snow_color(), snow_amount * 0.9);
	ALBEDO = col;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = mix(1.2, 0.7, w);
	ROUGHNESS = mix(0.95, 0.42, w);
	SPECULAR = mix(0.25, 0.55, w);
}
