// Vehicle body paint: clear-coated colour that wears towards the sills and wheel
// arches (dust and mud build up low on the body), darker and glossier in the rain.
// An old vehicle also gets sun-faded, chalky paint on the surfaces facing the sky
// (`fade`), rust eating through the sills and blistering the panels (`rust`) and
// grime streaks running down its sides (`streaks`); all 0 leaves the plain paint.
// `local_up` / `ground_h` give height above the wheels' contact plane in mesh space
// (ground_h per mesh: every body panel has its own origin).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform vec3 paint : source_color = vec3(0.05, 0.09, 0.2);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform float roughness = 0.32;
uniform float metallic = 0.35;
uniform float clearcoat = 0.45;
uniform float wear = 0.55;
uniform float fade = 0.0;
uniform float rust = 0.0;
uniform float streaks = 0.0;
uniform vec3 rust_color : source_color = vec3(0.36, 0.17, 0.08);
uniform vec3 local_up = vec3(0.0, 1.0, 0.0);
instance uniform float ground_h = 0.0;
uniform vec3 dirt_color : source_color = vec3(0.42, 0.36, 0.28);

varying float v_height;
varying float v_top;
varying vec3 v_local;

void vertex() {
	v_height = dot(VERTEX, local_up) - ground_h;
	// How much the surface faces the sky (1 roof and bonnet, 0 doors, -1 underside).
	v_top = dot(NORMAL, local_up);
	v_local = VERTEX;
}

void fragment() {
	float n = vnoise3(v_local * 3.1) * 0.6 + vnoise3(v_local * 11.0) * 0.4;
	// Dust low on the body, spattered upwards; a faint film everywhere.
	float low = 1.0 - smoothstep(0.25, 0.95, v_height + (n - 0.5) * 0.35);
	float dirt = clamp(low * 0.85 + 0.12, 0.0, 1.0) * wear;
	dirt *= smoothstep(0.2, 0.55, n + low * 0.3);
	vec3 base = paint * (0.92 + 0.16 * vnoise3(v_local * 0.8));
	float chalk = 0.0;
	float rusted = 0.0;
	float rim = 0.0;
	float streak = 0.0;
	vec3 rc = rust_color;
	if (fade > 0.0) {
		// Sun-bleached: pale and chalky on top, milder down the sides, in blotches.
		float top = smoothstep(0.15, 0.9, v_top);
		chalk = clamp(fade * (0.45 + 0.55 * top) * (0.65 + 0.7 * vnoise3(v_local * 1.7)), 0.0, 1.0);
		float grey = dot(base, vec3(0.3, 0.59, 0.11));
		base = mix(base, mix(vec3(grey), base, 0.55) * 1.6 + 0.035, chalk);
	}
	if (rust > 0.0) {
		// Rust breaks through where the noise rises above a threshold that drops low
		// on the body (sills, arches, door bottoms up to about a metre) and a little on
		// flat tops where water stands. A darker, bubbled rim of paint surrounds each
		// patch. With rust 0.7 about half the sills are gone, the doors get odd spots.
		float sill = 1.0 - smoothstep(0.55, 1.15, v_height + (n - 0.5) * 0.3);
		float rn = vnoise3(v_local * 2.4) * 0.55 + vnoise3(v_local * 8.0) * 0.3 + vnoise3(v_local * 26.0) * 0.15;
		float edge_in = 1.02 - rust * (0.3 + 0.55 * sill + 0.15 * smoothstep(0.5, 0.95, v_top));
		rusted = smoothstep(edge_in, edge_in + 0.035, rn);
		rim = smoothstep(edge_in - 0.06, edge_in, rn) - rusted;
		// Orange flakes on dark brown scale.
		rc = mix(rust_color * 0.55, rust_color * 1.35, vnoise3(v_local * 38.0));
		// Raised, flaking rust shows through the road dust (low on the body the dust
		// would otherwise hide most of the sill rust).
		dirt *= 1.0 - 0.5 * rusted;
	}
	if (streaks > 0.0) {
		// Grime run down the sides: noise stretched along `local_up`, fine across it.
		float h = dot(v_local, local_up);
		vec3 across = v_local - local_up * h;
		float s = vnoise3(across * 17.0 + local_up * h * 0.8) * 0.7 + vnoise3(across * 41.0 + local_up * h * 2.0) * 0.3;
		float side = 1.0 - smoothstep(0.35, 0.8, abs(v_top));
		streak = smoothstep(0.52, 0.78, s) * side * streaks;
	}
	vec3 col = mix(base, base * 0.55 + rc * 0.2, rim);
	col = mix(col, col * 0.62 + dirt_color * 0.08, streak * 0.7);
	col = mix(col, rc, rusted);
	col = mix(col, dirt_color * (0.75 + 0.3 * n), dirt);
	float wet = wetness;
	ALBEDO = col * (1.0 - wet * 0.25);
	float rough = mix(roughness, 0.7, chalk);
	rough = mix(rough, 0.8, streak * 0.6);
	rough = mix(rough, 0.93, rusted);
	ROUGHNESS = mix(rough, 0.85, dirt) * mix(1.0, 0.45, wet);
	METALLIC = metallic * (1.0 - dirt) * (1.0 - rusted);
	SPECULAR = 0.5;
	CLEARCOAT = clearcoat * (1.0 - dirt) * (1.0 - rusted) * (1.0 - chalk);
	CLEARCOAT_ROUGHNESS = mix(0.06, 0.4, wear * 0.5);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 0.4 * (1.0 - rusted * 0.5);
	}
}
