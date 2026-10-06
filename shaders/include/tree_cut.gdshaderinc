// A felled tree's trunk (ChoppableTree) is drawn twice, cut where the axe's notch went
// in: the stump keeps what lies under the cut in the column the trunk stands in, the
// falling trunk the rest (what lies over the cut, and whatever hangs lower than the cut
// out beyond the column: low limbs go over with the trunk they grow from, they are not
// left in the air). Both clip against the same face, so they fit together, in the
// shadow pass too. The limbs and the leaf cards are never cut: they all fall. The face,
// in the notch's frame (metres; origin on the trunk's axis at the notch floor, +X out
// through the notch, Y up): the flat floor the axe cut and, behind the notch's crease,
// the hinge wood, torn into splinters. The falling trunk also lacks the wedge the axe
// took out (up to the notch's sloping roof). Needs noise.gdshaderinc.

// xyz: the notch floor on the trunk's axis, in the mesh's space. w: the side kept, 1
// under the cut (the stump), -1 over it (the falling trunk).
instance uniform vec4 cut_origin = vec4(0.0, 0.0, 0.0, 1.0);
// xy: the notch's +X in the mesh's XZ. z: the crease, metres from the axis. w: the slope
// of the notch's roof.
instance uniform vec4 cut_frame = vec4(1.0, 0.0, 0.1, 1.15);
// x: the trunk's mean bark radius (m). y: metres per mesh unit. z: a random seed.
instance uniform vec4 cut_wood = vec4(0.3, 1.0, 0.0, 0.0);

// Fresh wood (as the notch: tree_notch.gdshader).
uniform vec3 sapwood : source_color = vec3(0.8, 0.68, 0.6);
uniform vec3 heartwood : source_color = vec3(0.7, 0.5, 0.4);
uniform vec3 bark_color : source_color = vec3(0.4, 0.3, 0.24);

// A point of the mesh's space in the notch's frame.
vec3 cut_space(vec3 p) {
	vec3 d = p - cut_origin.xyz;
	return vec3(d.x * cut_frame.x + d.z * cut_frame.y, d.y, d.z * cut_frame.x - d.x * cut_frame.y) * cut_wood.y;
}

// A point of the notch's frame in the mesh's space.
vec3 cut_to_mesh(vec3 s) {
	return cut_origin.xyz + vec3(s.x * cut_frame.x - s.z * cut_frame.y, s.y, s.x * cut_frame.y + s.z * cut_frame.x) / cut_wood.y;
}

// Past this distance from the axis (low limbs) the cut is a plane.
float cut_reach() {
	return cut_wood.x * 1.6;
}

// Share of the hinge wood (behind the crease) at x.
float cut_hinge(float x) {
	return smoothstep(cut_frame.z + 0.01, cut_frame.z - 0.01, x);
}

// How far the torn fibres of the hinge stand up from the floor: ridges along the hinge
// line, longer in clumps.
float cut_tear(vec2 s) {
	float clump = vnoise2(s * vec2(11.0, 6.0) + cut_wood.z);
	float fibre = vnoise2(s * vec2(80.0, 18.0) + cut_wood.z * 1.7);
	return 0.006 + clump * clump * 0.05 + fibre * (0.008 + clump * 0.03);
}

// Height of the cut face over (x, z) on this copy's side: the stump's top, or the
// falling trunk's butt with the notch's roof.
float cut_face(vec2 s) {
	float near = step(length(s), cut_reach());
	float h = cut_hinge(s.x) * cut_tear(s) * near;
	if (cut_origin.w < 0.0) {
		float roof = min((s.x - cut_frame.z) * cut_frame.w, (cut_reach() - cut_frame.z) * cut_frame.w);
		h = max(h, roof * near);
	}
	return h;
}

// How far from the trunk's axis the stump reaches at height y (0 at the cut): the trunk's
// own column, wider toward the roots (ChoppableTree.STUMP_COLUMN, STUMP_FLARE).
float cut_column(float y) {
	return cut_reach() + 0.25 + max(-y, 0.0) * 0.5;
}

// Whether this copy keeps the point (in the notch's frame): the stump what is under the
// cut face inside its column, the falling trunk everything else.
bool cut_keeps(vec3 s) {
	bool stump = s.y < cut_face(s.xz) && length(s.xz) < cut_column(s.y);
	return stump == (cut_origin.w > 0.0);
}

