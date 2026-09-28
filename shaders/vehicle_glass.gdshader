// Weathered vehicle glass: the model's glass atlas under a film of road dust that is
// thickest along the rubber seals and towards the bottom, wiped clean in two arcs on
// the windshield, and optionally a stone-chip crack (a pit, a star of jagged lines
// and a few broken rings). Rain rinses the dust a little.
// Per pane (instance uniforms, set by Vehicle._fit_pane): its UV rectangle, oriented
// so pane x runs to the vehicle's right and y up; its width / height; wipers on or
// off; the crack's centre as a fraction of the pane (x < 0: no crack).
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float grime = 0.5;
uniform vec3 grime_color : source_color = vec3(0.5, 0.45, 0.36);
// Longest crack line, in pane heights.
uniform float crack_size = 0.3;

instance uniform vec2 pane_min = vec2(0.0);
instance uniform vec2 pane_max = vec2(1.0);
instance uniform float aspect = 1.0;
instance uniform float wipers = 0.0;
instance uniform vec2 crack_at = vec2(-1.0);

// A thin line at distance `d` (pane heights): anti-aliased, fading out once it is
// thinner than a pixel instead of breaking up.
float hairline(float d, float width, float px) {
	float w = max(width, px);
	return (1.0 - smoothstep(w * 0.5, w * 0.5 + px, d)) * clamp(width / px, 0.2, 1.0);
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	vec2 p = clamp((UV - pane_min) / (pane_max - pane_min), 0.0, 1.0);
	// Pane space in pane heights (x across, y up).
	vec2 q = vec2(p.x * aspect, p.y);
	float px = max(length(fwidth(q)), 1e-5);

	// Dust: blotchy film, heavier along the seals and low on the pane.
	float edge = min(min(p.x, 1.0 - p.x) * aspect, min(p.y, 1.0 - p.y));
	float blotch = vnoise2(q * 6.0) * 0.65 + vnoise2(q * 23.0) * 0.35;
	float seal = 1.0 - smoothstep(0.012, 0.22, edge);
	float g = (0.3 + 0.55 * seal + 0.25 * (1.0 - p.y)) * (0.55 + 0.9 * blotch);
	if (wipers > 0.5) {
		// Two blades pivoting at the bottom sweep from lying flat (pointing right)
		// to nearly upright; a ridge of dust builds up at the end of the blade.
		float swept = 0.0;
		float ridge = 0.0;
		for (int k = 0; k < 2; k++) {
			vec2 pivot = vec2(mix(0.2, 0.62, float(k)) * aspect, -0.04);
			vec2 d = q - pivot;
			float r = length(d);
			float ang = atan(d.y, d.x);
			float in_arc = smoothstep(-0.02, 0.1, ang) * (1.0 - smoothstep(1.85, 2.0, ang));
			swept = max(swept, in_arc * smoothstep(0.1, 0.15, r) * (1.0 - smoothstep(0.84, 0.88, r)));
			ridge = max(ridge, in_arc * smoothstep(0.84, 0.88, r) * (1.0 - smoothstep(0.89, 0.95, r)));
		}
		g *= 1.0 - 0.82 * swept;
		g += ridge * 0.35;
	}
	g = clamp(g * grime * (1.0 - wetness * 0.35), 0.0, 1.0);

	// Stone-chip crack.
	float crack = 0.0;
	if (crack_at.x >= 0.0) {
		vec2 d = q - vec2(crack_at.x * aspect, crack_at.y);
		float r = length(d);
		float a = atan(d.y, d.x) / TAU + 0.5;
		float spokes = 11.0;
		float cell = floor(a * spokes);
		float wob = (vnoise2(vec2(r * 14.0, cell * 3.1)) - 0.5) * 0.55;
		float s = fract(a * spokes + wob);
		float reach = crack_size * (0.3 + 0.7 * hash12(vec2(cell, 7.0)));
		float fade_out = 1.0 - smoothstep(reach * 0.7, reach, r);
		// Distance to the spoke line across the cell's arc.
		float spoke = hairline(abs(s - 0.5) * TAU * r / spokes, 0.0022, px) * fade_out;
		// Broken rings around the impact in some cells.
		float ring_r = 0.03 + 0.03 * hash12(vec2(cell, 3.0));
		float ring = hairline(abs(r - ring_r), 0.0018, px) * step(0.45, hash12(vec2(cell, 11.0)));
		float ring2 = hairline(abs(r - ring_r * 2.1), 0.0016, px) * step(0.7, hash12(vec2(cell, 17.0)));
		// The pit and its crushed, milky halo.
		float pit = 1.0 - smoothstep(0.005, 0.011, r);
		float halo = (1.0 - smoothstep(0.0, 0.03, r)) * 0.45;
		crack = clamp(max(max(spoke, max(ring, ring2)), max(pit, halo)), 0.0, 1.0);
	}

	vec3 col = mix(c.rgb, grime_color * (0.8 + 0.3 * blotch), g);
	col = mix(col, vec3(0.82, 0.84, 0.83), crack * 0.8);
	ALBEDO = col;
	ALPHA = clamp(max(mix(c.a, 0.97, g * 0.75), crack * 0.9), 0.0, 1.0);
	ROUGHNESS = mix(0.04, 0.62, max(g, crack * 0.5));
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
