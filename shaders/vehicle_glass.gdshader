// Vehicle glass: clear panes whose reflection of the sky (the engine's Fresnel term)
// is added in full over what shows through (premultiplied alpha: ALPHA is only how
// much of the view behind is lost), under a film of road dust that is thickest along the rubber seals and
// towards the bottom, wiped clean in two arcs on the windshield; optionally a stone
// chip with a long stress crack wandering up from it. Rain rinses the dust a little.
// Per pane (instance uniforms, set by Vehicle._fit_pane): its UV rectangle, oriented
// so pane x runs to the vehicle's right and y up; its width / height; how much of the
// dust it gets (the side windows are wound down and wiped by the seals); wipers on or
// off; where the chip is, as a fraction of the pane (x < 0: no crack).
shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float grime = 0.5;
uniform vec3 grime_color : source_color = vec3(0.5, 0.45, 0.36);
// How much of the view through the glass is lost looking straight through it.
uniform float clarity_loss = 0.22;
// Length of the crack, in pane heights.
uniform float crack_size = 0.55;

instance uniform vec2 pane_min = vec2(0.0);
instance uniform vec2 pane_max = vec2(1.0);
instance uniform float aspect = 1.0;
instance uniform float pane_grime = 1.0;
instance uniform float wipers = 0.0;
instance uniform vec2 crack_at = vec2(-1.0);

// A thin line at distance `d` (pane heights): anti-aliased, fading out once it is
// thinner than a pixel instead of breaking up.
float hairline(float d, float width, float px) {
	float w = max(width, px);
	return (1.0 - smoothstep(w * 0.5, w * 0.5 + px, d)) * clamp(width / px, 0.15, 1.0);
}

// Distance to a crack running from `o` along `dir` for `len`, wandering sideways.
float crack_dist(vec2 q, vec2 o, vec2 dir, float len, float seed, out float along) {
	vec2 side = vec2(-dir.y, dir.x);
	float s = dot(q - o, dir);
	along = s / len;
	float wander = (vnoise2(vec2(s * 7.0, seed)) - 0.5) * 0.09 + (vnoise2(vec2(s * 31.0, seed + 5.0)) - 0.5) * 0.018;
	float d = abs(dot(q - o, side) - wander * smoothstep(0.0, 0.08, s));
	return d + max(-s, 0.0) + max(s - len, 0.0);
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	vec2 p = clamp((UV - pane_min) / (pane_max - pane_min), 0.0, 1.0);
	// Pane space in pane heights (x across, y up).
	vec2 q = vec2(p.x * aspect, p.y);
	float px = max(length(fwidth(q)), 1e-5);

	// Dust: blotchy film, heavier along the seals and low on the pane.
	float edge = min(min(p.x, 1.0 - p.x) * aspect, min(p.y, 1.0 - p.y));
	float blotch = vnoise2(q * 9.0) * 0.6 + vnoise2(q * 31.0) * 0.4;
	float seal = 1.0 - smoothstep(0.012, 0.2, edge);
	float g = (0.22 + 0.6 * seal + 0.25 * (1.0 - p.y)) * (0.5 + 0.9 * blotch);
	if (wipers > 0.5) {
		// Two blades pivoting at the bottom sweep from lying flat (pointing right)
		// to past upright, their arcs overlapping in the middle like real tandem
		// wipers; a ridge of dust builds up beyond the blade tips.
		float swept = 0.0;
		float ridge = 0.0;
		for (int k = 0; k < 2; k++) {
			vec2 pivot = vec2(mix(0.14, 0.52, float(k)) * aspect, -0.04);
			vec2 d = q - pivot;
			float r = length(d);
			float ang = atan(d.y, d.x);
			float in_arc = smoothstep(-0.02, 0.1, ang) * (1.0 - smoothstep(1.9, 2.05, ang));
			swept = max(swept, in_arc * smoothstep(0.1, 0.15, r) * (1.0 - smoothstep(0.88, 0.92, r)));
			ridge = max(ridge, in_arc * smoothstep(0.88, 0.92, r) * (1.0 - smoothstep(0.93, 0.99, r)));
		}
		g *= 1.0 - 0.85 * swept;
		g += ridge * 0.3;
	}
	g = clamp(g * grime * pane_grime * (1.0 - wetness * 0.35), 0.0, 1.0);

	// Stone chip and the crack it grew: a clear hairline that only glints, a short
	// branch; the chip itself is a frosted pit in a small bruised halo.
	float line = 0.0;
	float chip = 0.0;
	if (crack_at.x >= 0.0) {
		vec2 o = vec2(crack_at.x * aspect, crack_at.y);
		float along;
		float d1 = crack_dist(q, o, normalize(vec2(-0.82, 0.57)), crack_size, 3.0, along);
		line = hairline(d1, 0.0012, px) * (1.0 - smoothstep(0.75, 1.0, along));
		vec2 fork = o + normalize(vec2(-0.82, 0.57)) * crack_size * 0.38;
		float along2;
		float d2 = crack_dist(q, fork, normalize(vec2(-0.2, 0.98)), crack_size * 0.3, 11.0, along2);
		line = max(line, hairline(d2, 0.001, px) * (1.0 - smoothstep(0.5, 1.0, along2)));
		float r = length(q - o);
		chip = max(1.0 - smoothstep(0.003, 0.007, r), (1.0 - smoothstep(0.0, 0.018, r)) * 0.35);
	}

	// The view through dims as the pane mirrors more of the sky, the flatter it is
	// seen (Schlick).
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fres = 0.04 + 0.96 * pow(1.0 - facing, 5.0);
	// Premultiplied: the tint and dust are lit in proportion to what they cover. The
	// dust sits on the outside, in front of the glass' own tint; the crack over both.
	float dust = g * 0.85;
	float cover = 1.0 - (1.0 - clarity_loss) * (1.0 - dust);
	vec3 lit = c.rgb * 0.3 * clarity_loss * (1.0 - dust) + grime_color * (0.8 + 0.3 * blotch) * dust;
	float cc = max(line * 0.22, chip * 0.8);
	lit = mix(lit, vec3(0.62, 0.64, 0.64), cc);
	cover = mix(cover, 1.0, cc);
	ALBEDO = lit;
	ALPHA = clamp(max(cover, fres), 0.0, 1.0);
	ROUGHNESS = mix(mix(0.02, 0.6, max(g, chip * 0.4)), 0.02, line);
	METALLIC = 0.0;
	// The crack's faces catch the light.
	SPECULAR = 0.5 + 0.5 * line;
}