// Where the view ray from `cam` to `p` (a back face of the kept bark, seen through the
// opening the cut leaves) meets the cut face: the face is drawn there. False when the
// ray does not cross it (a back face seen through some other gap in the mesh).
bool cut_hit(vec3 cam, vec3 p, out vec3 hit) {
	hit = p;
	vec3 d = p - cam;
	float side = cut_origin.w;
	// The face lies in a band of heights: the ray crosses it there.
	float top = side > 0.0 ? 0.1 : (cut_reach() - cut_frame.z) * cut_frame.w + 0.1;
	vec2 band = abs(d.y) > 1e-5 ? (vec2(-0.001, top) - cam.y) / d.y : vec2(0.0, 1.0);
	float lo = clamp(min(band.x, band.y), 0.0, 1.0);
	float hi = clamp(max(band.x, band.y), 0.0, 1.0);
	vec3 a = cam + d * lo;
	vec3 b = cam + d * hi;
	// The removed side toward the camera, the kept side toward the back face.
	if ((a.y - cut_face(a.xz)) * side <= 0.0 || (b.y - cut_face(b.xz)) * side >= 0.0) {
		return false;
	}
	for (int i = 0; i < 10; i++) {
		float m = (lo + hi) * 0.5;
		vec3 c = cam + d * m;
		if ((c.y - cut_face(c.xz)) * side > 0.0) {
			lo = m;
		} else {
			hi = m;
		}
	}
	hit = cam + d * hi;
	// (A fork's second stem is cut by the same face, out to the column's rim.)
	return length(hit.xz) < cut_column(0.0);
}

// The cut face's normal at (x, z), out of the wood, in the notch's frame.
vec3 cut_normal(vec2 s) {
	float e = 0.003;
	float dx = cut_face(s + vec2(e, 0.0)) - cut_face(s - vec2(e, 0.0));
	float dz = cut_face(s + vec2(0.0, e)) - cut_face(s - vec2(0.0, e));
	return normalize(vec3(-dx, 2.0 * e, -dz)) * cut_origin.w;
}

// A direction of the notch's frame in the mesh's space.
vec3 cut_dir_to_mesh(vec3 n) {
	return vec3(n.x * cut_frame.x - n.z * cut_frame.y, n.y, n.x * cut_frame.y + n.z * cut_frame.x);
}

// Fresh wood of the cut face at `s`: growth rings in sap- and heartwood, the inner and
// outer bark at the rim; over the torn hinge pale pulled fibres, dark between them.
vec3 cut_wood_color(vec3 s, out float rough, out float ao) {
	float r = cut_wood.x;
	float seed = cut_wood.z;
	float rr = length(s.xz);
	float a = atan(s.z, s.x);
	// Growth rings, unevenly spaced: thin darker latewood lines in paler earlywood.
	float wob = (vnoise2(vec2(a * 4.0, rr * 30.0) + seed) - 0.5) * 0.008;
	float rp = (rr + wob) * 58.0 + vnoise2(vec2(rr * 35.0, seed * 1.7)) * 1.8;
	float rf = fract(rp);
	float late = smoothstep(0.55, 0.88, rf) * (1.0 - smoothstep(0.9, 1.0, rf));
	float heart = smoothstep(r * 0.62, r * 0.5, rr);
	vec3 wood = mix(sapwood, heartwood, heart * 0.85);
	wood = mix(wood, wood * vec3(0.72, 0.6, 0.5), late * 0.6);
	wood *= 0.9 + 0.2 * vnoise2(s.xz * 160.0 + seed);
	// A few radial checks from the pith.
	float check = smoothstep(0.96, 1.0, vnoise2(vec2(a * 9.0, seed))) * smoothstep(0.02, 0.06, rr);
	wood *= 1.0 - check * 0.45;
	// The torn hinge: the tips of the pulled fibres pale, the cracks between them dark.
	float hinge = cut_hinge(s.x) * step(rr, cut_reach());
	float tip = smoothstep(0.004, 0.06, cut_tear(s.xz));
	float fib = vnoise2(s.xz * vec2(160.0, 30.0) + seed * 2.3);
	wood = mix(wood, wood * (0.72 + 0.4 * tip) * (0.85 + 0.3 * fib), hinge);
	// Inner bark (cinnamon) and the dark outer bark at the rim.
	float bark_t = 0.01 + r * 0.045;
	float rim = r * 0.93;
	float bn = vnoise2(s.xz * 140.0 + seed);
	float inner = smoothstep(rim - bark_t - 0.004, rim - bark_t, rr);
	vec3 col = mix(wood, vec3(0.5, 0.3, 0.17) * (0.85 + 0.3 * bn), inner);
	float outer = smoothstep(rim - bark_t * 0.55, rim - bark_t * 0.45, rr);
	col = mix(col, bark_color * (0.75 + 0.5 * bn), outer);
	rough = mix(0.72, 0.95, max(hinge, inner));
	ao = mix(1.0, 0.55 + 0.45 * tip, hinge);
	return col;
}
