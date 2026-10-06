shader_type spatial;
// The shimmer of an egg lying about (Pickup, HatchingEgg): a shell drawn a little
// larger than the egg that adds a soft halo of light round its outline and, now and
// then, a glint passing along it, so eggs show in the grass and the straw. Only near
// by: it fades in between `fade_end` and `fade_full` metres from the eye (the shell is
// not drawn at all beyond its visibility range). The egg the farmer looks at (`aimed`)
// is lit more.
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.93, 0.74);
// How far the shell stands off the egg: metres per metre from the eye (so the halo is
// about as wide on screen from anywhere), between `halo_min` and `halo_max` metres.
uniform float halo = 0.0042;
uniform float halo_min = 0.003;
uniform float halo_max = 0.012;
uniform float fade_end = 4.0;
uniform float fade_full = 2.8;
// The egg's length along its own Y (it stands on its base at the origin).
uniform float egg_length = 0.058;
uniform float rim_strength = 0.55;
uniform float glint_strength = 0.45;
instance uniform float aimed = 0.0;
// Each egg glints in its own time (0..1).
instance uniform float phase = 0.0;

varying float v_fade;
varying float v_along;

void vertex() {
	v_along = VERTEX.y / egg_length;
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += NORMAL * clamp(dist * halo, halo_min, halo_max);
	v_fade = 1.0 - smoothstep(fade_full, fade_end, dist);
}

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	// Brightest at the shell's own outline (just outside the egg's), nothing in the middle.
	float rim = pow(1.0 - ndv, 1.7);
	// The glint crosses the egg in the first third of each cycle (about every 4 s).
	float cycle = fract(TIME * 0.24 + phase);
	float band = 1.0 - smoothstep(0.0, 0.22, abs(v_along - (cycle * 3.6 - 0.3)));
	float breathe = 0.72 + 0.28 * sin(TIME * 1.7 + phase * 6.2831);
	float glow = rim * rim_strength * breathe + band * glint_strength * (0.35 + 0.65 * ndv);
	ALBEDO = tint * (glow * v_fade * (1.0 + aimed * 0.7) + aimed * rim * 0.4);
}
