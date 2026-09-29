// The campfire's logs, coals and ash bed (CampfireModel). The logs wear the bark photo
// maps; as the fire burns (`burn`) char creeps over them from their hot side (vertex
// colour R: how deep in the fire a point sits), cracking into the alligator scales of
// charred wood whose cracks glow and breathe while the fire is hot (`glow`); cold, the
// char turns to grey ash (`ash`). Vertex colour G marks the coal bed and the ash under
// the fire (always charred).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Bark repeats per metre along and around the logs (MeshBuilder UVs are in metres).
uniform float uv_scale = 1.6;
uniform vec3 bark_tint : source_color = vec3(0.92, 0.88, 0.84);
// How burnt the wood is (0 fresh logs .. 1 burnt through), how hot (0 cold .. 1 blazing)
// and how much grey ash lies on it: set per fire.
instance uniform float burn = 0.0;
instance uniform float glow = 0.0;
instance uniform float ash = 0.0;
// A per-fire phase, so neighbouring fires don't breathe in step.
instance uniform float phase = 0.0;

varying vec3 v_obj;

// Distance to the nearest and second-nearest cell point (cellular noise): the char's
// scales are the cells, their cracks where the two distances meet.
vec2 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash13(i + g), hash13(i + g + 17.3), hash13(i + g + 41.7));
				float d = length(g + o - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec2(d1, d2);
}

void vertex() {
	v_obj = VERTEX;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 col = texture(albedo_tex, uv).rgb * bark_tint;
	vec3 arm = texture(arm_tex, uv).rgb;
	float exposure = COLOR.r;
	float bed = COLOR.g;
	float n = vnoise3(v_obj * 11.0) * 0.6 + vnoise3(v_obj * 27.0) * 0.4;
	// Char spreads from the flames' side outwards as the wood burns.
	float reach = burn * (0.6 + exposure * 0.9) - (1.0 - exposure) * 0.35 + (n - 0.5) * 0.35 * min(burn * 4.0, 1.0);
	float charred = max(smoothstep(0.0, 0.18, reach), bed);
	// Charred wood cracks into scales (not the bed: coal and ash lie loose there).
	vec2 c = cells(v_obj * 26.0);
	float crack = (1.0 - smoothstep(0.0, 0.07, c.y - c.x)) * (1.0 - bed);
	float scale_shade = mix(0.75 + 0.5 * c.x, 1.0, bed);
	float fine = vnoise3(v_obj * 70.0);
	vec3 char_col = srgb(vec3(0.05, 0.045, 0.04)) * scale_shade * (0.75 + n * 0.35 + fine * 0.15);
	char_col = mix(char_col, char_col * 0.4, crack);
	col = mix(col, char_col, charred);
	// Ash: pale flakes on the scales once the fire dies, drifts of it over the bed.
	float ash_amount = max(ash, bed * 0.4) * charred;
	float flakes = smoothstep(0.45, 0.75, n * 0.75 + fine * 0.25 + (1.0 - crack) * 0.1 + ash_amount * 0.35 - 0.2);
	col = mix(col, srgb(vec3(0.42, 0.4, 0.38)) * (0.75 + 0.35 * fine), flakes * ash_amount);
	// Embers: the cracks and hot spots glow deep orange, breathing with the flames;
	// hottest in the middle of the fire.
	float t = TIME + phase * 13.0;
	float breathe = 0.7 + 0.3 * sin(t * 2.1 + n * 9.0) * sin(t * 1.33 + v_obj.x * 6.0 + v_obj.z * 4.0);
	float heat = glow * charred * exposure * (1.0 - flakes * ash_amount * 0.8);
	float hot_spots = smoothstep(0.55, 0.8, n + (fine - 0.5) * 0.3);
	float ember = heat * (crack * 0.85 + hot_spots * mix(0.3, 0.9, bed));
	vec3 ember_col = mix(vec3(0.85, 0.1, 0.01), vec3(1.0, 0.4, 0.07), smoothstep(0.3, 1.0, ember));
	EMISSION = ember_col * ember * breathe * 3.0;
	ALBEDO = col * (1.0 - wetness * 0.3);
	ROUGHNESS = mix(arm.g, 0.92, charred) * mix(1.0, 0.6, wetness);
	AO = mix(arm.r, 1.0, charred);
	AO_LIGHT_AFFECT = 0.2;
	NORMAL_MAP = mix(texture(normal_tex, uv).rgb, vec3(0.5, 0.5, 1.0), charred * 0.6);
	NORMAL_MAP_DEPTH = 1.2;
	SPECULAR = 0.35;
}
