// A carnival night's light bulbs and paper lanterns (TownCarnival), drawn as multimesh
// instances. Per instance: COLOR = the bulb's colour (linear), INSTANCE_CUSTOM =
// (phase 0..1, pattern, place in the switch-on sweep 0..1, unused). Patterns: 0 a
// gentle shimmer, 1 a chase along the string, 2 a wave running round (the wheel).
// Lit bulbs glow well over 1.0 so the screen's glow makes them shine; unlit ones are
// coloured glass.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float sweep = 2.0;
uniform float energy = 5.0;
uniform float glass = 0.35;
// The night's grade takes some colour out of the picture: coloured bulbs are pushed
// further from grey to keep their colour, and glow a little less so the tonemapper
// doesn't bleach them to white.
uniform float saturate = 1.6;

varying vec4 v_col;
varying vec4 v_custom;

void vertex() {
	v_col = COLOR;
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	float phase = v_custom.x;
	float mode = v_custom.y;
	float tw;
	if (mode < 0.5) {
		tw = 0.84 + 0.16 * sin(TIME * 2.1 + phase * 37.0);
	} else if (mode < 1.5) {
		tw = 0.3 + 0.7 * step(0.55, fract(TIME * 0.8 - phase * 3.0));
	} else {
		tw = 0.45 + 0.55 * (0.5 + 0.5 * sin(TIME * 3.0 - phase * 6.2832 * 3.0));
	}
	float on = power * step(v_custom.z, sweep);
	vec3 c = v_col.rgb;
	float hi = max(c.r, max(c.g, c.b));
	float sat = hi > 0.0 ? (hi - min(c.r, min(c.g, c.b))) / hi : 0.0;
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid = max(mix(vec3(lum), c, saturate), vec3(0.0));
	ALBEDO = c * glass;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
	EMISSION = vivid * energy * (1.0 - 0.45 * sat) * tw * on;
}
