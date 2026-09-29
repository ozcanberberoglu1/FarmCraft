// Window pane of old sheet glass. Straight on it shows a dim view of the room behind;
// toward grazing angles it turns into a mirror of the sky (premultiplied alpha keeps
// the reflection at full strength while the view through fades). `dirt` spreads dust
// and dried rain spots that dull the reflection, thickest along the bottom of the pane
// (its UV v runs up from the bottom edge in metres, as on MeshBuilder boxes); `wobble`
// bends the reflection a little, as old uneven glass does. The value noise comes from
// `noise_tex` (Mats.noise_texture()), as in textured.gdshader.
shader_type spatial;
render_mode blend_premul_alpha, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.42, 0.47, 0.45);
uniform float clarity : hint_range(0.0, 1.0) = 0.62;
uniform float dirt : hint_range(0.0, 1.0) = 0.3;
uniform float wobble : hint_range(0.0, 1.0) = 0.3;
uniform sampler2D noise_tex : hint_default_black, filter_linear, repeat_enable;

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Smooth 3D value noise in 0..1 (see textured.gdshader).
float tnoise(vec3 x) {
	vec3 p = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	vec2 uv = mod(p.xy + vec2(37.0, 17.0) * p.z, 256.0) + f.xy + 0.5;
	float a = textureLod(noise_tex, uv * (1.0 / 256.0), 0.0).r;
	float b = textureLod(noise_tex, (uv + vec2(37.0, 17.0)) * (1.0 / 256.0), 0.0).r;
	return mix(a, b, f.z);
}

void fragment() {
	float d = tnoise(v_wpos * 9.0) * 0.55 + tnoise(v_wpos * 31.0) * 0.45;
	float low = 1.0 - smoothstep(0.0, 0.35, UV.y);
	float grime = dirt * smoothstep(0.35, 0.85, d * (0.75 + 0.5 * low));
	float cosv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - cosv, 5.0);
	// How much of the room behind is hidden: the pane's own tint, more at an angle.
	float cover = clamp(1.0 - clarity + fres * 0.5 + grime * 0.4, 0.0, 1.0);
	vec3 base = mix(tint * 0.08, srgb(vec3(0.46, 0.43, 0.37)), grime);
	ALBEDO = base * cover;
	ALPHA = cover;
	ROUGHNESS = mix(0.03, 0.5, grime) * (1.0 - wetness * 0.5);
	SPECULAR = 0.5;
	vec2 w = vec2(tnoise(v_wpos * vec3(2.3, 1.1, 2.3)), tnoise(v_wpos * vec3(1.7, 2.9, 1.7) + 4.0)) - 0.5;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(w.x, w.y, w.x, 0.0)).xyz * 0.06 * wobble);
}
