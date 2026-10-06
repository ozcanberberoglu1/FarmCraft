// Vehicle cab interior. Two kinds of surface:
// - a grain set (`grain_tile` > 0: art/textures/cab, tools/make_cab_textures.py): moulded
//   plastic, vinyl, woven cloth, ribbed rubber or perforated headliner laid over the part
//   by its position (three projections blended by the normal, so the Blender-built cabs
//   need no UVs and every part has the same texel density), tinted with the material's
//   colour; its normal map gives the grain, weave and ribs their relief (High / Ultra),
//   its cavities hold the dust. `dust` settles on what faces up (the dash top, the seat
//   cushions, the floor) and in the cavities, `wear` polishes patches of vinyl and
//   plastic smooth and fades what the sun reaches;
// - the model's own atlas or a printed face (`grain_tile` = 0: colour; roughness / metal
//   in g / b). The pickup's atlas marks most of the dash and door cards as metal: here
//   they are moulded plastic and vinyl with a little shine left, while the smooth metal
//   texels (the rear-view mirror's glass, chrome stems and trim) stay mirrors. Plastic
//   and vinyl are never glossier than `min_rough` and carry a faint mottle; at full
//   detail also a moulded grain a few millimetres across, faded out where it would shimmer.
// The body moves, so it stays out of SDFGI and the cab would get the open sky's bounce
// light as if it had no roof: `cab_ambient` is how much of it the windows let in.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/noise.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
// Metal left on the plastic and vinyl.
uniform float plastic_metal = 0.15;
uniform float min_rough = 0.6;
// Grain relief in metres.
uniform float grain_depth = 0.00025;
uniform float cab_ambient = 0.4;
// 1: full detail; 0 (Low / Medium quality): no grain relief.
uniform float detail = 1.0;
// The grain set: colour (near white), normal, and cavity / roughness in r / g.
uniform sampler2D grain_albedo : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres one tile covers; 0: no grain set.
uniform float grain_tile = 0.0;
uniform float grain_bump = 1.0;
// One over the set's mean colour: the tint comes out as the material's colour.
uniform float grain_gain = 1.5;
uniform float dust = 0.0;
uniform vec3 dust_color : source_color = vec3(0.45, 0.38, 0.29);
uniform float wear = 0.0;
// A lit part (the radio's display while the set is on, CarRadio): its own print glows
// in this colour; black for everything else.
uniform vec3 glow : source_color = vec3(0.0);

varying vec3 v_local;
varying vec3 v_normal;

void vertex() {
	v_local = VERTEX;
	v_normal = NORMAL;
}

void fragment() {
	vec3 orm = texture(orm_tex, UV).rgb;
	if (grain_tile > 0.0) {
		vec3 n = normalize(v_normal) * (FRONT_FACING ? 1.0 : -1.0);
		vec3 w = pow(abs(n), vec3(4.0));
		w /= w.x + w.y + w.z;
		vec3 p = v_local / grain_tile;
		vec3 col = texture(grain_albedo, p.zy).rgb * w.x + texture(grain_albedo, p.xz).rgb * w.y
				+ texture(grain_albedo, p.xy).rgb * w.z;
		vec3 g = texture(grain_orm, p.zy).rgb * w.x + texture(grain_orm, p.xz).rgb * w.y + texture(grain_orm, p.xy).rgb * w.z;
		float rough = g.g + (orm.g - 0.6);
		// Dust: on what faces up (the model's +Y) and in the grain's cavities, a film everywhere.
		float up = smoothstep(0.3, 0.95, n.y);
		float drift = vnoise3(v_local * 7.0) * 0.6 + vnoise3(v_local * 29.0 + 4.7) * 0.4;
		float settled = dust * clamp(up * (0.15 + 0.95 * drift) + (1.0 - g.r) * (0.25 + 0.5 * up) + 0.14 * drift, 0.0, 1.0);
		// Wear: handled patches gone smooth, the tops sun-faded.
		float patch = smoothstep(0.52, 0.78, vnoise3(v_local * 5.0 + 2.3)) * wear;
		col *= tint.rgb * grain_gain;
		col = mix(col, vec3(dot(col, vec3(0.3, 0.55, 0.15))) * 1.25 + 0.01, 0.35 * wear * up);
		col *= 1.0 + 0.12 * patch;
		ALBEDO = mix(col, dust_color, settled * 0.55);
		ROUGHNESS = clamp(mix(rough - 0.2 * patch, 0.95, settled), 0.08, 1.0);
		METALLIC = 0.0;
		if (detail > 0.5) {
			vec2 tx = texture(grain_normal, p.zy).rg * 2.0 - 1.0;
			vec2 ty = texture(grain_normal, p.xz).rg * 2.0 - 1.0;
			vec2 tz = texture(grain_normal, p.xy).rg * 2.0 - 1.0;
			vec3 bent = n + grain_bump * (1.0 - 0.6 * settled) * (w.x * vec3(0.0, tx.y, tx.x) + w.y * vec3(ty.x, 0.0, ty.y)
					+ w.z * vec3(tz.x, tz.y, 0.0));
			NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * normalize(bent)));
		}
	} else {
		float mirror = 1.0 - smoothstep(0.14, 0.2, orm.g);
		float mottle = vnoise3(v_local * 14.0);
		vec3 g = v_local * 260.0;
		float grain = vnoise3(g) * 0.65 + vnoise3(g * 2.1 + 7.3) * 0.35;
		ALBEDO = texture(albedo_tex, UV).rgb * tint.rgb * mix(0.93 + 0.12 * mottle, 1.0, mirror);
		ROUGHNESS = mix(clamp(max(orm.g, min_rough) + 0.1 * (grain - 0.5) + 0.06 * (mottle - 0.5), 0.0, 1.0), orm.g, mirror);
		METALLIC = orm.b * mix(plastic_metal, 1.0, mirror);
		if (detail > 0.5) {
			// Bump from the grain's screen-space slope (surface gradient), none on mirrors
			// and none where a grain cell is smaller than a couple of pixels.
			float fade = (1.0 - mirror) * (1.0 - smoothstep(0.25, 0.6, length(fwidth(g * 2.1))));
			float h = grain * grain_depth * fade;
			vec3 dpdx = dFdx(VERTEX);
			vec3 dpdy = dFdy(VERTEX);
			vec3 r1 = cross(dpdy, NORMAL);
			vec3 r2 = cross(NORMAL, dpdx);
			float det = dot(dpdx, r1);
			vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
			NORMAL = normalize(abs(det) * NORMAL - grad);
		}
	}
	AO = cab_ambient;
	AO_LIGHT_AFFECT = 0.0;
	SPECULAR = 0.5;
	EMISSION = glow * (0.35 + ALBEDO);
}
