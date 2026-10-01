shader_type spatial;
// The grey wolf's shell fur (WolfRig, tools/blender/build_wolf.py): Karamel's shell fur
// (dog_fur.gdshader) with a wild coat's hair. The fur mesh stacks `layer_count` copies
// of the body, UV2.x the layer (1/n .. 1), the fur's length there over `max_length` in
// UV2.y as glTF stores it (V counted from the top: 1 - the share). Each copy is pushed out along the normal by its share of the length,
// combed back and down, the long hair drooping; `strands` cuts it into hairs (R the
// strand's length, G the distance from its middle, B a shade). The guard hairs are
// banded (agouti): most end in a black tip where the coat is dark (the saddle, the
// tail) and some in a pale one, which grizzles the coat. The instance's `fur_layers`
// (graphics preset) and, further off, the distance thin out the layers; `ruffle` (0..1)
// raises the hackles a little (WolfRig: snarling).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D strands : filter_linear_mipmap, repeat_enable;
// Strand tiles per UV unit.
uniform float strand_scale = 15.0;
uniform float max_length = 0.07;
uniform float layer_count = 14.0;
// The model-space direction the coat lies towards (back and down).
uniform vec3 comb = vec3(0.0, -0.4, 1.0);
uniform float comb_amount = 0.6;
// How far long hair sags under its weight (share of its length, at full length).
uniform float droop = 0.2;
// Metres: full layers nearer than x, four from y, none beyond z.
uniform vec3 lod_distance = vec3(7.0, 24.0, 55.0);
global uniform float wetness;
instance uniform float fur_layers : instance_index(0) = 14.0;
instance uniform float ruffle : instance_index(1) = 0.0;

varying float v_h;
varying float v_len;

void vertex() {
	float layer = floor(UV2.x * layer_count + 0.5);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world - CAMERA_POSITION_WORLD);
	float n = min(fur_layers, layer_count);
	n = floor(mix(n, min(n, 4.0), smoothstep(lod_distance.x, lod_distance.y, dist)) + 0.5);
	if (dist > lod_distance.z) {
		n = 0.0;
	}
	// Wet fur clings.
	float share = 1.0 - UV2.y;
	float len = share * max_length * (1.0 - 0.55 * wetness);
	v_len = len;
	// A layer not drawn collapses to nothing (all of it: the layer is one per triangle).
	// A vertex without fur stays on the skin, so its triangles don't reach across the
	// body to wherever a collapsed vertex would go: the fragment drops it there.
	if (layer > n) {
		VERTEX = vec3(0.0);
		v_h = 2.0;
	} else {
		float h = layer / n;
		v_h = h;
		vec3 c = normalize(comb);
		c -= NORMAL * dot(c, NORMAL);
		// Skinned vertices are in the wolf's upright frame: down is down.
		vec3 down = vec3(0.0, -1.0, 0.0);
		down -= NORMAL * min(dot(down, NORMAL), 0.0);
		float sag = droop * share * h * h * (1.0 - ruffle);
		float lie = comb_amount * (1.0 - 0.6 * ruffle * share);
		VERTEX += NORMAL * len * h * (1.0 + 0.25 * ruffle) + c * len * lie * h * h + down * len * sag;
	}

}

void fragment() {
	if (v_h > 1.5 || v_len < 0.0006) {
		discard;
	}
	vec4 s = texture(strands, UV * strand_scale);
	float h = v_h;
	float len = max(s.r, 0.05);
	// Strands taper to their tips; one shorter than this layer's height has ended. A
	// wild coat is dense: the hairs stay thick most of their length (in locks).
	float taper = (1.0 - h / len) * 1.55 + 0.08;
	ALPHA = clamp((taper - s.g) * 6.0 + 0.5, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 base = texture(albedo_tex, UV).rgb;
	// Roots in the coat's shade (the dense, paler underfur), the hair lighter up its
	// length.
	vec3 col = base * mix(0.6, 1.0, h) * mix(0.8, 1.1, s.b);
	// Guard hairs' tips: black where the coat is dark (and on a share of them anywhere),
	// a pale band below; the rest bleached a shade lighter.
	float guard = smoothstep(0.78, 0.84, len);
	float tip = guard * smoothstep(0.62, 0.92, h / len);
	float band = guard * smoothstep(0.35, 0.55, h / len) * (1.0 - smoothstep(0.62, 0.8, h / len));
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	float black = step(mix(0.25, 0.75, smoothstep(0.22, 0.5, lum)), s.b);
	col = mix(col, min(col * 1.3 + vec3(0.04, 0.035, 0.025), vec3(1.0)), band * 0.6);
	col = mix(col, mix(min(col * 1.05 + vec3(0.01), vec3(1.0)), col * 0.22 + vec3(0.008), black), tip);
	col *= 1.0 - 0.32 * wetness;
	ALBEDO = col;
	ROUGHNESS = mix(0.82, 0.48, wetness);
	SPECULAR = 0.28;
	// Light through the thin tips.
	BACKLIGHT = col * 0.12 * h;
}
