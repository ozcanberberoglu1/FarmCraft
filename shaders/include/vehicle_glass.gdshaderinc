// Vehicle glass (vehicle_glass.gdshader, and vehicle_glass_wet.gdshader with GLASS_RAIN
// defined): clear panes whose reflection of the sky (the engine's Fresnel term)
// is added in full over what shows through (premultiplied alpha: ALPHA is only how
// much of the view behind is lost), under a film of road dust that is thickest along the rubber seals and
// towards the bottom, wiped clean in two arcs on the windshield; optionally a stone
// chip with a long stress crack wandering up from it. Rain rinses the dust a little.
// Seen from inside the cab a pane mirrors the dim cab, not the sky: without that an
// overcast sky lay over the whole view as a pale veil and turned wet grass and leaves
// to metal.
// Per pane (instance uniforms, set by Vehicle._fit_pane and VehicleWipers): its UV
// rectangle, oriented so pane x runs to the vehicle's right and y up; its width /
// height; how much of the dust it gets (the side windows are wound down and wiped by
// the seals); wipers on or off and where their blades turn; where the chip is, as a
// fraction of the pane (x < 0: no crack); a point inside the cab.
// GLASS_RAIN (the shader VehicleWipers gives the panes while they are wet): rain
// beads up on the panes and runs down them, seen through as small lenses (the view
// behind turned over in each drop), and the wiper blades clear it in their arcs.

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float grime = 0.5;
uniform vec3 grime_color : source_color = vec3(0.5, 0.45, 0.36);
// How much of the view through the glass is lost looking straight through it.
uniform float clarity_loss = 0.22;
// Length of the crack, in pane heights.
uniform float crack_size = 0.55;
// How much of the sky's mirror image is left on a pane seen from inside the cab.
uniform float inside_mirror = 0.12;

instance uniform vec2 pane_min = vec2(0.0);
instance uniform vec2 pane_max = vec2(1.0);
instance uniform float aspect = 1.0;
instance uniform float pane_grime = 1.0;
instance uniform float wipers = 0.0;
instance uniform vec2 crack_at = vec2(-1.0);
// The two wiper blades: the pivot (x as a share of the pane's width, y in pane heights)
// and the blade's inner and outer reach from it (pane heights; outer 0: no blade).
instance uniform vec4 wiper_a = vec4(0.14, -0.04, 0.1, 0.9);
instance uniform vec4 wiper_b = vec4(0.52, -0.04, 0.1, 0.9);
// The angle the blades park at and how far they turn from it (radians from pane +x,
// counter-clockwise; a negative turn runs clockwise).
instance uniform vec2 wiper_sweep = vec2(0.04, 1.95);
// A point inside the cab, in the pane mesh's own space (w = 0: not known, the pane
// mirrors the sky from both sides).
instance uniform vec4 cab_at = vec4(0.0);

#ifdef GLASS_RAIN
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
// How much rain water sits on the panes (0..1): builds while it falls, dries off after.
uniform float rain_wet = 0.0;
// How hard it rains (0..1; the last rain's once it has stopped: what it left stays as it is).
uniform float rain_rate = 0.75;
// Seconds of rain so far (stands still in the dry: the drops stop growing and running).
uniform float rain_time = 0.0;
// How far the side windows' runs lean back in the airstream (metres per metre down).
uniform float rain_slant = 0.0;
// The wipers' cycle: seconds since it began (a stroke up, a stroke back, then parked),
// how long a stroke takes, how long the blades stood parked before it, which cycle it is.
uniform float wiper_t = 1.0e6;
uniform float wiper_stroke = 0.6;
uniform float wiper_gap = 1.0e6;
uniform float wiper_count = 0.0;
// The pane's height (m), how much of the rain it catches, 1 on a side window, 1 when
// the wipers clear it.
instance uniform vec4 rain_pane = vec4(0.5, 1.0, 0.0, 0.0);
// A drop is a small lens: it shows the view through the pane from this far round it
// (pane heights), turned over.
const float LENS = 0.2;
#endif

varying vec3 v_cab;

