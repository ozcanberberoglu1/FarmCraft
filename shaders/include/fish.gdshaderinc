// Shared by the bending fish shaders (fish.gdshader: the body, fish_fin.gdshader: the
// thin fins, drawn from both sides): the tail beat and arch, and the model's own look.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform bool has_albedo_tex = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool has_normal_tex = false;
uniform float normal_scale = 1.0;
uniform float roughness = 0.3;
uniform float metallic = 0.0;
uniform float clearcoat = 0.0;
// Half the fish's length in model units.
uniform float half_length = 0.25;

// Tail beat (0 still .. 1 thrashing), its phase (radians) and a C-arch (-1 .. 1).
instance uniform float flex = 0.0;
instance uniform float flex_phase = 0.0;
instance uniform float curl = 0.0;

// The sideways offset at x (model units) and its slope.
vec2 bend(float x) {
	float u = x / half_length;
	// 0 behind the head .. 1 at the tail tip.
	float t = clamp((0.55 - u) / 1.55, 0.0, 1.0);
	float amp = flex * half_length * 0.42 * t * t;
	float k = 3.2 / 1.55 / half_length;
	float s = sin(flex_phase - t * 3.2);
	float c = cos(flex_phase - t * 3.2);
	float off = amp * s;
	// d(off)/dx: amp' * s + amp * c * (-dt/dx * 3.2); dt/dx = -1 / (1.55 * half_length).
	float damp = flex * half_length * 0.42 * 2.0 * t * (-1.0 / (1.55 * half_length));
	float slope = damp * s + amp * c * k;
	// The arch: a parabola through the middle of the body.
	float a = curl * half_length * 0.35;
	off += a * (u * u - 0.33);
	slope += a * 2.0 * u / half_length;
	return vec2(off, slope);
}

void vertex() {
	vec2 b = bend(VERTEX.x);
	VERTEX.z += b.x;
	NORMAL = normalize(vec3(NORMAL.x - b.y * NORMAL.z, NORMAL.y, NORMAL.z));
	TANGENT = normalize(vec3(TANGENT.x, TANGENT.y, TANGENT.z + b.y * TANGENT.x));
}

void fragment() {
	vec4 c = albedo;
	if (has_albedo_tex) {
		c *= texture(albedo_tex, UV);
	}
	ALBEDO = c.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = 0.08;
	if (has_normal_tex) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
