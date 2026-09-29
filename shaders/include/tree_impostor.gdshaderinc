// Far trees (shaders/tree_impostor.gdshader, and the backdrop's belt of trees in
// shaders/backdrop_trees.gdshader): a card that turns about the trunk to face the camera
// and shows the tree as seen from that side. The atlas (tools/blender/build_trees.py
// --compose) has one row per tree (NatureModels.TREES) and one column per view, eight
// round the tree, each rendered from the full film model with its crown shading;
// neighbouring views are blended. A normal atlas lights them.
// INSTANCE_CUSTOM: x = atlas row (tree), y = card width, z = card height (metres, before
// the instance scale), w = 1 for broadleaf trees (autumn colours, leaf fall).

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_atlas : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float rows = 9.0;
uniform float views = 8.0;
uniform float alpha_cut = 0.5;
uniform float brightness = 1.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.4;
// Share of a rounded crown normal in the lighting normal.
uniform float crown_blend : hint_range(0.0, 1.0) = 0.4;

varying vec3 v_right;
varying vec3 v_to_cam;
// x = view (0..views round the tree), y = atlas row, z = across the card (-1..1),
// w = random per tree.
varying vec4 v_card;
varying float v_broad;
varying vec3 v_tint;

// Varyings can only be set in vertex() itself: IMPOSTOR_VERTEX turns the unit card
// (x -0.5..0.5 across, y 0..1 up, UV from the top) to the camera and sets them.
#define IMPOSTOR_VERTEX vec3 imp_right; vec3 imp_to_cam; vec4 imp_card; vec3 imp_tint; VERTEX = impostor_vertex(UV, MODEL_MATRIX, INV_VIEW_MATRIX, INSTANCE_CUSTOM, imp_right, imp_to_cam, imp_card, imp_tint); v_right = imp_right; v_to_cam = imp_to_cam; v_card = imp_card; v_tint = imp_tint; v_broad = INSTANCE_CUSTOM.w; NORMAL = imp_to_cam

vec3 impostor_vertex(vec2 uv, mat4 model, mat4 inv_view, vec4 custom, out vec3 right, out vec3 to_cam,
		out vec4 card, out vec3 tint) {
	vec3 origin = model[3].xyz;
	float scale = length(model[1].xyz);
	to_cam = inv_view[3].xyz - origin;
	to_cam.y = 0.0;
	to_cam = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	vec2 corner = vec2(uv.x - 0.5, 1.0 - uv.y);
	// The side of the tree the camera is on, in the tree's own frame (the views are
	// rendered from angle k / views round it, measured from +X towards -Z).
	vec3 local = transpose(mat3(model)) * to_cam;
	float angle = atan(-local.z, local.x);
	float h = hash12(origin.xz * 0.53 + 17.3);
	card = vec4(fract(angle / 6.2831853) * views, custom.x, corner.x * 2.0, hash12(origin.xz * 0.731));
	tint = vec3(1.0 + (h - 0.5) * 0.1, 1.0, 1.0 - (h - 0.5) * 0.14) * mix(0.9, 1.08, fract(h * 7.31));
	return origin + (right * corner.x * custom.y + vec3(0.0, corner.y * custom.z, 0.0)) * scale;
}

vec2 impostor_uv(vec2 uv, float view, float row) {
	return vec2((mod(view, views) + uv.x) / views, (row + uv.y) / rows);
}

// Colour, normal (view space), alpha and backlight of the impostor at card UV `uv`.
void impostor_fragment(vec2 uv, mat4 view_matrix, vec3 right, vec3 to_cam, vec4 card, float broad, vec3 tint,
		out vec3 albedo, out vec3 normal, out float alpha, out vec3 backlight) {
	float k = floor(card.x);
	float t = card.x - k;
	float row = card.y;
	float rnd = card.w;
	vec4 c = mix(texture(atlas, impostor_uv(uv, k, row)), texture(atlas, impostor_uv(uv, k + 1.0, row)), t);
	vec3 nm = mix(texture(normal_atlas, impostor_uv(uv, k, row)).xyz,
			texture(normal_atlas, impostor_uv(uv, k + 1.0, row)).xyz, t) * 2.0 - 1.0;
	vec3 col = c.rgb * brightness * tint;
	// Leaves are greener than bark: only they take autumn colour, fall and snow.
	float leafy = smoothstep(0.0, 0.04, col.g - col.r * 0.95);
	alpha = c.a;
	if (broad > 0.5 && leafy > 0.5 && hash12(floor(uv * vec2(700.0, 1400.0)) + rnd * 37.0) < leaf_drop) {
		alpha = 0.0;
	}
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 autumn = mix(srgb(vec3(0.78, 0.33, 0.07)), srgb(vec3(0.9, 0.66, 0.14)), rnd);
	col = mix(col, autumn * (0.35 + lum * 2.4), autumn_amount * broad * leafy);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 n = normalize(right * nm.x + up * nm.y + to_cam * max(nm.z, 0.05));
	if (snow_amount > 0.0) {
		float patches = smoothstep(0.3, 0.75, vnoise2(uv * vec2(900.0, 1800.0) + rnd * 11.0));
		col = mix(col, snow_color(), snow_amount * leafy * smoothstep(0.0, 0.6, n.y) * mix(0.7, 1.0, patches));
	}
	vec3 round_n = normalize(to_cam * 0.75 + right * card.z * 0.9 + up * 0.3);
	normal = normalize((view_matrix * vec4(normalize(mix(n, round_n, crown_blend)), 0.0)).xyz);
	albedo = col * (1.0 - wetness * 0.15);
	backlight = albedo * translucency;
}