void vertex() {
	v_cab = (MODELVIEW_MATRIX * vec4(cab_at.xyz, 1.0)).xyz;
}

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

// Where pane point `q` lies for blade `w`: x its share of the blade's turn (0 parked,
// 1 turned right over; outside 0..1 the blade never comes by), y how far from the pivot.
vec2 sweep_of(vec2 q, vec4 w, float asp, vec2 sweep) {
	vec2 d = q - vec2(w.x * asp, w.y);
	float cs = cos(sweep.x);
	float sn = sin(sweep.x);
	vec2 turned = vec2(d.x * cs + d.y * sn, d.y * cs - d.x * sn);
	return vec2(atan(turned.y, turned.x) * sign(sweep.y) / max(abs(sweep.y), 0.01), length(d));
}

#ifdef GLASS_RAIN
// Beads of rain on a grid of `cell` metres, up to `rmax` across by half: each one
// swells over its life, runs off and another settles somewhere else in its cell; a
// share `fill` of the cells holds one. `since` (seconds since a blade last wiped here)
// lets them come back one by one over `build` seconds. Adds what a bead does to the
// view (`lens`: where it looks instead, as a share of LENS; `dome`: its slope; `rim`:
// its dark edge) and returns how much of the fragment it covers. The grid is turned by
// `turn` so its rows never line up with the pane or with the other layer's.
float beads(vec2 m, float cell, float turn, float seed, float rmax, float fill, float since, float build,
		inout vec2 lens, inout vec2 dome, inout float rim) {
	vec2 axis = vec2(cos(turn), sin(turn));
	vec2 g = vec2(m.x * axis.x + m.y * axis.y, m.y * axis.x - m.x * axis.y) / cell;
	vec2 id = floor(g);
	vec2 f = g - id;
	float h0 = hash12(id + seed);
	float age = h0 * 9.0 + rain_time * (0.03 + 0.05 * hash12(id * 1.9 - seed));
	float life = fract(age);
	vec2 spot = id + seed + floor(age) * 7.3;
	float h1 = hash12(spot + 3.1);
	float h2 = hash12(spot * 1.7 + 11.9);
	float h3 = hash12(spot * 2.3 + 27.4);
	float grown = (0.5 + 0.5 * smoothstep(0.0, 0.8, life)) * smoothstep(0.0, 0.04, life) * (1.0 - smoothstep(0.97, 1.0, life));
	grown *= step(h0, fill) * smoothstep(h3 * build, h3 * build + 0.5, since);
	float r = rmax * mix(0.45, 1.0, h3) * grown / cell;
	vec2 c = vec2(0.5) + (vec2(h1, h2) - 0.5) * (1.0 - 2.0 * rmax / cell);
	vec2 d = (f - c) / max(r, 0.0001);
	// Back in the pane's own axes.
	d = vec2(d.x * axis.x - d.y * axis.y, d.y * axis.x + d.x * axis.y);
	float l = length(d);
	float k = (1.0 - smoothstep(0.72, 1.0, l)) * step(0.001, r);
	lens -= d * k;
	dome += d * k;
	rim = max(rim, k * smoothstep(0.4, 1.0, l));
	return k;
}

