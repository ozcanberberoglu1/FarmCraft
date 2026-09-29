// Campfire flames (CampfireFx): each particle a camera-facing tongue of fire, its shape
// eaten away by noise rising through it as it ages, hot white-yellow at the core
// through orange to deep red at the fringes, added onto what is behind it (HDR: the
// core blooms). Soft where it meets the logs and the ground.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float intensity = 2.0;
// Width of the tongue's base (0..0.5 of the quad) and how far it licks up.
uniform float width = 0.42;
uniform float soft_distance = 0.12;
// The whole fire's strength (0 out .. 1 blazing), set per emitter.
instance uniform float heat = 1.0;

varying float v_age;
varying float v_seed;

void vertex() {
	// Faces the camera, keeping the particle's scale and its small tilt (custom x).
	float a = INSTANCE_CUSTOM.x * 0.25;
	mat4 face = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	face = face * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * face * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_age = INSTANCE_CUSTOM.y;
	v_seed = INSTANCE_CUSTOM.z;
}

void fragment() {
	float y = 1.0 - UV.y;
	float seed = v_seed * 17.31;
	float t = TIME;
	float n1 = texture(noise_tex, vec2(UV.x * 0.8 + seed, y * 0.7 - t * 0.85 + seed * 0.37)).r;
	float n2 = texture(noise_tex, vec2(UV.x * 1.7 - seed * 1.3, y * 1.6 - t * 1.9)).r;
	float n = n1 * 0.62 + n2 * 0.38;
	// The tongue: round and full at the bottom, licking up to a flickering point, bent by
	// the noise more the higher it goes.
	float x = UV.x - 0.5 + (n - 0.5) * 0.45 * y;
	float w = mix(width, 0.03, pow(clamp(y, 0.0, 1.0), 0.8));
	float body = 1.0 - smoothstep(w * 0.35, w, abs(x));
	float base = smoothstep(0.0, 0.2, y);
	float top = 1.0 - smoothstep(0.45, 1.0, y + (n - 0.5) * 0.6);
	float f = body * base * top;
	// Eaten away from its tip and edges as it rises and ages.
	f *= smoothstep(0.1 + v_age * 0.5, 0.55 + v_age * 0.35, n + (1.0 - y) * 0.4);
	float hot = f * (1.0 - v_age * 0.55);
	vec3 col = mix(vec3(0.45, 0.04, 0.005), vec3(1.0, 0.24, 0.02), smoothstep(0.04, 0.4, hot));
	col = mix(col, vec3(1.0, 0.5, 0.12), smoothstep(0.35, 0.75, hot));
	col = mix(col, vec3(1.0, 0.78, 0.45), smoothstep(0.78, 1.0, hot));
	// Soft against the logs and the ground behind it.
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float soft = clamp((VERTEX.z - behind.z) / soft_distance, 0.0, 1.0);
	ALBEDO = col * intensity * COLOR.rgb;
	ALPHA = clamp(f * COLOR.a * heat, 0.0, 1.0) * soft;
}
