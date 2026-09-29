// Small solid bits thrown by work (FxDebris): bark chips and splinters, rock fragments,
// soil clods, leaves, stalks and seeds, drawn as MultiMesh instances.
// Per instance: COLOR = tint (rgb: for the photo looks 0.5 grey = the photo as-is, for
// the others the linear albedo itself), INSTANCE_CUSTOM = (texture offset u, v, size in
// metres, random 0..1). The mesh's vertex alpha marks a wood chip's bark side (1)
// against its fresh wood (0).
// look: 0 photo textured (triplanar in the piece's own space: rock, soil),
//       1 wood (bark photo on the bark side, fresh fibrous wood elsewhere),
//       2 leaf or stalk (tint, midrib and veins, light through it), 3 plain tint.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#include "res://shaders/include/noise.gdshaderinc"

uniform int look = 0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = true;
// Texture repeats per metre.
uniform float uv_scale = 1.0;
uniform float normal_strength = 1.0;
uniform float roughness = 0.85;
// Fresh wood under the bark (look 1).
uniform vec3 fresh_color : source_color = vec3(0.86, 0.73, 0.52);
// Light let through a leaf (look 2).
uniform float translucency = 0.35;

varying vec3 obj_pos;
varying vec3 obj_nrm;
varying vec4 inst;
varying float bark;

void vertex() {
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
	inst = INSTANCE_CUSTOM;
	bark = COLOR.a;
}

vec3 triplanar_albedo(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(albedo_tex, p.zy).rgb * w.x + texture(albedo_tex, p.xz).rgb * w.y + texture(albedo_tex, p.xy).rgb * w.z;
}

vec3 triplanar_normal(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(normal_tex, p.zy).rgb * w.x + texture(normal_tex, p.xz).rgb * w.y + texture(normal_tex, p.xy).rgb * w.z;
}

void fragment() {
	float size = max(inst.z, 0.005);
	vec3 tint = COLOR.rgb;
	// The piece's surface in metres, shifted per piece so no two show the same patch.
	vec3 p = obj_pos * size * uv_scale + vec3(inst.x, inst.y, inst.x + inst.y) * 7.0;
	vec3 col;
	float rough = roughness;
	if (look == 0) {
		col = triplanar_albedo(p, obj_nrm) * tint * 2.0;
		if (has_normal) {
			NORMAL_MAP = triplanar_normal(p, obj_nrm);
			NORMAL_MAP_DEPTH = normal_strength;
		}
		// Freshly broken faces are a little paler and crisper than weathered ones.
		col *= 0.9 + 0.2 * vnoise3(obj_pos * 3.0 + inst.w * 17.0);
	} else if (look == 1) {
		// Fibres run along the piece's long (X) axis.
		vec3 q = obj_pos * size;
		float fib = vnoise3(vec3(q.x * 40.0, q.y * 900.0, q.z * 900.0) + inst.w * 31.0);
		float fib2 = vnoise3(vec3(q.x * 12.0, q.y * 300.0, q.z * 300.0) + inst.w * 7.0);
		vec3 fresh = fresh_color * (0.82 + 0.26 * fib) * (0.9 + 0.15 * fib2);
		vec3 barkc = texture(albedo_tex, vec2(p.x, p.z)).rgb * 1.1;
		col = mix(fresh, barkc, smoothstep(0.3, 0.7, bark)) * tint * 2.0;
		if (has_normal && bark > 0.5) {
			NORMAL_MAP = texture(normal_tex, vec2(p.x, p.z)).rgb;
			NORMAL_MAP_DEPTH = normal_strength;
		}
		rough = mix(0.72, 0.92, bark);
	} else if (look == 2) {
		// UV.x runs along the midrib (0 at the stalk), UV.y across (-1..1).
		float mid = smoothstep(0.07, 0.0, abs(UV.y));
		float veins = smoothstep(0.08, 0.0, abs(fract(UV.x * 7.0 - abs(UV.y) * 2.2) - 0.5) - 0.42) * (1.0 - mid);
		float mottle = vnoise2(UV * vec2(6.0, 3.0) + inst.w * 13.0);
		col = tint * (0.85 + 0.25 * mottle);
		col = mix(col, col * 1.25 + vec3(0.02, 0.03, 0.0), mid * 0.6 + veins * 0.25);
		// The side away from the light is a little lighter and yellower underneath.
		if (!FRONT_FACING) {
			col *= vec3(1.08, 1.1, 0.9);
		}
		BACKLIGHT = col * translucency;
		rough = roughness;
	} else {
		col = tint * (0.9 + 0.2 * vnoise3(obj_pos * 4.0 + inst.w * 11.0));
	}
	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	ROUGHNESS = rough;
	SPECULAR = 0.4;
}
