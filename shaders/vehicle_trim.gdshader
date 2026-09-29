// Vehicle trim: bumpers, bull bar, running boards, underbody and bed trim, drawn from
// the model's trim atlas (colour, and occlusion / roughness / metal in r / g / b) with
// the road on top: dust in patches, thickest low down and behind the wheels, caked mud
// on the lowest faces. With `rust` an old vehicle's chrome goes dull and pitted, its
// bare and painted steel breaks into rust from the lower edges up. The atlas' lamp
// sprites are lenses (the side markers glow with the parking lights), and the housings
// on the bed's rear corners carry red tail lamps. Placed in the vehicle's frame like
// vehicle_paint.gdshader (x forward, y up from the ground, z to the right; frame_x/y/z
// per mesh). Double-sided like the source model: back faces and the cab's inside
// (headliner, pillar trim) skip the weathering.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float wear = 0.3;
uniform float rust = 0.0;
// Chrome roughness added with age (0: showroom).
uniform float chrome_dull = 0.0;
uniform vec3 dirt_color : source_color = vec3(0.45, 0.39, 0.3);
uniform sampler2D pit_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pit_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scale_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float pit_scale = 1.6;
uniform float scale_scale = 1.1;
uniform vec4 arches = vec4(1.93, -1.23, 0.385, 0.47);
// The cab's inside (its headliner and pillar trim are in this atlas): centre, half
// length; `cab_width` is the inner door plane.
uniform vec4 cab = vec4(0.9, 1.3, 0.0, 0.62);
uniform float cab_width = 0.8;
// The narrow gap between the cab's back and the bed's front wall (its x).
uniform float gap_x = 0.135;
// The door mirror heads (x from / to, height from / to), outside the door plane: not
// the cab's inside whatever way they face; their glass stays a mirror.
uniform vec4 mirrors = vec4(1.05, 1.34, 1.2, 1.4);
// The atlas' lamp sprites: u from, v from / to.
uniform vec3 lens_rect = vec3(0.684, 0.35, 0.665);
// Tail lamp housings on the bed's rear corners (x below, height from / to, |z| from / to).
uniform float tail_x = -2.25;
uniform vec4 tail_box = vec4(0.77, 1.02, 0.69, 0.83);
// Lamp glow, set by Vehicle: tail lamps (tail / brake), amber markers (parking lights).
uniform float tail_glow = 0.0;
uniform float marker_glow = 0.0;
// 1: full detail; 0 (Low / Medium quality): one projection per map, no rust relief.
uniform float detail = 1.0;

instance uniform vec4 frame_x = vec4(1.0, 0.0, 0.0, 0.0);
instance uniform vec4 frame_y = vec4(0.0, 1.0, 0.0, 0.0);
instance uniform vec4 frame_z = vec4(0.0, 0.0, 1.0, 0.0);

varying vec3 v_pos;
varying vec3 v_nrm;
varying vec3 v_ax;
varying vec3 v_ay;
varying vec3 v_az;

void vertex() {
	v_pos = vec3(dot(frame_x.xyz, VERTEX) + frame_x.w, dot(frame_y.xyz, VERTEX) + frame_y.w,
			dot(frame_z.xyz, VERTEX) + frame_z.w);
	v_nrm = normalize(vec3(dot(frame_x.xyz, NORMAL), dot(frame_y.xyz, NORMAL), dot(frame_z.xyz, NORMAL)));
	v_ax = normalize((MODELVIEW_MATRIX * vec4(frame_x.xyz, 0.0)).xyz);
	v_ay = normalize((MODELVIEW_MATRIX * vec4(frame_y.xyz, 0.0)).xyz);
	v_az = normalize((MODELVIEW_MATRIX * vec4(frame_z.xyz, 0.0)).xyz);
}

// Mostly one axis, blended where the surface turns; only the main axis at low detail.
vec3 proj_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(6.0));
	w *= step(0.03, w / (w.x + w.y + w.z));
	if (detail < 0.5) {
		vec3 a = abs(n);
		w = step(max(a.yzx, a.zxy), a);
	}
	return w / max(w.x + w.y + w.z, 1e-4);
}

vec4 proj_tex(sampler2D t, vec3 p, vec3 w, vec3 dx, vec3 dy) {
	vec4 c = vec4(0.0);
	if (w.x > 0.0) c += textureGrad(t, vec2(p.z, -p.y), vec2(dx.z, -dx.y), vec2(dy.z, -dy.y)) * w.x;
	if (w.y > 0.0) c += textureGrad(t, p.xz, dx.xz, dy.xz) * w.y;
	if (w.z > 0.0) c += textureGrad(t, vec2(p.x, -p.y), vec2(dx.x, -dx.y), vec2(dy.x, -dy.y)) * w.z;
	return c;
}