// Drops that have grown too heavy: each runs down its own wandering lane in fits and
// starts, a thin wet trail breaking into beads behind it. `xs`: across the pane with
// the airstream's lean taken out (the lanes lean back on the side windows at speed).
float runners(vec2 m, float xs, float since, inout vec2 lens, inout vec2 dome, inout float rim) {
	const float LANE = 0.065;
	const float LAP = 0.5;
	float lane = floor(xs / LANE);
	float fx = xs / LANE - lane;
	float hl = hash12(vec2(lane, 7.0));
	float run = rain_time * (0.045 + 0.09 * hl);
	// Fits and starts.
	float y = (m.y + run + 0.012 * sin(run * 55.0 + hl * 40.0)) / LAP + hl * 5.0;
	float lap = floor(y);
	float fy = y - lap;
	float hk = hash12(vec2(lane, lap));
	float on = step(hk, 0.2 + 0.45 * rain_rate) * smoothstep(0.8, 1.8, since);
	float rr = mix(0.0045, 0.0075, hash12(vec2(lap, lane + 3.0)));
	float mid = 0.5 + (hk - 0.32) * 0.4 + 0.08 * sin(m.y * 43.0 + hk * 20.0);
	float dx = (fx - mid) * LANE;
	float up = (fy - 0.12) * LAP;
	vec2 d = vec2(dx, up * 0.72) / rr;
	float l = length(d);
	float k = (1.0 - smoothstep(0.72, 1.0, l)) * on;
	lens -= d * k;
	dome += d * k;
	rim = max(rim, k * smoothstep(0.4, 1.0, l));
	// The trail above the head, narrowing and breaking up.
	float reach = 0.12 + 0.14 * hk;
	float width = rr * mix(0.5, 0.22, clamp(up / reach, 0.0, 1.0));
	float t = (1.0 - smoothstep(0.55, 1.0, abs(dx) / width)) * step(0.0, up) * (1.0 - smoothstep(0.55 * reach, reach, up)) * on;
	t *= mix(1.0, smoothstep(-0.2, 0.5, sin(up * 620.0 + hk * 30.0)), smoothstep(0.015, 0.06, up)) * (1.0 - k);
	lens.x -= dx / width * t * 0.35;
	dome.x += dx / width * t * 0.6;
	return max(k, t * 0.7);
}
#endif

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	vec2 p = clamp((UV - pane_min) / (pane_max - pane_min), 0.0, 1.0);
	// Pane space in pane heights (x across, y up).
	vec2 q = vec2(p.x * aspect, p.y);
	vec2 qdx = dFdx(q);
	vec2 qdy = dFdy(q);
	float px = max(length(abs(qdx) + abs(qdy)), 1e-5);
	vec3 pdx = dFdx(VERTEX);
	vec3 pdy = dFdy(VERTEX);

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
			vec4 w = k == 0 ? wiper_a : wiper_b;
			vec2 s = sweep_of(q, w, aspect, wiper_sweep);
			float in_arc = smoothstep(-0.03, 0.03, s.x) * (1.0 - smoothstep(0.97, 1.05, s.x)) * step(0.001, w.w);
			swept = max(swept, in_arc * smoothstep(w.z, w.z + 0.05, s.y) * (1.0 - smoothstep(w.w - 0.02, w.w + 0.02, s.y)));
			ridge = max(ridge, in_arc * smoothstep(w.w - 0.02, w.w + 0.02, s.y) * (1.0 - smoothstep(w.w + 0.03, w.w + 0.09, s.y)));
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

	// From which side: the pane's face towards the eye also faces the cab's inside.
	vec3 face = cross(pdx, pdy);
	face *= sign(dot(face, VIEW));
	float inside = cab_at.w * step(0.0, dot(face, v_cab - VERTEX));
	float mirror = mix(1.0, inside_mirror, inside);

	// The view through dims as the pane mirrors more of the sky, the flatter it is
	// seen (Schlick).
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fres = (0.04 + 0.96 * pow(1.0 - facing, 5.0)) * mix(1.0, 0.6, inside);
	// Premultiplied: the tint and dust are lit in proportion to what they cover. The
	// dust sits on the outside, in front of the glass' own tint; the crack over both.
	float dust = g * 0.85;
	float cover = 1.0 - (1.0 - clarity_loss) * (1.0 - dust);
	vec3 lit = c.rgb * 0.3 * clarity_loss * (1.0 - dust) + grime_color * (0.8 + 0.3 * blotch) * dust;
	float cc = max(line * 0.22, chip * 0.8);
	lit = mix(lit, vec3(0.62, 0.64, 0.64), cc);
	cover = mix(cover, 1.0, cc);
	float alpha = clamp(max(cover, fres), 0.0, 1.0);
	float rough = mix(mix(0.02, 0.6, max(g, chip * 0.4)), 0.02, line);
	// The crack's faces catch the light.
	float spec = (0.5 + 0.5 * line) * mirror;

