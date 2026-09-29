// Distant landscape beyond the map (scripts/world/backdrop.gd): the rim's meadow under
// the tree cards near the map, then a forest canopy, clearings and far ridges, lit by
// the sun and sky like the terrain. The scene fog hazes it at its true distance,
// tinted by the sky behind it (aerial perspective), so it melts into the horizon at
// every hour and in every weather. The vertex shader draws its far parts squeezed
// inside the camera's range (shaders/include/backdrop.gdshaderinc).
//
// UV.x = metres outside the map edge. COLOR: r = forest cover, g = bare rock.
shader_type spatial;
render_mode specular_disabled, cull_back;

#include "res://shaders/include/nature.gdshaderinc"
#include "res://shaders/include/backdrop.gdshaderinc"

// The hill forest's ground (the terrain's rim: forest floor litter with a little grass).
uniform vec3 meadow_color : source_color = vec3(0.31, 0.31, 0.19);
// Crowns seen from above, sunlit and shaded, matched to the hill forest's impostor
// trees on screen (dark spruce and broadleaf crowns; the impostor atlas averages
// 0.08, 0.1, 0.04 unlit: a canopy's crowns shade each other, so from afar it reads
// darker than one tree).
uniform vec3 crown_color : source_color = vec3(0.19, 0.235, 0.135);
uniform vec3 crown_dark : source_color = vec3(0.1, 0.14, 0.09);
uniform vec3 field_color : source_color = vec3(0.34, 0.4, 0.2);
uniform vec3 field_dry : source_color = vec3(0.48, 0.46, 0.27);
uniform vec3 rock_color : source_color = vec3(0.38, 0.37, 0.34);
// Where the tree cards give way to the canopy surface (metres out; backdrop.gd).
uniform float canopy_begin = 40.0;
uniform float canopy_end = 230.0;
// How far a canopy's light wraps round and leans towards a low sun (0..1), and how much
// darker it looks against the light (its shaded sides) than with it.
uniform float canopy_wrap = 0.35;
uniform float canopy_lean = 0.4;
uniform float canopy_backlit = 0.3;

varying vec3 v_world;
varying float v_out;
varying float v_canopy;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_out = UV.x;
	v_canopy = COLOR.r * smoothstep(canopy_begin, canopy_end, UV.x);
	POSITION = backdrop_position(v_world, VIEW_MATRIX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
}

