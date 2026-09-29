// Sparks and embers rising off a campfire (CampfireFx): tiny camera-facing glowing dots,
// bright enough to bloom, fading out as they cool (the particle colour's alpha).
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float intensity = 6.0;

void vertex() {
	mat4 face = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * face * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float dot_shape = 1.0 - smoothstep(0.2, 1.0, d);
	ALBEDO = COLOR.rgb * intensity;
	ALPHA = dot_shape * COLOR.a;
}
