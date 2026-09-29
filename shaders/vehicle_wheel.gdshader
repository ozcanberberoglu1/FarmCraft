// Vehicle wheel from the model's tyre atlas: the tread strip along the top, the
// sidewall ring around its middle, the rim on a metal gradient strip at the right.
// Rubber gets a weathered charcoal instead of the atlas' ink black, tread blocks and
// raised sidewall letters in relief (from the atlas' own shading; the letters are the
// same rubber, only their relief shows), road dust in the grooves, on the tread and
// the shoulders, a lighter film down the sidewall. The rim is polished metal or, with
// `rim_paint` > 0, painted steel; brake dust gathers towards the hub, and with `rust`
// the paint breaks into rust pits, worst round the nuts.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
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
// Atlas layout: the rim strip's left edge and top, the sidewall ring's centre and
// radii, the bottom of the tread strip.
uniform vec2 rim_from = vec2(0.84, 0.34);
uniform vec2 wall_center = vec2(0.415, 0.586);
uniform vec2 wall_radii = vec2(0.24, 0.4);
uniform float tread_end = 0.175;
uniform float relief = 1.4;

// The wheel's own space: its axle is the mesh's y axis.
varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	float n = vnoise3(v_local * 9.0);
	// Sampled up front: texture lookups in a branch that splits a pixel quad lose
	// their mip level.
	float lum = dot(a.rgb, vec3(0.333));
	vec2 e = vec2(1.5 / 1024.0, 0.0);
	float lx = dot(texture(albedo_tex, UV + e.xy).rgb, vec3(0.333)) - lum;
	float ly = dot(texture(albedo_tex, UV + e.yx).rgb, vec3(0.333)) - lum;
	vec3 pit = texture(pit_albedo, v_local.xz * pit_scale).rgb;
	bool rim = UV.x > rim_from.x && UV.y > rim_from.y;
	if (!rim) {
		// Rubber: the atlas' shading (0 in the grooves) becomes relief and tone.
		float tone = clamp(lum / 0.012, 0.0, 1.6);
		float tread = 1.0 - step(tread_end, UV.y);
		float r = length(UV - wall_center);
		// 0 at the rim bead, 1 at the shoulder.
		float out_wall = clamp((r - wall_radii.x) / (wall_radii.y - wall_radii.x), 0.0, 1.0);
		// On the sidewall the lettering is the same rubber: its tone evens out.
		float t = mix(mix(1.0, min(tone, 1.2), 0.35), tone, tread);
		vec3 col = rubber * (0.6 + 0.35 * t) * (0.92 + 0.16 * n);
		float groove = 1.0 - smoothstep(0.2, 0.9, tone);
		float shoulder = max(tread, smoothstep(0.8, 1.0, out_wall));
		// Caked on the tread and in its grooves, down the shoulders; a lighter film on
		// the sidewall.
		float dust = mix(0.12 + 0.3 * smoothstep(0.5, 1.0, out_wall), 0.55 + 0.4 * groove, tread);
		dust = clamp(dust * wear * (0.7 + 0.6 * n) * 1.3, 0.0, mix(0.45, 1.0, shoulder));
		col = mix(col, dirt_color * (0.7 + 0.3 * n), dust * 0.75);
		ALBEDO = col * (1.0 - wetness * 0.3);
		ROUGHNESS = mix(mix(0.72, 0.86, tread), 0.95, dust) * mix(1.0, 0.6, wetness);
		METALLIC = 0.0;
		SPECULAR = 0.35;
		AO = mix(1.0, orm.r, 0.5) * (0.75 + 0.25 * tone);
		NORMAL_MAP = normalize(vec3(-lx * relief * 40.0, ly * relief * 40.0, 1.0)) * 0.5 + 0.5;
	} else {
		// Rim: the strip runs from the bright outer face (top) to the dark hub (bottom).
		float s = clamp((UV.y - rim_from.y) / (1.0 - rim_from.y), 0.0, 1.0);
		float shade = clamp(lum / 0.35, 0.0, 1.0);
		vec3 bare = a.rgb;
		vec3 painted = rim_color * (0.35 + 0.65 * shade);
		vec3 col = mix(bare, painted, rim_paint);
		float rough = mix(orm.g, 0.45, rim_paint);
		float metal = mix(orm.b, 0.1, rim_paint);
		// Rust pits through the paint, from the nuts and the hub outwards.
		float spots = clamp((pit.r - pit.b - 0.08) * 2.7, 0.0, 1.0);
		float sev = rust * (0.3 + 0.75 * s) * (0.6 + 0.8 * n);
		float rusted = smoothstep(1.0 - sev, 1.06 - sev, spots);
		col = mix(col, pit * vec3(0.5, 0.36, 0.26), rusted);
		rough = mix(rough, 0.85, rusted);
		metal *= 1.0 - rusted;
		// Brake dust towards the hub, road dust over it all.
		float bd = clamp(wear * (0.15 + 0.7 * s) * (0.6 + 0.8 * n), 0.0, 1.0) * 0.7;
		col = mix(col, brake_dust * (0.8 + 0.3 * n), bd);
		float dust = clamp(wear * (0.2 + 0.4 * s) * (0.6 + 0.8 * n), 0.0, 1.0) * 0.5;
		col = mix(col, dirt_color * (0.65 + 0.3 * n), dust);
		ALBEDO = col * (1.0 - wetness * 0.2);
		ROUGHNESS = clamp(mix(rough, 0.9, max(dust, bd)) * mix(1.0, 0.6, wetness), 0.05, 1.0);
		METALLIC = metal * (1.0 - max(dust, bd));
		SPECULAR = 0.5;
		AO = orm.r;
	}
}
