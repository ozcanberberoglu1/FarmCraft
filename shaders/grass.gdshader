// Geometry grass blades (tall wild grass patches, pond reeds) rendered with MultiMesh.
// UV.y = height along the blade (0 root, 1 tip), UV.x = blade height in meters (used
// to shrink blades into the ground far away). Vertex COLOR tints a blade (white = as
// is; the reeds' cattail heads are brown).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

#include "res://shaders/include/nature.gdshaderinc"

uniform float fade_start = 30.0;
uniform float fade_end = 42.0;
uniform float bend = 0.16;
// Kept for the materials that set it; the colour now comes from blade_color.
uniform sampler2D ground_tex : source_color, filter_linear_mipmap, repeat_enable;
// Mid-blade colour of a lush clump (sRGB); tips are paler and a little dry, roots dark.
uniform vec3 blade_color : source_color = vec3(0.34, 0.4, 0.17);
uniform vec3 tip_color : source_color = vec3(0.54, 0.51, 0.3);
// How far toward straw the tips of a clump can go (0..1).
uniform float dry_tips = 0.55;
// Roughness of soaked blades: a soft sheen at grazing angles, never a mirror of the sky.
uniform float wet_roughness : hint_range(0.3, 1.0) = 0.62;

varying float v_h;
varying vec3 v_base;
varying vec3 v_tip;

void vertex() {
	v_h = UV.y;
	// Far away, shrink the whole clump into its root so nothing is left lying flat.
	vec3 root = MODEL_MATRIX[3].xyz;
	float keep = 1.0 - smoothstep(fade_start, fade_end, distance(root, CAMERA_POSITION_WORLD));
	// Snow buries the grass: blades shrink toward their roots.
	keep *= 1.0 - snow_amount * 0.8;
	if (keep <= 0.0) {
		// Fully shrunk: every vertex sits on the root, so the wind and colour work is skipped.
		VERTEX = root;
		v_base = vec3(0.0);
		v_tip = vec3(0.0);
	} else {
		vec3 wp = VERTEX;
		float t = TIME;
		float gust = vnoise2(wp.xz * 0.06 + vec2(t * 0.35, t * 0.12));
		float w = sin(t * 1.7 + wp.x * 0.33 + wp.z * 0.21) * 0.5
				+ sin(t * 2.9 + wp.x * 0.9 - wp.z * 0.6) * 0.25
				+ (gust - 0.4) * 1.3;
		vec2 disp = vec2(0.8, 0.45) * w * bend * wind_strength * v_h * v_h;
		VERTEX.xz += disp;
		VERTEX.y -= length(disp) * 0.35;
		VERTEX = mix(root, VERTEX, keep);
		// Each clump and each blade its own shade; some clumps drier than others.
		float jitter = hash12(root.xz * 1.37);
		float blade = hash12(vec2(UV.x * 37.0, jitter * 11.0));
		v_base = blade_color * COLOR.rgb * (0.8 + 0.3 * jitter) * (0.85 + 0.3 * blade);
		v_tip = mix(blade_color, tip_color, dry_tips * (0.4 + 0.6 * jitter)) * COLOR.rgb;
		// Autumn and winter dry the grass to straw.
		vec3 straw = srgb(vec3(0.58, 0.52, 0.32)) * (0.8 + 0.4 * jitter) * COLOR.rgb;
		v_base = mix(v_base, straw, autumn_amount * 0.6);
		v_tip = mix(v_tip, straw, autumn_amount * 0.7);
	}
}

void fragment() {
	vec3 col = mix(v_base * 0.55, v_base, smoothstep(0.0, 0.45, v_h));
	col = mix(col, v_tip, smoothstep(0.55, 1.0, v_h));
	col = mix(col, snow_color(), snow_amount * smoothstep(0.35, 1.0, v_h));
	// Wet grass is darker and deeper in colour, not brighter.
	float grey = dot(col, vec3(0.3, 0.59, 0.11));
	ALBEDO = mix(vec3(grey), col, 1.0 + 0.25 * wetness) * (1.0 - wetness * 0.18);
	ROUGHNESS = mix(0.78, wet_roughness, wetness);
	METALLIC = 0.0;
	SPECULAR = mix(0.25, 0.18, wetness);
	AO = mix(0.55, 1.0, v_h);
	AO_LIGHT_AFFECT = 0.2;
	BACKLIGHT = col * 0.35;
	// Blades use an up-facing normal on both sides for soft, even lighting.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
