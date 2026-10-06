// Crown of the photo trees (NatureModels.tree): a cloud of cards, each showing a cluster
// of the real tree's twigs and leaves rendered along the card's facing
// (tools/blender/build_trees.py): colour with the crown's self-shading baked in, cut out
// by alpha, and a normal map of the real leaves. Lighting mixes each leaf's own normal
// with the crown's rounded one (UV2, octahedral), so the crown shades as one volume
// with leaf detail in it; light shines through the leaves from behind.
// Vertex COLOR: r = openness (share of the sky seen there), g/b/a = wind (tree_wind).
// Body of tree_leaves.gdshader. (A felled tree's crown is never cut: all of it goes
// over with the trunk, see tree_cut.gdshaderinc.)
#include "res://shaders/include/nature.gdshaderinc"
#include "res://shaders/include/tree_wind.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float alpha_cut = 0.5;
// How fast the cut-out thickens with distance (mip level), so far crowns stay full.
uniform float mip_alpha = 0.3;
uniform float tex_size = 4096.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float brightness = 1.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.5;
// Share of the crown's rounded normal in the lighting normal.
uniform float crown_blend : hint_range(0.0, 1.0) = 0.45;
// Cards seen nearly edge-on (|cos| of the view angle under this) thin away: the
// crossing card of the same cluster shows it there.
uniform float edge_fade = 0.22;
// 1 for deciduous leaves (autumn colour, leaf fall).
uniform float deciduous : hint_range(0.0, 1.0) = 0.0;
// Past the sun's shadows the crown shades itself: the openness darkens the direct light
// by pow(open, shade_far), fading in over shade_range (m).
uniform vec2 shade_range = vec2(100.0, 120.0);
uniform float shade_far = 1.2;
// Ambient occlusion from the openness (the colour already carries most of it).
uniform float ao_amount : hint_range(0.0, 1.0) = 0.35;
uniform float specular : hint_range(0.0, 1.0) = 0.25;
// Mip levels the cut-out is blurred by in the shadow pass.
uniform float shadow_blur = 2.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.75;

varying vec3 v_crown;
varying vec4 v_col;
varying float v_up;

vec3 octa_decode(vec2 e) {
	e = e * 2.0 - 1.0;
	vec3 n = vec3(e.x, 1.0 - abs(e.x) - abs(e.y), e.y);
	if (n.y < 0.0) {
		n.xz = (1.0 - abs(n.zx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.z >= 0.0 ? 1.0 : -1.0);
	}
	return normalize(n);
}

void vertex() {
	vec3 crown = octa_decode(UV2);
	v_col = COLOR;
	VERTEX += tree_wind(VERTEX, COLOR, MODEL_MATRIX, TIME);
	v_crown = normalize((MODELVIEW_MATRIX * vec4(crown, 0.0)).xyz);
	v_up = normalize((MODEL_MATRIX * vec4(crown, 0.0)).xyz).y;
}

void fragment() {
	if (deciduous > 0.5 && v_col.b < leaf_drop) {
		discard;
	}
	vec4 tex = texture(albedo_tex, UV);
	vec2 dx = dFdx(UV * tex_size);
	vec2 dy = dFdy(UV * tex_size);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	float alpha = tex.a * (1.0 + lod * mip_alpha);
	float facing = abs(dot(NORMAL, VIEW));
	if (IN_SHADOW_PASS) {
		// A shadow map texel is bigger than a needle or leaf: the cut-out is read
		// blurred, so the crown casts dappled shade, not speckle.
		alpha = textureLod(albedo_tex, UV, shadow_blur).a * 1.4;
	} else {
		alpha *= smoothstep(edge_fade * 0.3, edge_fade, facing);
	}
	vec3 nm = texture(normal_tex, UV).xyz * 2.0 - 1.0;
	// Seen from behind, the card shows the cluster mirrored.
	if (!FRONT_FACING) {
		nm.xy = -nm.xy;
	}
	vec3 leaf_n = normalize(TANGENT * nm.x + BINORMAL * nm.y + NORMAL * nm.z);
	vec3 n = normalize(mix(leaf_n, v_crown, crown_blend));

	float open = clamp(v_col.r, 0.03, 1.0);
	float far = smoothstep(shade_range.x, shade_range.y, length(VERTEX));
	vec3 col = tex.rgb * tint * brightness * mix(1.0, pow(open, shade_far), far);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 autumn = mix(srgb(vec3(0.78, 0.33, 0.07)), srgb(vec3(0.9, 0.66, 0.14)), v_col.b);
	col = mix(col, autumn * (0.35 + lum * 2.4), autumn_amount * deciduous);
	float snow = clamp((v_up - 0.1) * 2.0, 0.0, 1.0) * snow_amount * smoothstep(0.2, 0.6, open);
	col = mix(col, snow_color(), snow);

	NORMAL = n;
	ALBEDO = col * (1.0 - wetness * 0.15);
	AO = mix(1.0, open, ao_amount);
	AO_LIGHT_AFFECT = 0.0;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA_ANTIALIASING_EDGE = 0.0;
	ROUGHNESS = mix(roughness, 0.4, wetness);
	// No sheen where the crown turns away from the camera (against the sun it would
	// blow up into grey leaves).
	SPECULAR = specular * clamp(dot(v_crown, VIEW) * 2.0 + 0.3, 0.0, 1.0);
	BACKLIGHT = col * translucency * (0.4 + 0.6 * open);
}
