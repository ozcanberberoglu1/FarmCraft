// Wind for the photo trees (NatureModels.tree): the bark and the leaf cards of a tree use
// the same motion, so the crown never slides off its limbs. Vertex COLOR (see
// tools/blender/build_trees.py): g = trunk bend weight ((height / tree height)^2),
// b = random per card (phase), a = reach (0 at the trunk, 1 at the crown's rim).
// The offsets are worked out in world space and turned into the mesh's own space.

// Metres the tree top leans in a full gust, how far the limbs bob, leaf flutter.
uniform float sway = 0.22;
uniform float branch_sway = 0.1;
uniform float flutter = 0.025;

vec3 tree_wind(vec3 vertex, vec4 col, mat4 model, float t) {
	vec3 origin = model[3].xyz;
	float phase = hash12(origin.xz * 0.37) * 6.2831853;
	// Gusts sweep over the forest: neighbours move alike, far trees differently.
	float gust = vnoise2(origin.xz * 0.012 + vec2(t * 0.09, t * 0.04));
	vec2 dir = normalize(vec2(1.0, 0.35));
	vec3 wdir = vec3(dir.x, 0.0, dir.y);
	float lean = (0.62 + 0.38 * sin(t * 0.55 + phase)) * (0.25 + 0.75 * gust);
	vec3 off = wdir * lean * col.g * sway;
	// Limbs bob up and down and back with the gusts, each card in its own phase.
	float bob = sin(t * 1.6 + phase + col.b * 6.2831853) * (0.4 + gust);
	off += vec3(wdir.x * 0.5, 0.7, wdir.z * 0.5) * bob * col.a * col.a * branch_sway;
	// Leaves flutter.
	vec3 wp = (model * vec4(vertex, 1.0)).xyz;
	off += vec3(sin(t * 6.1 + wp.x * 2.3 + col.b * 17.0), sin(t * 5.3 + wp.y * 2.9) * 0.5,
			cos(t * 7.3 + wp.z * 2.1 + col.b * 11.0)) * flutter * col.a * (0.35 + gust);
	off *= wind_strength;
	// World offset -> the mesh's space (rotation and uniform scale).
	mat3 b = mat3(model);
	return transpose(b) * off / max(dot(b[0], b[0]), 1e-6);
}
