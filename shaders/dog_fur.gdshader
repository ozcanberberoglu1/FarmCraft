shader_type spatial;
// Karamel's shell fur (DogRig, tools/blender/build_dog.py): the fur mesh stacks
// `layer_count` copies of the body, UV2.x the layer (1/n .. 1), UV2.y the fur's length
// there over `max_length`. Each copy is pushed out along the normal by its share of the
// length and combed back and down (and heavier fur droops), and is cut into strands by
// `strands` (R the strand's length, G the distance from its middle, B a shade): a dense
// undercoat and longer guard hairs whose tips the sun has bleached a shade lighter. The
// instance's `fur_layers` (graphics preset) and, further off, the distance thin out the
// layers: unused layers collapse to nothing.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D strands : filter_linear_mipmap, repeat_enable;
// Strand tiles per UV unit.
uniform float strand_scale = 24.0;
uniform float max_length = 0.02;
uniform float layer_count = 14.0;
// The model-space direction the coat lies towards (back and down).
uniform vec3 comb = vec3(0.0, -0.45, 1.0);
uniform float comb_amount = 0.85;
// How far long hair sags under its weight (share of its length, at full length).
uniform float droop = 0.35;
// Metres: full layers nearer than x, four from y, none beyond z.
uniform vec3 lod_distance = vec3(6.0, 20.0, 45.0);
global uniform float wetness;
instance uniform float fur_layers : instance_index(0) = 14.0;

varying float v_h;

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
	float len = UV2.y * max_length * (1.0 - 0.5 * wetness);
	if (layer > n || len < 0.0004) {
		VERTEX = vec3(0.0);
		v_h = 2.0;
	} else {
		float h = layer / n;
		v_h = h;
		vec3 c = normalize(comb);
		c -= NORMAL * dot(c, NORMAL);
		// Skinned vertices are in the dog's upright frame: down is down.
		vec3 down = vec3(0.0, -1.0, 0.0);
		down -= NORMAL * min(dot(down, NORMAL), 0.0);
		float sag = droop * UV2.y * h * h;
		VERTEX += NORMAL * len * h + c * len * comb_amount * h * h + down * len * sag;
	}
}

void fragment() {
	if (v_h > 1.5) {
		discard;
	}
	vec4 s = texture(strands, UV * strand_scale);
	float h = v_h;
	float len = max(s.r, 0.05);
	// Strands taper to their tips; one shorter than this layer's height has ended.
	float taper = (1.0 - h / len) * 1.05;
	ALPHA = clamp((taper - s.g) * 6.0 + 0.5, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 base = texture(albedo_tex, UV).rgb;
	// Roots in the coat's shade, the tips of the guard hairs bleached lighter.
	vec3 col = base * mix(0.55, 1.0, h) * mix(0.84, 1.1, s.b);
	float guard = smoothstep(0.78, 0.84, len);
	col = mix(col, min(col * 1.1 + vec3(0.02, 0.012, 0.0), vec3(1.0)), guard * smoothstep(0.6, 0.95, h / len));
	col *= 1.0 - 0.3 * wetness;
	ALBEDO = col;
	ROUGHNESS = mix(0.8, 0.45, wetness);
	SPECULAR = 0.3;
	// Light through the thin tips.
	BACKLIGHT = col * 0.35 * h;
}
