// The axe's notch in a standing trunk (TreeNotch): a flat floor and a sloping roof cut
// into the wood. The trunk mesh is left alone; this draws the two cut faces after the
// opaque pass, over the bark wherever the bark seen at that pixel lies inside the notch
// (read back from the depth buffer), so the opening follows the real bark exactly.
// Space: the notch node's own (origin on the trunk axis at the floor, +X out through
// the notch, Y up; no scale).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back, depth_test_disabled, depth_draw_never, blend_mix;

#include "res://shaders/include/noise.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// Oak / pine fresh wood.
uniform vec3 sapwood : source_color = vec3(0.86, 0.72, 0.5);
uniform vec3 heartwood : source_color = vec3(0.62, 0.43, 0.26);
uniform vec3 bark_color : source_color = vec3(0.24, 0.18, 0.13);

// Trunk radius, how deep the notch is cut (from the bark), the height of its mouth at
// the bark, how many blows made it, and the outer reach of the faces.
instance uniform float notch_r = 0.3;
instance uniform float notch_depth = 0.05;
instance uniform float notch_mouth = 0.08;
instance uniform float notch_blows = 1.0;
instance uniform float notch_reach = 0.4;
instance uniform float notch_seed = 0.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

// Seen from outside, a point is cut away when it lies over the floor, under the roof
// and within the faces' reach.
bool in_notch(vec3 s, float x0, float k) {
	return s.y > -0.004 && s.y < k * (s.x - x0) + 0.004 && s.x > x0 - 0.004
			&& length(s.xz) < notch_reach && s.y < notch_mouth * 3.0 + 0.1;
}

float wood_height(vec3 p, float x0) {
	float a = atan(p.z, p.x);
	float rr = length(p.xz);
	// Fibres along the trunk, torn deeper near the crease where the blows meet.
	float fib = vnoise3(vec3(a * 90.0, rr * 260.0, p.y * 9.0) + notch_seed);
	float tear = smoothstep(notch_depth * 0.45, 0.0, p.x - x0);
	float torn = vnoise3(vec3(a * 60.0, rr * 120.0, p.y * 60.0) + notch_seed * 3.0);
	// Each blow left its own facet in the roof: shallow steps across the slope.
	float steps = fract((p.x - x0) / max(notch_depth, 0.001) * notch_blows);
	float facet = smoothstep(0.0, 0.12, steps) * (1.0 - smoothstep(0.85, 1.0, steps));
	return fib * 0.25 + torn * tear * 0.9 + facet * 0.15;
}

void fragment() {
	float x0 = notch_r - notch_depth;
	float k = notch_mouth / max(notch_depth, 0.001);
	// The scene surface behind this pixel, in notch space.
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	mat3 rot = mat3(MODEL_MATRIX[0].xyz, MODEL_MATRIX[1].xyz, MODEL_MATRIX[2].xyz);
	vec3 s = transpose(rot) * (world - MODEL_MATRIX[3].xyz);
	// Draw only over bark that the notch cuts away, and only behind it.
	if (!in_notch(s, x0, k) || -VERTEX.z < -view.z - 0.01) {
		discard;
	}
	float rr = length(lp.xz);
	float a = atan(lp.z, lp.x);
	// The bark seen here is the trunk's real surface nearby: its radius sets the rim.
	float rs = max(length(s.xz), notch_r * 0.9);
	// Growth rings, unevenly spaced (solid wood: a flat cut shows circles, the slope
	// stretched arcs): thin darker latewood lines in paler earlywood.
	float wob = (vnoise2(vec2(a * 4.0, rr * 30.0) + notch_seed) - 0.5) * 0.008;
	float rp = (rr + wob) * 58.0 + vnoise2(vec2(rr * 35.0, notch_seed * 1.7)) * 1.8;
	float rf = fract(rp);
	float late = smoothstep(0.55, 0.88, rf) * (1.0 - smoothstep(0.9, 1.0, rf));
	float heart = smoothstep(notch_r * 0.62, notch_r * 0.5, rr);
	vec3 wood = mix(sapwood, heartwood, heart * 0.85);
	wood = mix(wood, wood * vec3(0.72, 0.6, 0.5), late * 0.6);
	float h = wood_height(lp, x0);
	wood *= 0.88 + 0.2 * h;
	// Where one blow's facet meets the next the fibres are crushed a little darker.
	float st = fract((lp.x - x0) / max(notch_depth, 0.001) * notch_blows);
	wood *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.1, st));
	// Torn fibres in the crease are darker, shadowed and rough.
	float crease = smoothstep(notch_depth * 0.35, 0.0, lp.x - x0);
	wood *= 1.0 - crease * 0.3;
	// Inner bark (cinnamon, over a thin cambium line) and the dark outer bark at the rim.
	float bark_t = 0.01 + notch_r * 0.045;
	float bn = vnoise3(lp * 140.0 + notch_seed);
	float inner = smoothstep(rs - bark_t - 0.004, rs - bark_t, rr);
	vec3 col = mix(wood, vec3(0.5, 0.3, 0.17) * (0.85 + 0.3 * bn), inner);
	float outer = smoothstep(rs - bark_t * 0.55, rs - bark_t * 0.45, rr);
	col = mix(col, bark_color * (0.75 + 0.5 * bn), outer);
	// Height-derived bump for the fibres and facets.
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float bump = (h + inner * bn * 0.6) * 0.0025;
	float hx = dFdx(bump);
	float hy = dFdy(bump);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (hx * r1 + hy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	ALBEDO = col;
	ROUGHNESS = mix(0.7, 0.95, max(crease, inner));
	// Deep in the cut less sky and bounce light reaches.
	float inside = smoothstep(0.0, notch_depth * 0.8, lp.x - x0);
	AO = mix(0.55, 1.0, inside);
	AO_LIGHT_AFFECT = 0.2;
	SPECULAR = 0.35;
	// Lit and shadowed as the bark that was cut away here (a little in front of it): the
	// faces lie inside the trunk's uncut mesh, whose own shadow would fall on them in
	// stripes, sun and shade side by side.
	LIGHT_VERTEX = view.xyz * (1.0 - 0.04 / max(length(view.xyz), 0.04));
}
