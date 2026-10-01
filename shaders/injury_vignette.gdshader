shader_type canvas_item;
// The farmer's wounds at the edges of the view (InjuryOverlay): a dark red that creeps in
// from the corners as the injury meter fills, throbbing with the heartbeat when it is
// high, the picture a little drained of colour; a fresh bite flares the edge and leaves a
// smear of blood on the side it came from, fading over a second or two.

uniform float injury : hint_range(0.0, 1.0) = 0.0;
// 0..1 heartbeat throb (added to the vignette at high injury).
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
// A fresh wound's flare of the whole edge (fades fast).
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// Where the last bite came from, in screen space (x right, y down), and how much of its
// smear is left.
uniform vec2 splash_dir = vec2(0.0, 1.0);
uniform float splash : hint_range(0.0, 1.0) = 0.0;
uniform float splash_seed = 0.0;
uniform float aspect = 1.7778;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
	vec2 q = (UV - 0.5) * 2.0;
	vec2 qa = q * vec2(aspect, 1.0);
	float d = length(q * vec2(0.92, 1.0));
	float n = fbm(qa * 2.2 + vec2(splash_seed * 3.1, 0.0));
	// The vignette: further in the worse the wounds, its edge ragged.
	float strength = clamp(injury * (0.85 + 0.25 * pulse) + flash * 0.35, 0.0, 1.2);
	float inner = mix(1.25, 0.4, clamp(strength, 0.0, 1.0));
	float v = smoothstep(inner, inner + 0.55, d + (n - 0.5) * 0.35);
	v *= clamp(strength * 1.4, 0.0, 1.0);
	// The smear on the bitten side: blotches near that edge.
	vec2 dir = normalize(splash_dir + vec2(1e-4));
	float side = dot(normalize(q + vec2(1e-4)), dir);
	float edge = smoothstep(0.45, 1.05, d);
	float blot = smoothstep(0.52, 0.72, fbm(qa * 3.4 + vec2(splash_seed * 7.3, splash_seed * 1.7)) + (side - 0.55) * 0.9 + (edge - 0.5) * 0.5);
	float s = blot * smoothstep(0.25, 0.75, side) * edge * splash;
	// Drained colour and a darker picture as it gets bad.
	float lum = dot(scene, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(scene, vec3(lum), injury * 0.45) * (1.0 - injury * 0.18);
	vec3 blood = mix(vec3(0.5, 0.025, 0.02), vec3(0.17, 0.0, 0.0), clamp(d - 0.7, 0.0, 1.0));
	col = mix(col, blood, clamp(v * 0.92, 0.0, 0.92));
	col = mix(col, vec3(0.3, 0.01, 0.01) * (0.7 + 0.3 * n), clamp(s * 0.85, 0.0, 0.85));
	COLOR = vec4(col, 1.0);
}
