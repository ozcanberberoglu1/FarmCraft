// A ring of ripples spreading over the pond from where something touched the water (the
// float landing, a nibble, a fish thrashing on the hook). A short train of waves runs
// outward and dies away; drawn as a bumped, glossy film just over the water, so its
// crests catch the sky and the sun like real ripples.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, diffuse_burley, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.1, 0.12, 0.09);
// Waves across the ring's radius.
uniform float wavelength = 0.16;

// 0 .. 1 over the ring's life; how strong the waves start.
instance uniform float age = 0.0;
instance uniform float strength = 1.0;

float waves(float r) {
	// The wave train's front moves out to the edge of the quad (r = 1) over its life.
	float front = 0.08 + age * 0.9;
	float behind = front - r;
	float packet = exp(-pow((behind - 0.1) / 0.13, 2.0)) * step(-0.05, behind);
	float fade = (1.0 - age) * (1.0 - age) / sqrt(max(r, 0.1) * 2.0);
	return sin(behind / wavelength * 6.2832) * packet * fade * strength;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float e = 0.01;
	float h = waves(r);
	float dr = (waves(r + e) - h) / e;
	vec2 grad = r > 0.001 ? p / r * dr : vec2(0.0);
	NORMAL_MAP = normalize(vec3(-grad * 0.035, 1.0)) * 0.5 + 0.5;
	ALBEDO = water_color;
	ROUGHNESS = 0.03;
	SPECULAR = 0.7;
	ALPHA = clamp(abs(dr) * 0.02 + abs(h) * 0.25, 0.0, 0.55) * smoothstep(1.0, 0.85, r);
}
