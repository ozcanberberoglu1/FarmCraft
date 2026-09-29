// Depth squeeze for the distant landscape (scripts/world/backdrop.gd): its mesh and
// trees reach kilometres past the camera's far plane. The vertex shaders keep the true
// position for lighting and fog (VERTEX) but draw everything beyond BACKDROP_START of
// the far plane squeezed into the next BACKDROP_SPAN of it (POSITION): same place on
// screen, same order along each view ray, never clipped. Real geometry stays nearer
// than that from any spot the player can reach (0.86 x 600 m for the player camera),
// so it always hides the backdrop behind it.

const float BACKDROP_START = 0.86;
const float BACKDROP_SPAN = 0.12;
// Distance over which the squeeze closes in on the end of its span (metres).
const float BACKDROP_FALLOFF = 1400.0;

// Distance to the camera's far plane. Unprojects both ends of the depth range and takes
// the farther, so it holds for reversed and standard depth alike.
float backdrop_camera_far(mat4 inv_projection) {
	vec4 a = inv_projection * vec4(0.0, 0.0, 0.0, 1.0);
	vec4 b = inv_projection * vec4(0.0, 0.0, 1.0, 1.0);
	return max(abs(a.z / a.w), abs(b.z / b.w));
}

// Clip-space position of world point `world`, squeezed as described above.
vec4 backdrop_position(vec3 world, mat4 view, mat4 projection, mat4 inv_projection) {
	vec3 v = (view * vec4(world, 1.0)).xyz;
	float d = max(length(v), 0.001);
	float far_d = backdrop_camera_far(inv_projection);
	float start = far_d * BACKDROP_START;
	float dc = d <= start ? d : start + far_d * BACKDROP_SPAN * (1.0 - exp((start - d) / BACKDROP_FALLOFF));
	return projection * vec4(v * (dc / d), 1.0);
}
