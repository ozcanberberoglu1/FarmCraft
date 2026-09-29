// Photo-textured PBR surface (Poly Haven albedo / normal / ARM maps).
// Mesh UVs are in meters; `uv_scale` = texture repeats per meter. Triplanar mode ignores
// UVs and projects in world space (rocks, stonework). Vertex color tints the texture:
// mid grey (0.5 sRGB) leaves it unchanged. ARM = R ambient occlusion, G roughness, B metal.
// Age (all off by default): `weathering` bleaches toward silver grey with rain streaks
// down vertical faces, `grime_top` is the world height ground dirt and algae splash up
// to (the farm yard sits at y 0), `rust_amount` eats patches and runs of rust into metal.
// Photo realism (all off by default): `albedo_tint` calibrates a photo that is too bright,
// `ao_albedo` lets its occlusion darken the cracks and gaps, `macro_variation` lays soft
// metre-sized patches of tone over it so the repeat never shows, `streaks` runs dark
// water stains down vertical faces, `lichen_amount` spots it with pale grey-green lichen.
// Every world-space mask reads its value noise from `noise_tex` (Mats.noise_texture():
// two bilinear fetches a lookup instead of eight hashes), so they cost little. They are
// fixed in the world: only for things that never move (see the *_ext keys in Mats).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 0.5;
uniform bool triplanar = false;
uniform float triplanar_sharpness = 6.0;
uniform float normal_strength = 1.0;
uniform float roughness_mult = 1.0;
uniform float tint_strength = 1.0;
uniform float ao_strength = 0.7;
uniform float snow_accumulates : hint_range(0.0, 1.0) = 1.0;
uniform float moss_amount : hint_range(0.0, 1.0) = 0.0;
uniform float weathering : hint_range(0.0, 1.0) = 0.0;
uniform float grime_top = 0.0;
uniform float rust_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 albedo_tint = vec3(1.0);
uniform float ao_albedo : hint_range(0.0, 1.0) = 0.0;
uniform float macro_variation : hint_range(0.0, 1.0) = 0.0;
uniform float streaks : hint_range(0.0, 1.0) = 0.0;
uniform float lichen_amount : hint_range(0.0, 1.0) = 0.0;
// Random texels (Mats.noise_texture(), NOISE_SIZE square, R8), filtered and repeated.
uniform sampler2D noise_tex : hint_default_black, filter_linear, repeat_enable;

varying vec3 v_wpos;
varying vec3 v_wnormal;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 unpack_normal(vec4 t) {
	vec2 xy = t.xy * 2.0 - 1.0;
	return vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
}

// Smooth 3D value noise in 0..1 from the random texture: the lattice layer z sits at
// texel offset (37, 17) * z, so layers z and z + 1 are two bilinear fetches mixed.
float tnoise(vec3 x) {
	vec3 p = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	vec2 uv = mod(p.xy + vec2(37.0, 17.0) * p.z, 256.0) + f.xy + 0.5;
	float a = textureLod(noise_tex, uv * (1.0 / 256.0), 0.0).r;
	float b = textureLod(noise_tex, (uv + vec2(37.0, 17.0)) * (1.0 / 256.0), 0.0).r;
	return mix(a, b, f.z);
}

vec3 tint_from_color(vec3 c) {
	vec3 s = pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)) * 2.0;
	return mix(vec3(1.0), s, tint_strength);
}

