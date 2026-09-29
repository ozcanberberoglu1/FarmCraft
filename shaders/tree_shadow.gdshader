// The hill forest's shadow shapes (NatureModels.shadow_shape), drawn only into the sun's
// shadow maps: holes in patches let sun flecks through, so the shade of a crown is
// dappled like a real one's (on the forest floor and on the tree's own inner and far
// branches) instead of a solid cut-out. World-space noise: the flecks stay put as the
// camera moves and only shift a little in the wind.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/include/nature.gdshaderinc"

// Share of the shape left open (each of its two sides: light passes where both are).
uniform float gaps : hint_range(0.0, 1.0) = 0.42;
// More open where the sun grazes the shape: the shade's outline frays like a crown's.
uniform float edge_gaps : hint_range(0.0, 1.0) = 0.3;
// Size of the leaf masses and of the flecks between them (noise frequency per metre).
uniform float clumps = 1.3;
uniform float flecks = 4.5;

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wp.xz += vec2(sin(TIME * 0.9 + wp.y * 0.3), cos(TIME * 0.7 + wp.y * 0.2)) * 0.06 * wind_strength;
	float n = vnoise3(wp * clumps) * 0.6 + vnoise3(wp * flecks + 17.0) * 0.4;
	float graze = 1.0 - abs(dot(normalize(NORMAL), VIEW));
	if (n < mix(0.2, 0.62, gaps) + smoothstep(0.45, 0.95, graze) * edge_gaps) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
