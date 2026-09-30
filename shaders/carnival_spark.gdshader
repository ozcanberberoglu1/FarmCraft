// Firework sparks (CarnivalFireworks): camera-facing soft dots added onto the night,
// bright enough for the screen's glow. The particle's colour (its shell's colour ramp)
// fades them out.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float energy = 3.6;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = clamp(1.0 - d, 0.0, 1.0);
	a *= a;
	float lum = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid = max(mix(vec3(lum), COLOR.rgb, 1.6), vec3(0.0));
	ALBEDO = vivid * energy * a * COLOR.a;
}