vec3 proj_tilt(sampler2D t, vec3 p, vec3 w, vec3 dx, vec3 dy) {
	vec3 d = vec3(0.0);
	if (w.x > 0.0) {
		vec2 n = textureGrad(t, vec2(p.z, -p.y), vec2(dx.z, -dx.y), vec2(dy.z, -dy.y)).xy * 2.0 - 1.0;
		d += vec3(0.0, n.y, n.x) * w.x;
	}
	if (w.y > 0.0) {
		vec2 n = textureGrad(t, p.xz, dx.xz, dy.xz).xy * 2.0 - 1.0;
		d += vec3(n.x, 0.0, -n.y) * w.y;
	}
	if (w.z > 0.0) {
		vec2 n = textureGrad(t, vec2(p.x, -p.y), vec2(dx.x, -dx.y), vec2(dy.x, -dy.y)).xy * 2.0 - 1.0;
		d += vec3(n.x, n.y, 0.0) * w.z;
	}
	return d;
}

void fragment() {
	vec3 p = v_pos;
	vec3 nf = normalize(v_nrm);
	float h = p.y;
	vec4 base = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	// Outside any branch: derivatives are undefined where a pixel quad splits.
	vec3 dx = dFdx(p);
	vec3 dy = dFdy(p);
	// Chrome and mirror glass: bright, smooth metal in the atlas.
	float chrome = smoothstep(0.5, 0.8, orm.b) * (1.0 - smoothstep(0.25, 0.45, orm.g));
	bool mirror = p.x > mirrors.x && p.x < mirrors.y && h > mirrors.z && h < mirrors.w && abs(p.z) > cab_width;
	vec3 to_cab = cab.xyz - p;
	bool in_cab = !mirror && abs(to_cab.x) < cab.w && abs(p.z) < cab_width && abs(to_cab.y) < 0.5
			&& dot(nf, to_cab) > 0.0;
	if (!FRONT_FACING || in_cab) {
		// The headliner and pillar trim: cloth and vinyl, brightwork stays metal. Only
		// the windows let the sky's light in; back faces of the shells stay dark.
		ALBEDO = base.rgb;
		ROUGHNESS = mix(max(orm.g, 0.85), orm.g, chrome);
		METALLIC = orm.b * chrome;
		AO = orm.r * 0.4;
		SPECULAR = 0.5;
	} else {
		vec3 col = base.rgb * tint;
		float rough = orm.g;
		float metal = orm.b;
		// Lamp lenses: coloured plastic, not chrome; the amber ones (orange, not red:
		// green well above blue) are side markers.
		float lens = step(lens_rect.x, UV.x) * step(lens_rect.y, UV.y) * step(UV.y, lens_rect.z);
		float amber = lens * smoothstep(0.06, 0.14, base.r - base.b) * smoothstep(0.3, 0.45, base.g / max(base.r, 0.01));
		rough = mix(rough, 0.06, lens);
		metal *= 1.0 - lens;
		// Door mirror glass: faces back.
		float glass = mirror ? chrome * step(0.7, -nf.x) : 0.0;
		// Tail lamps on the bed's rear corners: a red lens over ribbed reflectors.
		float tail = step(p.x, tail_x) * step(tail_box.x, h) * step(h, tail_box.y)
				* step(tail_box.z, abs(p.z)) * step(abs(p.z), tail_box.w) * step(0.6, -nf.x);
		float rib = smoothstep(0.2, 0.8, abs(fract(h * 38.0) - 0.5) * 2.0);
		col = mix(col, vec3(0.26, 0.012, 0.008) * (0.75 + 0.35 * rib), tail);
		rough = mix(rough, 0.07, tail);
		metal *= 1.0 - tail;
		float clean = max(max(lens, tail), glass);

		float n = vnoise3(p * 2.3) * 0.6 + vnoise3(p * 7.7) * 0.4;
		vec3 w = proj_weights(nf);
		vec3 pit = proj_tex(pit_albedo, p * pit_scale, w, dx * pit_scale, dy * pit_scale).rgb;
		float spots = clamp((pit.r - pit.b - 0.08) * 2.7, 0.0, 1.0);
		float smudge = dot(pit, vec3(0.33));
		vec3 tilt = vec3(0.0, (rib - 0.5) * 0.25 * tail, 0.0);
		float rusted = 0.0;
		if (rust > 0.0) {
			// Dull, hazy chrome with brown pitting (the mirror glass only a little);
			// steel rusting from the bottom edges.
			float dull = chrome_dull * (1.0 - 0.85 * glass);
			rough = mix(rough, rough + dull * (0.6 + 0.8 * smudge), chrome);
			// Aged chrome loses its mirror: darker, milky, blotched where the plating thins.
			col = mix(col, col * (0.45 + 0.3 * smudge) * vec3(1.0, 0.97, 0.93), chrome * dull * 1.6);
			float low = 1.0 - smoothstep(0.35, 0.95, h + (n - 0.5) * 0.3);
			float sev = rust * (0.12 + 0.75 * low + 0.25 * (1.0 - chrome)) * (0.35 + 1.1 * n) * (1.0 - clean);
			float t = 1.0 - sev;
			rusted = smoothstep(t, t + 0.08, spots);
			vec3 scale = proj_tex(scale_albedo, p * scale_scale, w, dx * scale_scale, dy * scale_scale).rgb;
			vec3 rc = mix(scale * 1.05, pit * vec3(0.62, 0.5, 0.42), 0.3);
			col = mix(col, rc, rusted);
			rough = mix(rough, 0.88, rusted);
			metal *= 1.0 - rusted;
			if (detail > 0.5) {
				tilt += proj_tilt(pit_normal, p * pit_scale, w, dx * pit_scale, dy * pit_scale) * (0.35 + rusted) * 0.9;
			}
		}
		// Dust in patches: from the ground up, sprayed behind the wheels, settled on the
		// tops and in the cavities; edges and chrome show through. At most a film: the
		// metal and paint underneath still read.
		float low = 1.0 - smoothstep(0.25, 1.0, h + (n - 0.5) * 0.3);
		float spray = 0.0;
		for (int k = 0; k < 2; k++) {
			float bx = (k == 0 ? arches.x : arches.y) - p.x;
			spray = max(spray, (1.0 - smoothstep(0.1, 1.2, bx)) * smoothstep(-0.25, 0.1, bx) * (1.0 - smoothstep(0.4, 1.0, h)));
		}
		float top = smoothstep(0.55, 0.95, nf.y);
		float cavity = 1.0 - orm.r;
		float dirt = clamp(low * 0.7 + spray * 0.45 + top * 0.3 + cavity * 0.7 + 0.05, 0.0, 1.0);
		dirt *= smoothstep(0.25, 0.75, n * 0.75 + smudge * 0.45 + low * 0.2 + cavity * 0.6 - chrome * 0.15);
		dirt = min(dirt * wear * 1.2, 0.65) * (1.0 - 0.6 * clean);
		// Caked mud, darker, on the lowest faces and behind the wheels.
		float caked = max(1.0 - smoothstep(0.3, 0.46, h), spray * (1.0 - smoothstep(0.35, 0.6, h))) * smoothstep(0.35, 0.6, n);
		vec3 dc = dirt_color * (0.72 + 0.35 * n) * mix(1.0, 0.62, caked);
		col = mix(col, dc, dirt);
		float wet = wetness;
		// Faces looking into the gap behind the cab see only its back wall.
		float gap = (1.0 - smoothstep(0.035, 0.08, abs(p.x - gap_x))) * smoothstep(0.3, 0.6, abs(nf.x))
				* (1.0 - smoothstep(1.12, 1.2, h));
		ALBEDO = col * (1.0 - wet * mix(0.1, 0.35, dirt)) * (1.0 - 0.6 * gap);
		ROUGHNESS = clamp(mix(mix(rough, 0.9, dirt) * mix(1.0, 0.55, wet), 0.7, gap), 0.04, 1.0);
		METALLIC = metal * (1.0 - dirt) * (1.0 - gap);
		AO = orm.r * (1.0 - 0.75 * gap);
		SPECULAR = 0.5 * (1.0 - 0.8 * gap);
		EMISSION = vec3(1.0, 0.03, 0.015) * tail_glow * 0.45 * tail * (0.65 + 0.35 * rib)
				+ base.rgb * marker_glow * amber;
		if (dot(tilt, tilt) > 0.0) {
			NORMAL = normalize(NORMAL + (v_ax * tilt.x + v_ay * tilt.y + v_az * tilt.z) * (1.0 - dirt * 0.6));
		}
	}
}
