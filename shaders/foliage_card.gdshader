// Alpha-tested leaf / needle cards using photo-scanned foliage atlases.
// Vertex COLOR.rgb tints the card (0.5 grey = unchanged), COLOR.a = sway weight.
// Normals come from the mesh (pointing out of the crown) on both faces, which gives
// soft, volumetric-looking lighting; the atlas normal map adds leaf detail.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float alpha_cut = 0.42;
uniform vec3 tint : source_color = vec3(1.0);
uniform float brightness = 1.0;
uniform float sway_amount = 0.12;
uniform float flutter = 0.025;
uniform float autumn_factor : hint_range(0.0, 1.0) = 1.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.45;
uniform float tex_size = 2048.0;
uniform float normal_strength = 0.6;
// 1 for deciduous leaves (they fall in late autumn/winter), 0 for needles and crops.
uniform float deciduous : hint_range(0.0, 1.0) = 0.0;
// Far forest trees have no shadows: their cards carry a crown-depth shade in the
// vertex colour (darker = deeper inside), used here as ambient occlusion so the sky
// and GI light is kept out of the crown like on the shadowed trees. 0 = off.
uniform float crown_ao : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_wpos;
varying vec3 v_wnormal;
varying float v_rand;
varying float v_card;

void vertex() {
	// VERTEX and NORMAL are already in world space, so the wind offset is added as is.
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 wp = VERTEX;
	float sway = COLOR.a;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float t = TIME;
	float gust = vnoise2(origin.xz * 0.02 + vec2(t * 0.12, t * 0.05));
	vec3 offs = vec3(sin(t * 0.9 + phase), 0.0, cos(t * 0.7 + phase * 1.3)) * (0.5 + gust);
	offs *= sway * sway_amount;
	offs += vec3(sin(t * 5.3 + wp.x * 3.1 + wp.y * 2.3), sin(t * 4.7 + wp.z * 2.9) * 0.4,
			cos(t * 6.1 + wp.y * 3.3 + wp.z)) * flutter * sway;
	offs *= wind_strength;
	VERTEX += offs;
	v_wpos = wp;
	v_wnormal = normalize(NORMAL);
	v_rand = hash12(origin.xz * 0.731);
	// Each card has its own slightly random tint, which doubles as a per-card id.
	v_card = fract(dot(COLOR.rgb, vec3(91.7, 57.3, 23.1)) * 13.0 + v_rand);
}

void fragment() {
	if (deciduous > 0.5 && v_card < leaf_drop) {
		discard;
	}
	vec4 tex = texture(albedo_tex, UV);
	// Mip-aware alpha: keeps distant canopies from thinning out.
	vec2 dx = dFdx(UV * tex_size);
	vec2 dy = dFdy(UV * tex_size);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	float alpha = tex.a * (1.0 + lod * 0.3);

	vec3 card_tint = pow(max(COLOR.rgb, vec3(0.0)), vec3(1.0 / 2.2)) * 2.0;
	vec3 col = tex.rgb * tint * card_tint * brightness;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 autumn = mix(srgb(vec3(0.78, 0.33, 0.07)), srgb(vec3(0.9, 0.66, 0.14)), v_rand);
	col = mix(col, autumn * (0.35 + lum * 2.4), autumn_amount * autumn_factor);
	float up = v_wnormal.y;
	float snow = clamp((up - 0.2) * 2.5, 0.0, 1.0) * snow_amount;
	col = mix(col, snow_color(), snow);

	// Keep the crown normal on both faces (don't flip for back faces).
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ALBEDO = col * (1.0 - wetness * 0.15);
	float open = clamp(dot(card_tint, vec3(1.0 / 3.0)), 0.0, 1.0);
	AO = mix(1.0, open * open, crown_ao);
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA_ANTIALIASING_EDGE = 0.2;
	ROUGHNESS = mix(0.78, 0.4, wetness);
	SPECULAR = 0.18;
	BACKLIGHT = col * translucency;
}
