// Water drops (Fx: the watering can's stream, splashes, drips): small clear beads
// stretched along their flight, mostly reflection and a bright glint. Whatever falls
// below `floor_y` is hidden, so a stream ends where it lands.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.42, 0.47, 0.5);
uniform float opacity = 0.3;
uniform float floor_y = -1000000.0;

void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (w.y < floor_y) {
		discard;
	}
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - facing, 3.0);
	// Clear water: little colour of its own, the sky and sun mirrored at the edges.
	ALBEDO = water_color * COLOR.rgb;
	ROUGHNESS = 0.03;
	SPECULAR = 1.0;
	ALPHA = clamp((opacity + fres * 0.6) * COLOR.a, 0.0, 1.0);
}