void fragment() {
	vec3 albedo;
	vec3 arm;
	vec3 wn = normalize(v_wnormal);
	if (triplanar) {
		vec3 w = pow(abs(wn), vec3(triplanar_sharpness));
		w /= (w.x + w.y + w.z);
		vec3 p = v_wpos * uv_scale;
		albedo = texture(albedo_tex, p.zy).rgb * w.x + texture(albedo_tex, p.xz).rgb * w.y + texture(albedo_tex, p.xy).rgb * w.z;
		arm = texture(arm_tex, p.zy).rgb * w.x + texture(arm_tex, p.xz).rgb * w.y + texture(arm_tex, p.xy).rgb * w.z;
		// Whiteout-blended triplanar normals, built in world space.
		vec3 nx = unpack_normal(texture(normal_tex, p.zy));
		vec3 ny = unpack_normal(texture(normal_tex, p.xz));
		vec3 nz = unpack_normal(texture(normal_tex, p.xy));
		nx.xy *= normal_strength;
		ny.xy *= normal_strength;
		nz.xy *= normal_strength;
		nx = vec3(nx.xy + wn.zy, abs(nx.z) * wn.x);
		ny = vec3(ny.xy + wn.xz, abs(ny.z) * wn.y);
		nz = vec3(nz.xy + wn.xy, abs(nz.z) * wn.z);
		vec3 world_n = normalize(nx.zyx * w.x + ny.xzy * w.y + nz.xyz * w.z);
		NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);
		wn = world_n;
	} else {
		vec2 uv = UV * uv_scale;
		albedo = texture(albedo_tex, uv).rgb;
		arm = texture(arm_tex, uv).rgb;
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	albedo *= tint_from_color(COLOR.rgb) * albedo_tint;
	if (ao_albedo > 0.0) {
		albedo *= mix(1.0, arm.r, ao_albedo);
	}
	if (macro_variation > 0.0) {
		// Soft patches of tone and warmth a metre or two across.
		float m = tnoise(v_wpos * 0.23) * 0.6 + tnoise(v_wpos * 0.87 + vec3(5.2, 1.3, 7.9)) * 0.4;
		float k = (m - 0.5) * macro_variation;
		albedo *= (1.0 + k * 0.55) * vec3(1.0 + k * 0.12, 1.0, 1.0 - k * 0.16);
	}
	// Walls and other steep faces: where rain runs down.
	float side = 1.0 - smoothstep(0.3, 0.7, abs(wn.y));
	if (streaks > 0.0 && side > 0.0) {
		// Rain runs down the walls: long thin stains, fading in and out along the fall line.
		float run = smoothstep(0.55, 0.85, tnoise(v_wpos * vec3(8.0, 0.3, 8.0)))
				* smoothstep(0.3, 0.75, tnoise(v_wpos * vec3(1.9, 0.55, 1.9) + vec3(11.0, 3.0, 5.0)));
		albedo *= 1.0 - streaks * 0.4 * run * side;
	}
	float rust = 0.0;
	if (weathering > 0.0) {
		// Sun-bleached: toward a warm silver grey, patchy, with darker rain runs.
		float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
		float blot = 0.7 + 0.6 * tnoise(v_wpos * 0.9);
		albedo = mix(albedo, vec3(lum) * vec3(1.05, 1.03, 0.98) * 1.1, clamp(weathering * blot, 0.0, 1.0));
		if (abs(wn.y) < 0.98) {
			float runs = tnoise(v_wpos * vec3(7.0, 0.35, 7.0)) * tnoise(v_wpos * vec3(2.3, 0.9, 2.3));
			albedo *= 1.0 - weathering * 0.45 * smoothstep(0.25, 0.6, runs) * (1.0 - abs(wn.y));
		}
	}
	if (rust_amount > 0.0) {
		// Patches, plus runs that follow the fall line (long in y).
		float n = tnoise(v_wpos * vec3(1.2, 2.2, 1.2)) * 0.6 + tnoise(v_wpos * 5.5) * 0.25
				+ tnoise(v_wpos * vec3(9.0, 0.8, 9.0)) * 0.25;
		rust = smoothstep(0.5, 0.78, n) * rust_amount;
		if (rust > 0.0) {
			vec3 rust_col = srgb(mix(vec3(0.42, 0.22, 0.11), vec3(0.55, 0.36, 0.2), tnoise(v_wpos * 13.0)));
			albedo = mix(albedo, rust_col * (0.75 + 0.5 * tnoise(v_wpos * 31.0)), rust);
		}
	}
	if (grime_top > 0.0 && v_wpos.y < grime_top + 0.25) {
		// Splashed dirt near the ground, greening where it stays damp.
		float h = v_wpos.y + (tnoise(v_wpos * vec3(2.3, 0.7, 2.3)) - 0.5) * 0.4;
		float g = 1.0 - smoothstep(0.0, grime_top, h);
		float algae = smoothstep(0.45, 0.75, tnoise(v_wpos * 1.6 + vec3(3.1, 0.0, 7.7)));
		vec3 dirt = mix(srgb(vec3(0.68, 0.6, 0.48)), srgb(vec3(0.56, 0.63, 0.4)), algae);
		albedo = mix(albedo, albedo * dirt, g * g * 0.85);
	}
	if (moss_amount > 0.0 && wn.y > -0.05) {
		// On what faces up, in patches (damp spots, not a coat of green paint).
		float up = smoothstep(0.35, 0.85, wn.y + (tnoise(v_wpos * 1.3) - 0.5) * 0.8);
		float patches = smoothstep(0.45, 0.72, tnoise(v_wpos * 0.55) * 0.7 + tnoise(v_wpos * 2.9) * 0.3);
		float moss = up * patches * moss_amount;
		albedo = mix(albedo, srgb(vec3(0.21, 0.26, 0.12)) * (0.7 + 0.5 * tnoise(v_wpos * 7.0)), moss);
	}
	// Centimetre detail fades out by 30 m, before it turns to shimmer (and costs nothing
	// past that).
	float near = 1.0 - smoothstep(10.0, 30.0, length(VERTEX));
	if (lichen_amount > 0.0 && near > 0.0) {
		// Crusty rosettes, a few centimetres across, in loose colonies.
		float l = tnoise(v_wpos * 11.0) * 0.7 + tnoise(v_wpos * 29.0) * 0.3;
		float aa = fwidth(l);
		float spots = smoothstep(0.62 - aa, 0.7 + aa, l) * smoothstep(0.4, 0.7, tnoise(v_wpos * 1.6 + vec3(2.0, 7.0, 4.0))) * near;
		vec3 lichen = srgb(mix(vec3(0.6, 0.64, 0.5), vec3(0.7, 0.69, 0.56), tnoise(v_wpos * 3.1)));
		albedo = mix(albedo, lichen, spots * lichen_amount);
	}
	float snow = clamp((wn.y - 0.55) * 4.0, 0.0, 1.0) * snow_amount * snow_accumulates;
	albedo = mix(albedo, snow_color(), snow);
	float wet = wetness * snow_accumulates;
	ALBEDO = albedo * (1.0 - wet * 0.3);
	ROUGHNESS = clamp(arm.g * roughness_mult * (1.0 + rust * 0.3), 0.04, 1.0) * mix(1.0, 0.55, wet);
	AO = mix(1.0, arm.r, ao_strength);
	METALLIC = arm.b * (1.0 - rust);
	SPECULAR = 0.5;
}
