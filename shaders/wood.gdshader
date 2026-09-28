// Procedural planks. Mesh UVs are in meters: U runs along the plank, V across.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform float plank_width = 0.26;
uniform float seam_width = 0.05;
uniform float seam_darkness : hint_range(0.0, 1.0) = 0.45;
uniform float grain_strength = 0.18;
uniform float plank_variation = 0.22;
uniform float plank_length = 2.4;
uniform float roughness : hint_range(0.0, 1.0) = 0.82;
uniform float snow_accumulates : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_wpos;
varying vec3 v_wnormal;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV;
	float row = floor(uv.y / plank_width);
	float across = fract(uv.y / plank_width);
	// Staggered butt joints along each plank row.
	float along = uv.x / plank_length + hash12(vec2(row, 7.3)) * 3.0;
	float plank_id = row * 31.0 + floor(along);
	float joint = fract(along);
	float seam_v = smoothstep(0.0, seam_width, across) * smoothstep(1.0, 1.0 - seam_width, across);
	float seam_u = smoothstep(0.0, 0.012, joint) * smoothstep(1.0, 0.988, joint);
	float seam = min(seam_v, seam_u);

	float tint = 1.0 + (hash12(vec2(plank_id, 1.7)) - 0.5) * 2.0 * plank_variation;
	float grain = vnoise2(vec2(uv.x * 1.2 + plank_id * 3.1, uv.y * 38.0));
	float streak = vnoise2(vec2(uv.x * 0.25 + plank_id, uv.y * 9.0));
	float g = mix(grain, streak, 0.5);

	vec3 col = COLOR.rgb * tint * (1.0 + (g - 0.5) * 2.0 * grain_strength);
	col *= mix(1.0 - seam_darkness, 1.0, seam);

	float snow = clamp((v_wnormal.y - 0.55) * 4.0, 0.0, 1.0) * snow_amount * snow_accumulates;
	col = mix(col, snow_color(), snow);
	float wet = wetness * snow_accumulates;
	ALBEDO = col * (1.0 - wet * 0.3);
	ROUGHNESS = mix(roughness, 0.4, wet * 0.6);
	SPECULAR = 0.3;
}
