// Vehicle wheel, modelled by tools/build_pickup_hd.py: one material per `part`.
// The mesh's vertex colour says where a point is: r exposure (tread block tops 1,
// groove floors 0, sidewall about 0.6), g distance from the axle over the tyre
// radius, b raised sidewall marks (lettering, serrations, ribs).
// - Rubber: a weathered charcoal; block tops scuffed lighter, dust caked in the
//   grooves and down the shoulders, a lighter film on the sidewall, letters catching it.
// - Rim: polished metal or, with `rim_paint` > 0, painted steel; brake dust gathers
//   towards the hub and in the barrel, and with `rust` the paint breaks into pits.
// - Hardware (nuts, hub cap, valve cap): chrome going dull and rusty with wear.
// - Brake: cast iron, the discs' friction faces machined bright, the rest rusty.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

// 0 rubber, 1 rim, 2 hardware, 3 brake.
uniform int part = 0;
uniform vec3 rubber : source_color = vec3(0.16, 0.16, 0.16);
uniform float wear = 0.3;
uniform vec3 dirt_color : source_color = vec3(0.45, 0.39, 0.3);
uniform vec3 brake_dust : source_color = vec3(0.24, 0.17, 0.11);
uniform vec3 rim_color : source_color = vec3(0.75, 0.75, 0.74);
// 0: bare polished metal, 1: painted steel.
uniform float rim_paint = 0.0;
uniform float rust = 0.0;
uniform sampler2D pit_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Rust pit texture repeats per metre, on the wheel's face.
uniform float pit_scale = 5.0;

// The wheel's own space: its axle is the mesh's y axis.
varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	float expo = COLOR.r;
	float radial = COLOR.g;
	float raised = COLOR.b;
	float n = vnoise3(v_local * 9.0);
	float fine = vnoise3(v_local * 160.0);
	vec3 pit = texture(pit_albedo, v_local.xz * pit_scale).rgb;
	if (part == 0) {
		float top = step(0.9, expo);
		float groove = 1.0 - smoothstep(0.05, 0.3, expo);
		float wall = 1.0 - max(top, groove);
		// Scuffed, slightly greyer block tops; the raised marks a shade lighter.
		vec3 col = rubber * (0.82 + 0.2 * n + 0.1 * fine);
		col = mix(col, col * vec3(1.18, 1.16, 1.12), top * (0.5 + 0.5 * fine));
		col *= 1.0 + 0.12 * raised;
		// Caked in the grooves, dusted on the tops and down the shoulders, a film on
		// the sidewall that the raised marks catch more of.
		float shoulder = smoothstep(0.93, 0.86, radial) * smoothstep(0.78, 0.86, radial);
		float dust = groove * (0.55 + 0.45 * n) + top * 0.18 * fine
				+ wall * (0.3 + 0.4 * shoulder + 0.18 * raised) * (0.6 + 0.8 * n);
		dust = clamp(dust * wear * 1.35, 0.0, 0.92);
		col = mix(col, dirt_color * (0.62 + 0.3 * n), dust * 0.8);
		ALBEDO = col * (1.0 - wetness * 0.3);
		ROUGHNESS = clamp(mix(mix(0.78 - 0.1 * raised, 0.84, top) + 0.08 * fine, 0.95, dust) * mix(1.0, 0.55, wetness), 0.2, 1.0);
		METALLIC = 0.0;
		SPECULAR = 0.3;
		AO = mix(0.45, 1.0, smoothstep(0.0, 0.5, expo));
	} else if (part == 3) {
		// Cast iron: bright machined friction faces with fine turning marks; the hat,
		// vanes and drums brown with surface rust.
		float face = step(0.9, expo);
		float turning = 0.5 + 0.5 * sin(radial * 900.0 + fine * 3.0);
		vec3 iron = vec3(0.36, 0.35, 0.34) * (0.85 + 0.2 * n);
		vec3 rusty = mix(vec3(0.2, 0.19, 0.18), pit * vec3(0.55, 0.36, 0.24), clamp(0.35 + rust * 0.6, 0.0, 1.0));
		vec3 col = mix(rusty, iron * (0.92 + 0.12 * turning), face);
		ALBEDO = mix(col, brake_dust * (0.7 + 0.4 * n), 0.25 * (1.0 - face)) * (1.0 - wetness * 0.2);
		ROUGHNESS = mix(0.8, 0.28 + 0.1 * turning, face);
		METALLIC = mix(0.2, 0.9, face);
		SPECULAR = 0.5;
		AO = mix(0.5, 0.85, face);
	} else {
		// Rim and hardware: the barrel inside the tyre (exposure below 0.9) stays in
		// the wheel's shade and gathers the most brake dust.
		float deep = 1.0 - step(0.9, expo);
		float hub = 1.0 - smoothstep(0.2, 0.55, radial);
		bool hardware = part == 2;
		vec3 painted = rim_color * (0.9 + 0.1 * n);
		vec3 bare = rim_color * (0.92 + 0.08 * fine);
		vec3 col = hardware ? bare : mix(bare, painted, rim_paint);
		float rough = hardware ? mix(0.1, 0.42, wear) : mix(0.1 + 0.25 * wear, 0.42, rim_paint);
		float metal = hardware ? 1.0 : mix(1.0, 0.12, rim_paint);
		// Rust pits: through the paint from the nuts and the hub outwards; the nuts
		// and cap themselves bloom with it.
		float spots = clamp((pit.r - pit.b - 0.08) * 2.7, 0.0, 1.0);
		float sev = rust * (hardware ? 0.9 : 0.35 + 0.6 * hub + 0.3 * deep) * (0.6 + 0.8 * n);
		float rusted = smoothstep(1.0 - sev, 1.06 - sev, spots);
		col = mix(col, pit * vec3(0.5, 0.36, 0.26), rusted);
		rough = mix(rough, 0.85, rusted);
		metal *= 1.0 - rusted;
		// Brake dust towards the hub and in the barrel, road dust over it all.
		float bd = clamp(wear * (0.15 + 0.55 * hub + 0.5 * deep) * (0.6 + 0.8 * n), 0.0, 1.0) * 0.75;
		col = mix(col, brake_dust * (0.8 + 0.3 * n), bd);
		float dust = clamp(wear * (0.2 + 0.3 * hub) * (0.6 + 0.8 * n), 0.0, 1.0) * 0.5;
		col = mix(col, dirt_color * (0.65 + 0.3 * n), dust);
		ALBEDO = col * (1.0 - wetness * 0.2) * mix(1.0, 0.55, deep);
		ROUGHNESS = clamp(mix(rough, 0.9, max(dust, bd)) * mix(1.0, 0.6, wetness), 0.05, 1.0);
		METALLIC = metal * (1.0 - max(dust, bd));
		SPECULAR = 0.5;
		AO = mix(1.0, 0.55, deep);
	}
}