void fragment() {
	vec2 p = v_world.xz;
	// Metres per pixel along the longer side: at grazing angles a pixel stretches far
	// along the view, and detail finer than that would shimmer or comb into ripples.
	float foot = max(max(length(dFdx(p)), length(dFdy(p))), 0.001);
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float stand = vnoise2(p * 0.006 + vec2(11.0, 3.0));

	// Detail finer than a pixel is skipped (most of the backdrop is far away).
	// The rim's meadow, under the tree cards near the map.
	vec3 meadow = meadow_color;
	if (foot < 8.0) {
		meadow *= mix(1.0, 0.85 + 0.3 * vnoise2(p * 0.07 + 5.0), 1.0 - smoothstep(2.0, 8.0, foot));
	}
	// Farther out the canopy closes over it: crowns lit where they bulge, with shaded
	// gaps down to the meadow, in darker conifer and lighter broadleaf stands a few
	// hundred metres across. Single crowns only show while a pixel is under a metre;
	// otherwise their average stands in.
	vec3 crown = mix(crown_dark, crown_color, stand);
	crown *= mix(vec3(0.92, 0.98, 1.06), vec3(1.1, 1.05, 0.9), smoothstep(0.3, 0.8, vnoise2(p * 0.0032 + 21.0)));
	crown = mix(crown, srgb(vec3(0.5, 0.36, 0.16)), autumn_amount * smoothstep(0.35, 0.8, stand) * 0.7);
	float open = mix(0.42, 0.28, stand);
	vec3 floor_col = mix(meadow * 0.6, crown_dark * 0.7, 0.4);
	// Seen at a slant the crowns hide the gaps between them.
	vec3 up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float steep = smoothstep(0.05, 0.6, dot(VIEW, up_view));
	vec3 canopy = mix(crown * 0.95, floor_col, open * 0.75 * steep);
	float detail = 1.0 - smoothstep(0.4, 1.5, foot);
	if (detail > 0.0) {
		float crowns = vnoise2(p * 0.2) * 0.7 + vnoise2(p * 0.53 + vec2(5.2, 1.7)) * 0.3;
		float gap = 1.0 - smoothstep(open - 0.1, open + 0.1, crowns);
		vec3 near_canopy = mix(crown * mix(0.75, 1.15, smoothstep(open, 0.85, crowns)), floor_col, gap);
		canopy = mix(canopy, near_canopy, detail);
	}
	// Clumps of crowns a few metres across and groups of trees a few tens of metres
	// across while a pixel is small enough to show them, and stands of trees a few
	// hundred metres across, darker and lighter.
	if (foot < 12.0) {
		canopy *= mix(1.0, 0.78 + 0.44 * vnoise2(p * 0.08 + 9.0), 1.0 - smoothstep(3.0, 12.0, foot));
	}
	if (foot < 70.0) {
		canopy *= mix(1.0, 0.8 + 0.4 * vnoise2(p * 0.022 + 13.0), 1.0 - smoothstep(25.0, 70.0, foot));
	}
	canopy *= mix(0.84, 1.12, vnoise2(p * 0.0045 + 7.0));
	float cover = smoothstep(canopy_begin, canopy_end, v_out);
	vec3 forest = mix(meadow, canopy, cover);

	// Scattered clearings of pasture and fields far out (per pixel, so they follow the
	// land rather than the mesh's rings): a patchwork of lots, green, hay-coloured and
	// darker, with tree lines along their edges while a pixel is small enough to show them.
	vec3 col = forest;
	if (v_out > 800.0) {
		float clearing = smoothstep(0.66, 0.76, vnoise2(p * 0.0016) * 0.7 + vnoise2(p * 0.005 + 3.0) * 0.3);
		clearing *= smoothstep(800.0, 1500.0, v_out);
		vec2 lot_size = vec2(90.0, 64.0);
		vec2 lot = floor(p / lot_size);
		vec3 field = mix(field_color, field_dry, smoothstep(0.45, 0.9, hash12(lot + 17.0))) * mix(0.78, 1.05, hash12(lot + 5.0));
		if (foot < 12.0) {
			field *= mix(1.0, 0.9 + 0.2 * vnoise2(p * 0.05), 1.0 - smoothstep(3.0, 12.0, foot));
		}
		vec2 to_edge = min(fract(p / lot_size), 1.0 - fract(p / lot_size)) * lot_size;
		float hedge = (1.0 - smoothstep(2.0, 5.0, min(to_edge.x, to_edge.y))) * (1.0 - smoothstep(4.0, 10.0, foot));
		field = mix(field, crown_dark * 0.9, hedge * 0.8);
		col = mix(col, field, clearing);
	}

	float slope = 1.0 - n_world.y;
	float rock = clamp(COLOR.g + smoothstep(0.5, 0.7, slope) * 0.6, 0.0, 1.0);
	col = mix(col, rock_color * (0.85 + 0.3 * stand), rock);
	col = mix(col, snow_color(), snow_amount * (1.0 - rock * 0.5) * 0.85);
	col *= 1.0 - wetness * 0.2;

	ALBEDO = col;
	ROUGHNESS = 1.0;
	// A canopy is a rough volume whose crowns shade each other.
	AO = mix(1.0, 0.82, v_canopy * (1.0 - rock));
	AO_LIGHT_AFFECT = 0.25;
}

void light() {
	// A forest canopy is a rough volume: its crowns face every way, so the slope under
	// them shades it less than bare land; the crowns facing a low sun light up even where
	// the land is flat, so its light wraps round and leans towards the sun. Seen against
	// the light it shows the crowns' shaded sides. Bare land (the meadow near the map,
	// fields, rock) is plain Lambert.
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float elevation = dot(LIGHT, up);
	float low = v_canopy * (1.0 - smoothstep(0.1, 0.6, elevation));
	vec3 across = LIGHT - up * elevation;
	vec3 n = normalize(mix(NORMAL, up, 0.3 * v_canopy) + across * canopy_lean * low);
	float wrap = canopy_wrap * low;
	float lit = clamp((dot(n, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	vec3 view_across = VIEW - up * dot(VIEW, up);
	float facing = dot(normalize(across + vec3(0.0001)), normalize(view_across + vec3(0.0001)));
	lit *= 1.0 + canopy_backlit * facing * v_canopy * (1.0 - abs(dot(VIEW, up)));
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
}
