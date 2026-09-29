// Distant hill forest: a card that turns to face the camera and shows an unlit
// picture of one of the forest trees (tools/tree_impostors.gd renders the atlas).
// It is lit here with a rounded crown normal so it shades like the leaf-card trees;
// autumn tint, falling leaves, snow and rain follow the same world globals.
// INSTANCE_CUSTOM: x = atlas cell, y = card width, z = card height (metres, before
// the instance scale), w = 1 for broadleaf trees (autumn colours, leaf fall).
shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float cells = 5.0;
uniform float alpha_cut = 0.45;
uniform float brightness = 1.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.4;

varying vec3 v_right;
varying vec3 v_to_cam;
varying float v_rand;
varying float v_broad;
varying float v_across;
varying vec3 v_tint;

void vertex() {
	// VERTEX is already in world space; rebuild it from the card corner (UV) so the
	// card turns about the trunk to face the camera, keeping the instance's scale.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[1].xyz);
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - origin;
	to_cam.y = 0.0;
	to_cam = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	vec2 corner = vec2(UV.x - 0.5, 1.0 - UV.y);
	VERTEX = origin + (right * corner.x * INSTANCE_CUSTOM.y + vec3(0.0, corner.y * INSTANCE_CUSTOM.z, 0.0)) * scale;
	NORMAL = to_cam;
	// Every other tree is the mirror image of its picture, and each has its own shade
	// of green: a forest of a few pictures doesn't repeat.
	float h = hash12(origin.xz * 1.37 + 5.1);
	float u = h < 0.5 ? UV.x : 1.0 - UV.x;
	UV = vec2((INSTANCE_CUSTOM.x + u) / cells, UV.y);
	v_across = corner.x * 2.0;
	float h2 = hash12(origin.xz * 0.53 + 17.3);
	v_tint = vec3(1.0 + (h2 - 0.5) * 0.12, 1.0, 1.0 - (h2 - 0.5) * 0.16) * mix(0.86, 1.1, fract(h * 7.31));
	v_right = right;
	v_to_cam = to_cam;
	v_rand = hash12(origin.xz * 0.731);
	v_broad = INSTANCE_CUSTOM.w;
}

void fragment() {
	vec4 tex = texture(atlas, UV);
	vec3 col = tex.rgb * brightness * v_tint;
	// Leaves are greener than bark: only they take autumn colour, fall and snow.
	float leafy = smoothstep(0.0, 0.04, col.g - col.r * 0.95);
	if (v_broad > 0.5 && leafy > 0.5 && hash12(floor(UV * vec2(1400.0, 520.0)) + v_rand * 37.0) < leaf_drop) {
		discard;
	}
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 autumn = mix(srgb(vec3(0.78, 0.33, 0.07)), srgb(vec3(0.9, 0.66, 0.14)), v_rand);
	col = mix(col, autumn * (0.35 + lum * 2.4), autumn_amount * v_broad * leafy);
	// Snow sits on nearly every twig of the card trees (their cards face up and out);
	// a little texture keeps the covered crowns from looking flat.
	if (snow_amount > 0.0) {
		float patches = smoothstep(0.3, 0.75, vnoise2(UV * vec2(2200.0, 900.0) + v_rand * 11.0));
		col = mix(col, snow_color(), snow_amount * leafy * mix(0.72, 1.0, patches));
	}
	// Rounded crown: across the card the normal turns sideways and a little up.
	vec3 n = normalize(v_to_cam * 0.75 + v_right * v_across * 0.9 + vec3(0.0, 0.3, 0.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = col * (1.0 - wetness * 0.15);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA_ANTIALIASING_EDGE = 0.0;
	ROUGHNESS = mix(0.78, 0.4, wetness);
	SPECULAR = 0.18;
	BACKLIGHT = col * translucency;
}
