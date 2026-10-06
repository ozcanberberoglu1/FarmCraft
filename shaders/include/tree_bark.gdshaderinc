// Trunk and limbs of the photo trees (NatureModels.tree): the source model's bark maps
// (colour, OpenGL normal, ARM = occlusion / roughness / metal) on its own UVs, moving in
// the wind with the crown (tree_wind). Vertex COLOR r = openness: limbs deep in the
// crown get less sky light. Body of tree_bark.gdshader and, with TREE_CUT defined, of
// tree_bark_cut.gdshader: one side of a felled tree's cut trunk (tree_cut.gdshaderinc),
// drawn two-sided so that inside the bark, seen through the opening, the cut face shows.

#include "res://shaders/include/nature.gdshaderinc"
#include "res://shaders/include/tree_wind.gdshaderinc"
#ifdef TREE_CUT
#include "res://shaders/include/tree_cut.gdshaderinc"
#endif

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// A trunk whose foot is a photo-scan (its own texture atlas, the maps above) wears the
// tree's plain, tiling bark higher up, as the model has it: these maps, wherever the
// UVs lie past upper_from in V (NatureModels moves that part of the trunk there). The
// atlas shown on those UVs instead is stripes and leaf litter from chest height up.
uniform sampler2D upper_albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D upper_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D upper_arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float upper_from = 1000000.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float normal_strength = 1.2;
// Share of the openness (vertex colour) used as ambient occlusion.
uniform float crown_ao : hint_range(0.0, 1.0) = 0.35;

varying float v_open;
varying vec3 v_wnormal;
#ifdef TREE_CUT
// The vertex in the mesh's space, before the wind.
varying vec3 v_lp;
#endif

void vertex() {
#ifdef TREE_CUT
	v_lp = VERTEX;
#endif
	v_open = COLOR.r;
	VERTEX += tree_wind(VERTEX, COLOR, MODEL_MATRIX, TIME);
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
#ifdef TREE_CUT
	vec3 cs = cut_space(v_lp);
	if (!cut_keeps(cs)) {
		discard;
	}
#endif
	// (Gradients taken before the branch: which bark it is changes from one triangle to
	// the next.)
	vec2 uv_dx = dFdx(UV);
	vec2 uv_dy = dFdy(UV);
	bool upper = UV.y > upper_from;
	vec3 col = (upper ? textureGrad(upper_albedo_tex, UV, uv_dx, uv_dy).rgb : textureGrad(albedo_tex, UV, uv_dx, uv_dy).rgb) * tint;
	vec3 arm = upper ? textureGrad(upper_arm_tex, UV, uv_dx, uv_dy).rgb : textureGrad(arm_tex, UV, uv_dx, uv_dy).rgb;
	float snow = smoothstep(0.35, 0.8, v_wnormal.y) * snow_amount;
	col = mix(col * (1.0 - wetness * 0.35), snow_color(), snow);
	ALBEDO = col;
	NORMAL_MAP = upper ? textureGrad(upper_normal_tex, UV, uv_dx, uv_dy).rgb : textureGrad(normal_tex, UV, uv_dx, uv_dy).rgb;
	NORMAL_MAP_DEPTH = normal_strength * (1.0 - snow * 0.7);
	ROUGHNESS = mix(clamp(arm.g, 0.4, 1.0), 0.35, wetness);
	SPECULAR = 0.35;
	AO = arm.r * mix(1.0, clamp(v_open, 0.05, 1.0), crown_ao);
	AO_LIGHT_AFFECT = 0.0;
#ifdef TREE_CUT
	// Inside the bark, seen through the opening: the cut face, lit where it lies. (Its
	// depth stays the bark's behind it: a written DEPTH would come out in front of the
	// bark round the rim, and Metal has no pipeline for it in every pass.)
	if (!FRONT_FACING && !IN_SHADOW_PASS) {
		mat3 basis = mat3(MODEL_MATRIX);
		vec3 cam = transpose(basis) * (CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz) / dot(basis[0], basis[0]);
		vec3 hit;
		if (cut_hit(cut_space(cam), cs, hit)) {
			float rough;
			float ao;
			ALBEDO = cut_wood_color(hit, rough, ao) * (1.0 - wetness * 0.3);
			ROUGHNESS = mix(rough, 0.45, wetness);
			AO = ao;
			AO_LIGHT_AFFECT = 0.2;
			SPECULAR = 0.35;
			NORMAL = normalize(mat3(VIEW_MATRIX) * (basis * cut_dir_to_mesh(cut_normal(hit.xz))));
			NORMAL_MAP_DEPTH = 0.0;
			LIGHT_VERTEX = (VIEW_MATRIX * (MODEL_MATRIX * vec4(cut_to_mesh(hit), 1.0))).xyz;
		} else {
			ALBEDO *= 0.3;
		}
	}
#endif
}
