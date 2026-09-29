// Meadow grass (GrassField): photo-scanned tufts on alpha-tested cards, three crossed
// cards per clump. UV = card atlas (green tufts in the top half, the same tufts dried
// in the bottom half), UV2.x = height up the card (0 root .. 1 top).
// Each clump takes the meadow colour of the ground fields at its root, like the terrain
// under it (include/ground.gdshaderinc): taller and darker in damp hollows, short and
// sparse where trampled, some tufts straw in dry patches and in autumn. With distance
// a growing share of clumps shrinks away while the rest widen, and everything has
// shrunk into its roots by fade_end, where the chunk is cut off.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

#include "res://shaders/include/nature.gdshaderinc"
#include "res://shaders/include/ground.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float fade_start = 42.0;
uniform float fade_end = 58.0;
// Past this distance clumps start thinning out.
uniform float thin_start = 12.0;
uniform float bend = 0.13;
uniform float alpha_cut = 0.4;
uniform float tex_size = 2048.0;
// Average (linear) colour of the green tufts: the photo adds detail around the meadow colour.
uniform vec3 tuft_avg = vec3(0.1073, 0.1205, 0.0241);
// Straw tufts keep their own colour, shifted from reddish toward straw yellow.
uniform vec3 straw_tint = vec3(0.8, 0.84, 0.68);
uniform float translucency = 0.4;
// How much trampled ground thins and shortens the clumps (0 for grass that stands
// where it is put, like the scythe's wild grass patches).
uniform float worn_response = 1.0;

varying vec3 v_col;
varying float v_h;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float dist = distance(root, CAMERA_POSITION_WORLD);
	float r = hash12(root.xz * 1.37 + 0.5);
	float keep = 1.0 - smoothstep(fade_start, fade_end, dist);
	// Thinning: clumps whose random value is under the share drop out smoothly.
	float thin = smoothstep(thin_start, fade_end, dist) * 0.5;
	keep *= smoothstep(thin, thin + 0.08, r);
	// Snow buries them.
	keep *= 1.0 - smoothstep(0.15, 0.75, snow_amount);
	// The ground fields only for clumps still standing (a good share of a chunk's
	// clumps is past fade_end or thinned out).
	vec4 f = vec4(0.0);
	if (keep > 0.0) {
		f = ground_fields(root.xz, root.y);
		f.y *= worn_response;
		// Trampled ground keeps few, short clumps.
		keep *= smoothstep(f.y * 0.75, f.y * 0.75 + 0.1, hash12(root.xz * 0.91 + 3.7));
	}
	v_h = UV2.x;
	if (keep <= 0.0) {
		// Fully shrunk: every vertex sits on the root, so the rest of the work is skipped.
		VERTEX = root;
		v_col = vec3(0.0);
	} else {
		vec3 local = VERTEX - root;
		local.y *= 1.0 + f.x * 0.35 - f.y * 0.45 - f.z * 0.2;
		local.xz *= 1.0 + thin * 0.7;
		float t = TIME;
		vec3 wp = VERTEX;
		float gust = vnoise2(wp.xz * 0.06 + vec2(t * 0.35, t * 0.12));
		float w = sin(t * 1.7 + wp.x * 0.33 + wp.z * 0.21) * 0.5
				+ sin(t * 2.9 + wp.x * 0.9 - wp.z * 0.6) * 0.25
				+ (gust - 0.4) * 1.3;
		vec2 disp = vec2(0.8, 0.45) * w * bend * wind_strength * v_h * v_h;
		local.xz += disp;
		local.y -= length(disp) * 0.3;
		VERTEX = root + local * keep;
		float jitter = hash12(root.xz * 0.73);
		// Straw: dry patches, trampled ground and autumn turn some tufts.
		float straw = clamp(smoothstep(0.35, 0.95, f.z) * 0.55 + autumn_amount * 0.62, 0.0, 0.9);
		if (hash12(root.xz * 2.71 + 1.3) < straw) {
			UV.y += 0.5;
			v_col = straw_tint * (0.85 + 0.3 * jitter);
		} else {
			v_col = meadow_albedo(root.xz, f) / tuft_avg * (0.88 + 0.24 * jitter);
		}
	}
}

void fragment() {
	// A little sharper than the mip chain would pick: the blades are thin.
	vec4 tex = texture(albedo_tex, UV, -0.6);
	// Mip-aware alpha: keeps distant clumps from thinning out.
	vec2 dx = dFdx(UV * tex_size);
	vec2 dy = dFdy(UV * tex_size);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))) - 0.6);
	vec3 col = tex.rgb * v_col;
	col = mix(col, snow_color(), snow_amount * smoothstep(0.3, 1.0, v_h));
	// Keep the clump normal on both faces (don't flip for back faces).
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = col * (1.0 - wetness * 0.2);
	ALPHA = tex.a * (1.0 + lod * 0.35);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	// Crisp, antialiased blade edges (alpha to coverage with MSAA).
	ALPHA_ANTIALIASING_EDGE = alpha_cut;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(tex_size, tex_size * 0.5);
	// Little sheen: at grazing angles a glossier sward turns milky with sky light.
	ROUGHNESS = mix(0.85, 0.5, wetness);
	SPECULAR = 0.12;
	AO = mix(0.55, 1.0, v_h);
	AO_LIGHT_AFFECT = 0.25;
	BACKLIGHT = col * translucency;
}