#ifdef GLASS_RAIN
	float water = rain_wet * rain_pane.y;
	if (water > 0.003) {
		vec2 m = q * rain_pane.x;
		// When a blade last came by here, and which of its strokes that was.
		float since = 1.0e6;
		float wipe = 0.0;
		if (rain_pane.w > 0.5) {
			for (int k = 0; k < 2; k++) {
				vec4 w = k == 0 ? wiper_a : wiper_b;
				vec2 s = sweep_of(q, w, aspect, wiper_sweep);
				if (w.w > 0.001 && s.x > 0.0 && s.x < 1.0 && s.y > w.z && s.y < w.w) {
					// The blade eases out of and into each end of its stroke.
					float u = acos(1.0 - 2.0 * s.x) / PI * wiper_stroke;
					float back = 2.0 * wiper_stroke - u;
					float sn = wiper_t >= back ? wiper_t - back : (wiper_t >= u ? wiper_t - u : wiper_t + wiper_gap + u);
					if (sn < since) {
						since = sn;
						wipe = wiper_count * 2.0 + (wiper_t >= back ? 2.0 : (wiper_t >= u ? 1.0 : 0.0)) + float(k) * 0.37;
					}
				}
			}
		}
		// Heavier rain brings the beads back sooner.
		float build = 2.6 / max(rain_rate * rain_rate * rain_rate, 0.05);
		vec2 lens = vec2(0.0);
		vec2 dome = vec2(0.0);
		float rim = 0.0;
		float drop = beads(m, 0.016, 0.5, wipe * 3.7, 0.0042, water * 0.8, since, build * 0.6, lens, dome, rim);
		drop = max(drop, beads(m + vec2(0.37, 0.11), 0.04, -0.9, wipe * 5.3 + 40.0, 0.0105, water * 0.65, since, build, lens, dome, rim));
		drop = max(drop, runners(m, m.x - rain_slant * rain_pane.z * m.y, since, lens, dome, rim));
		if (drop > 0.002) {
			// What the drop shows: the view through the pane all round it, upside
			// down, and never from beyond the pane's own edges (the cab's inside).
			vec2 o = clamp(q + lens * LENS, vec2(0.03), vec2(aspect - 0.03, 0.97)) - q;
			// Pane -> pixels (the inverse of the pane's screen derivatives).
			float det = qdx.x * qdy.y - qdx.y * qdy.x;
			det = abs(det) > 1e-12 ? det : 1e-12;
			vec2 pix = vec2(qdy.y * o.x - qdy.x * o.y, qdx.x * o.y - qdx.y * o.x) / det;
			pix *= min(1.0, 0.4 * VIEWPORT_SIZE.y / max(length(pix), 0.001));
			vec2 suv = clamp(SCREEN_UV + pix / VIEWPORT_SIZE, vec2(0.002), vec2(0.998));
			vec3 seen = textureLod(screen_tex, suv, 3.5).rgb * EXPOSURE;
			// A drop holds the sky in its lower half and the ground in its upper
			// half, whatever the pane itself looks out on, inside a darker edge.
			seen *= clamp(1.0 - 0.65 * dome.y, 0.5, 1.7) * (1.0 - 0.3 * rim);
			EMISSION = seen * drop * 0.96;
			// It also gathers the daylight from all round (lit like the dust, so none at
			// night): against dark trees a drop is a pale bead, not a black dot.
			lit = lit * (1.0 - drop) + vec3(0.24, 0.25, 0.26) * drop * smoothstep(0.0, 0.7, -dome.y);
			alpha = max(alpha, drop * 0.97);
			rough = mix(rough, 0.05, drop);
			spec = mix(spec, 0.5 * mix(1.0, 0.5, inside), drop);
			// The drop's dome catches the sky and the sun.
			vec3 tq = (pdx * qdy.y - pdy * qdx.y) / det;
			vec3 bq = (pdy * qdx.x - pdx * qdy.x) / det;
			NORMAL = normalize(NORMAL + (normalize(tq) * dome.x + normalize(bq) * dome.y) * 0.8);
		}
	}
#endif

	ALBEDO = lit;
	ALPHA = alpha;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = spec;
}
