shader_type spatial;
// The outline of the egg the farmer looks at (Pickup.set_highlight): the egg's own
// mesh turned inside out and grown, so a thin warm line shows round its silhouette.
// The line keeps about the same width on screen (`width` metres per metre from the
// eye), between `width_min` and `width_max`.
render_mode unshaded, cull_front, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.93, 0.7);
uniform float width = 0.0032;
uniform float width_min = 0.002;
uniform float width_max = 0.009;

void vertex() {
	float depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX += NORMAL * clamp(depth * width, width_min, width_max);
}

void fragment() {
	ALBEDO = color;
}
