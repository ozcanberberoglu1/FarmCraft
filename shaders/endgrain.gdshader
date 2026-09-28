// Cut log face: growth rings, a darker bark rim and radial cracks. UVs are in
// meters, centered on the log axis.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/noise.gdshaderinc"

uniform float log_radius = 0.07;

void fragment() {
	float r = length(UV);
	float a = atan(UV.y, UV.x);
	float wobble = (vnoise2(vec2(a * 3.0, r * 20.0)) - 0.5) * 0.004;
	float rings = sin((r + wobble) * 260.0) * 0.5 + 0.5;
	float crack = smoothstep(0.985, 1.0, vnoise2(vec2(a * 9.0, 1.0))) * smoothstep(0.01, 0.03, r);
	vec3 wood = mix(srgb(vec3(0.83, 0.68, 0.47)), srgb(vec3(0.66, 0.5, 0.32)), rings * 0.6);
	wood *= 0.85 + 0.3 * vnoise2(UV * 180.0);
	float rim = smoothstep(log_radius * 0.82, log_radius * 0.95, r);
	vec3 col = mix(wood, srgb(vec3(0.3, 0.22, 0.15)), rim);
	col *= 1.0 - crack * 0.6;
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
