// Grass blades rendered with MultiMesh. UV.y = height along the blade (0 root, 1 tip),
// UV.x = blade height in meters (used to shrink blades into the ground far away).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

#include "res://shaders/include/nature.gdshaderinc"

uniform float fade_start = 30.0;
uniform float fade_end = 42.0;
uniform float bend = 0.16;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float ground_scale = 0.33;
uniform vec3 ground_tint : source_color = vec3(0.7, 1.0, 0.52);

varying float v_h;
varying vec3 v_base;

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
		// Blades take the (blurred) color of the ground texture under them so meadow and
		// terrain match; a hue jitter per clump adds variety.
		vec3 ground = textureLod(ground_tex, root.xz * ground_scale, 6.0).rgb * ground_tint;
		float jitter = hash12(root.xz * 1.37);
		v_base = mix(ground, grass_base_color(root.xz), 0.35) * (0.85 + 0.3 * jitter);
		// Autumn and winter dry the grass to straw.
		vec3 straw = srgb(vec3(0.62, 0.55, 0.3)) * (0.8 + 0.4 * jitter);
		v_base = mix(v_base, straw, autumn_amount * 0.6);
	}
}

void fragment() {
	vec3 tip = v_base * 1.3 + srgb(vec3(0.05, 0.06, 0.0));
	vec3 col = mix(v_base * 0.6, tip, v_h);
	col = mix(col, snow_color(), snow_amount * smoothstep(0.35, 1.0, v_h));
	ALBEDO = col;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	AO = mix(0.6, 1.0, v_h);
	AO_LIGHT_AFFECT = 0.2;
	BACKLIGHT = col * 0.3;
	// Blades use an up-facing normal on both sides for soft, even lighting.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
