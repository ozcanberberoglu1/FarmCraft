// Shared by the photo-textured (downloaded) animal shaders: the model's own PBR
// textures, plus per-animal coat recolouring, rain wetness and shorn fleece.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
// Hair strands painted grey on black, without an alpha channel: the grey is the
// strand coverage, the colour comes from `hair_base` (and the coat variant).
uniform bool alpha_from_luma = false;
uniform vec3 hair_base : source_color = vec3(0.72, 0.7, 0.66);
uniform bool has_normal = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength = 1.0;
uniform bool has_orm = false;
// glTF metallic-roughness texture: G = roughness, B = metallic.
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float specular = 0.4;
// glTF occlusion: R channel.
uniform bool has_ao = false;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
// Coat recolouring: texels are split into dark and light coat by luminance and
// re-tinted, keeping the texture's hair detail (its luminance relative to the
// typical dark / light coat luminance).
uniform float split_lo = 0.22;
uniform float split_hi = 0.42;
uniform float dark_mean = 0.08;
uniform float light_mean = 0.62;
// Texture columns (u < edge or u > 1 - edge) that keep their colour, e.g. where a
// model keeps its lower legs and hooves.
uniform float keep_u_edge = 0.0;
// Fleece: vertices inside this ellipsoid (mesh space -> unit sphere) sink along
// the normal by `fleece_depth` when shorn.
uniform bool has_fleece = false;
uniform mat4 fleece_xform = mat4(1.0);
uniform float fleece_depth = 0.05;
// Carrying young: the barrel between the legs rounds out along the normal by `belly`
// (mesh units), round the instance's `belly_at` (xyz: the barrel's middle in mesh space,
// w: half its length); `belly_fwd` / `belly_up` are the body's axes in mesh space.
uniform vec3 belly_fwd = vec3(0.0, 0.0, -1.0);
uniform vec3 belly_up = vec3(0.0, 1.0, 0.0);

// Instance uniforms: identical names and order in every photo animal shader.
instance uniform vec3 dark_tint : source_color = vec3(0.05);
instance uniform vec3 light_tint : source_color = vec3(0.95);
instance uniform float recolor = 0.0;
instance uniform float wet = 0.0;
instance uniform float wool_amount = 1.0;
instance uniform vec4 belly_at = vec4(0.0, 0.0, 0.0, 1.0);
instance uniform float belly = 0.0;

varying float v_fleece;

void vertex() {
	v_fleece = 0.0;
	if (has_fleece) {
		vec3 q = (fleece_xform * vec4(VERTEX, 1.0)).xyz;
		v_fleece = 1.0 - smoothstep(0.75, 1.0, length(q));
		VERTEX -= NORMAL * v_fleece * (1.0 - wool_amount) * fleece_depth;
	}
	if (belly > 0.0) {
		vec3 d = VERTEX - belly_at.xyz;
		float along = dot(d, belly_fwd);
		vec3 radial = d - belly_fwd * along;
		float far = length(radial);
		// Between the legs only (they stand at the barrel's ends), the flanks and the
		// underside most, the back hardly.
		float w = 1.0 - smoothstep(0.4, 0.95, abs(along) / belly_at.w);
		w *= 1.0 - smoothstep(1.3, 1.9, far / belly_at.w);
		w *= mix(1.0, 0.3, smoothstep(0.0, 0.8, dot(radial / max(far, 0.0001), belly_up)));
		VERTEX += NORMAL * w * belly;
	}
}

vec3 coat_color(vec3 c, vec2 uv) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float t = smoothstep(split_lo, split_hi, l);
	float detail = clamp(l / max(mix(dark_mean, light_mean, t), 0.02), 0.0, 1.8);
	vec3 recoloured = mix(dark_tint, light_tint, t) * detail;
	// Pink and red bare skin (muzzle, udder, comb, wattles) keeps its colour.
	float keep = smoothstep(0.1, 0.2, c.r - c.g) * step(c.g * 0.72, c.b);
	keep = max(keep, step(uv.x, keep_u_edge) + step(1.0 - keep_u_edge, uv.x));
	return mix(c, recoloured, recolor * (1.0 - clamp(keep, 0.0, 1.0)));
}

void shade(vec2 uv, out vec3 albedo, out float alpha, out float rough, out float metal) {
	vec4 tex = texture(albedo_tex, uv) * albedo_color;
	alpha = tex.a;
	if (alpha_from_luma) {
		float l = tex.r;
		alpha = smoothstep(0.06, 0.3, l);
		tex.rgb = hair_base * mix(0.55, 1.1, smoothstep(0.2, 0.9, l));
	}
	albedo = coat_color(tex.rgb, uv);
	rough = roughness;
	metal = metallic;
	if (has_orm) {
		vec4 orm = texture(orm_tex, uv);
		rough *= orm.g;
		metal *= orm.b;
	}
	// Freshly shorn fleece is short, pale and even: the curl detail flattens out.
	float shorn = v_fleece * (1.0 - wool_amount);
	float grey = max(dot(albedo, vec3(0.333)), 0.02);
	// The fleece's hue without its curl shading, lightened towards cream.
	vec3 even = mix(vec3(0.8, 0.74, 0.67), albedo / grey * 0.6, 0.5);
	albedo = mix(albedo, even, shorn * 0.8);
	// Rain soaks the coat: darker, glossier.
	albedo *= 1.0 - 0.35 * wet;
	rough = mix(rough, rough * 0.45, wet);
}
