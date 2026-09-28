// Hay / straw: fine fibres along the mesh U direction with color streaks.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform float fiber_scale = 90.0;

void fragment() {
	vec2 uv = UV;
	// Fibres run along U with random bends; several layers give a matted look.
	vec2 p = vec2(uv.x * 3.0 + vnoise2(uv * vec2(8.0, 40.0)) * 0.6, uv.y * fiber_scale);
	float fibers = vnoise2(p);
	float fine = vnoise2(p * vec2(1.7, 2.3) + 13.0);
	float streak = vnoise2(vec2(uv.x * 0.8, uv.y * fiber_scale * 0.2));
	float dark = smoothstep(0.55, 0.8, vnoise2(p * vec2(2.0, 1.4) + 5.0));
	vec3 col = COLOR.rgb * (0.62 + 0.5 * fibers + 0.2 * fine) * (0.85 + 0.3 * streak);
	col = mix(col, col * vec3(0.45, 0.4, 0.3), dark * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
	NORMAL_MAP = normalize(vec3(0.5 + (fibers - 0.5) * 0.5, 0.5, 1.0));
}
