// Garden bed soil (FarmPlot) with a per-bed wetness value. The soil photo is laid out
// in world space, so no two beds look alike. Watered soil turns dark and glossy, the
// furrows first (they hold the water); dry packed soil gets a pale crust on its humps.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 0.6;
uniform vec3 tint : source_color = vec3(1.0);
// Bed-local soil heights of the furrow bottoms and the ridge crowns.
uniform float furrow_y = 0.1;
uniform float crown_y = 0.17;
// Pale dry crust on packed soil (0..1).
uniform float crust = 0.0;
instance uniform float wet = 0.0;

varying vec3 v_wpos;
varying float v_y;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_y = VERTEX.y;
}

void fragment() {
	vec2 uv = v_wpos.xz * uv_scale;
	vec3 col = texture(albedo_tex, uv).rgb * tint;
	float n = vnoise2(v_wpos.xz * 3.1);
	col *= 0.88 + 0.24 * n;
	float low = 1.0 - smoothstep(furrow_y, crown_y, v_y);
	float w = clamp(max(wet, wetness), 0.0, 1.0);
	float soak = clamp(w * (0.7 + 0.6 * low) * (0.85 + 0.3 * n), 0.0, 1.0);
	col = mix(col, col * vec3(1.3, 1.24, 1.16), crust * (1.0 - w) * (1.0 - low) * smoothstep(0.35, 0.75, n));
	col *= mix(1.0, 0.45, soak);
	col = mix(col, snow_color(), snow_amount * 0.9);
	ALBEDO = col;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = mix(1.4, 0.7, soak);
	ROUGHNESS = mix(0.96, 0.55, soak) - 0.25 * smoothstep(0.85, 1.0, soak) * low;
	SPECULAR = mix(0.25, 0.4, soak);
}
