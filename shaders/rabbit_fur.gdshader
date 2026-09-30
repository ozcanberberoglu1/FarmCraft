shader_type spatial;
// Shell fur (RabbitRig, tools/blender/build_rabbit.py): the fur mesh stacks `layer_count`
// copies of the body, UV2.x the layer (1/n .. 1), UV2.y the fur's length there over
// `max_length`. Each copy is pushed out along the normal by its share of the length and
// combed back and down, and is cut into strands by `strands` (R the strand's length,
// G the distance from its middle, B a shade): dense short underfur and longer guard
// hairs with dark tips. The instance's `fur_layers` (graphics preset) and, further off,
// the distance thin out the layers: unused layers collapse to nothing.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D strands : filter_linear_mipmap, repeat_enable;
// Strand tiles per UV unit.
uniform float strand_scale = 14.6;
uniform float max_length = 0.02;
uniform float layer_count = 16.0;
// The model-space direction the coat lies towards (back and a little down).
uniform vec3 comb = vec3(0.0, -0.35, 1.0);
uniform float comb_amount = 0.9;
// Metres: full layers nearer than x, four from y, none beyond z.
uniform vec3 lod_distance = vec3(5.0, 18.0, 45.0);
global uniform float wetness;
instance uniform float fur_layers : instance_index(2) = 16.0;
instance uniform float coat_shade : instance_index(0) = 1.0;

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
	float len = UV2.y * max_length * (1.0 - 0.4 * wetness);
	if (layer > n || len < 0.0003) {
		VERTEX = vec3(0.0);
		v_h = 2.0;
	} else {
		float h = layer / n;
		v_h = h;
		vec3 c = normalize(comb);
		c -= NORMAL * dot(c, NORMAL);
		VERTEX += NORMAL * len * h + c * len * comb_amount * h * h;
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
	vec3 base = texture(albedo_tex, UV).rgb * coat_shade;
	// Roots in the coat's shade; guard hairs end in dark tips (agouti).
	vec3 col = base * mix(0.5, 1.08, h) * mix(0.72, 1.25, s.b);
	float guard = smoothstep(0.78, 0.84, len);
	col = mix(col, col * 0.3, guard * smoothstep(0.72, 0.9, h / len));
	col *= 1.0 - 0.3 * wetness;
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.5, wetness);
	SPECULAR = 0.3;
	// Light through the thin tips.
	BACKLIGHT = col * 0.35 * h;
}
