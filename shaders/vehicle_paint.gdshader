// Vehicle body paint: a metallic base coat under a glossy clear coat, and the road on
// top of it: dust thickest low on the body, mud sprayed up behind the wheels and caked
// on the arch lips, a film on the flat tops, darker and glossier in the rain.
// An old vehicle also gets sun-oxidised, chalky paint on the surfaces facing the sky
// (`fade`), rust (`rust`: blistered paint breaking into pitted rust spots and flaking
// scale, worst on the sills, wheel arches and door bottoms, bleeding down in stains
// below) and grime streaks running down its sides (`streaks`); all 0 is a clean coat.
// Everything is placed in the vehicle's frame (x forward, y up from the ground, z to
// the right, metres): per mesh, `frame_x/y/z` are the rows of its transform into that
// frame (every body panel has its own origin). The rust textures (Poly Haven, CC0)
// are projected along the frame's two main axes of each surface.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/nature.gdshaderinc"

uniform vec3 paint : source_color = vec3(0.05, 0.09, 0.2);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
// The model's baked occlusion (red channel): panel gaps, the grille, handles.
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float roughness = 0.34;
uniform float metallic = 0.4;
uniform float clearcoat = 1.0;
uniform float clearcoat_roughness = 0.05;
uniform float wear = 0.55;
uniform float fade = 0.0;
uniform float rust = 0.0;
uniform float streaks = 0.0;
uniform vec3 dirt_color : source_color = vec3(0.45, 0.39, 0.3);
// Painted steel with pitting (rusty_metal_02: its rust spots are the mask) and coarse
// rust scale (rust_coarse_01).
uniform sampler2D pit_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pit_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scale_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scale_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Texture repeats per metre.
uniform float pit_scale = 1.3;
uniform float scale_scale = 0.9;
// Wheel arches: front and rear axle x, hub height, radius of the arch opening.
uniform vec4 arches = vec4(1.93, -1.23, 0.385, 0.47);
// The cab's inside: centre and half length.
uniform vec4 cab = vec4(0.9, 1.3, 0.0, 0.62);
// The narrow gap between the cab's back and the bed's front wall (its x).
uniform float gap_x = 0.135;
// 1: full detail; 0 (Low / Medium quality): one projection per map, no rust relief.
uniform float detail = 1.0;

instance uniform vec4 frame_x = vec4(1.0, 0.0, 0.0, 0.0);
instance uniform vec4 frame_y = vec4(0.0, 1.0, 0.0, 0.0);
instance uniform vec4 frame_z = vec4(0.0, 0.0, 1.0, 0.0);

varying vec3 v_pos;
varying vec3 v_nrm;
// The frame's axes in view space (for the projected normal maps).
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

// Projection weights: mostly one axis, blended where the surface turns; only the main
// axis at low detail.
vec3 proj_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(6.0));
	w *= step(0.03, w / (w.x + w.y + w.z));
	if (detail < 0.5) {
		vec3 a = abs(n);
		w = step(max(a.yzx, a.zxy), a);
	}
	return w / max(w.x + w.y + w.z, 1e-4);
}

// A colour map projected along the frame's axes (uv per axis: x -> zy, y -> xz, z -> xy,
// v running down so the image's up is the frame's up).
vec4 proj_tex(sampler2D t, vec3 p, vec3 w, vec3 dx, vec3 dy) {
	vec4 c = vec4(0.0);
	if (w.x > 0.0) c += textureGrad(t, vec2(p.z, -p.y), vec2(dx.z, -dx.y), vec2(dy.z, -dy.y)) * w.x;
	if (w.y > 0.0) c += textureGrad(t, p.xz, dx.xz, dy.xz) * w.y;
	if (w.z > 0.0) c += textureGrad(t, vec2(p.x, -p.y), vec2(dx.x, -dx.y), vec2(dy.x, -dy.y)) * w.z;
	return c;
}

// The tilt of a projected normal map, in the frame (OpenGL maps: green is the image's up).
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
	float n = vnoise3(p * 2.3) * 0.6 + vnoise3(p * 7.7) * 0.4;
	vec3 w = proj_weights(nf);
	vec3 dx = dFdx(p);
	vec3 dy = dFdy(p);
	float ao = texture(ao_tex, UV).r;

	// Painted-steel grunge: its rust spots are the rust mask, its paint the smudges.
	vec3 pit = proj_tex(pit_albedo, p * pit_scale, w, dx * pit_scale, dy * pit_scale).rgb;
	float spots = clamp((pit.r - pit.b - 0.08) * 2.7, 0.0, 1.0);
	float smudge = dot(pit, vec3(0.33));

	// Inside the cab (the back of the outer panels, the pillars' inner faces) the
	// paint stays clean; not the bonnet's back edge in front of the windshield.
	vec3 to_cab = cab.xyz - p;
	bool in_cab = abs(to_cab.x) < cab.w && abs(to_cab.z) < 0.92 && abs(to_cab.y) < 0.5 && dot(nf, to_cab) > 0.0
			&& nf.y < 0.4 && p.x < 1.42;
	float outside = FRONT_FACING && !in_cab ? 1.0 : 0.0;
	// Faces looking into the gap behind the cab see only its back wall: dark, no sky
	// in their gloss.
	float gap = (1.0 - smoothstep(0.035, 0.08, abs(p.x - gap_x))) * smoothstep(0.3, 0.6, abs(nf.x))
			* (1.0 - smoothstep(1.12, 1.2, h));
	float side = smoothstep(0.3, 0.7, abs(nf.z));
	float vert = 1.0 - smoothstep(0.45, 0.85, abs(nf.y));
	float top = smoothstep(0.55, 0.95, nf.y);
	// Wheel arches: distance outside the arch opening on the side panels.
	vec2 hub_f = vec2(arches.x, arches.z);
	vec2 hub_r = vec2(arches.y, arches.z);
	float da = min(length(p.xy - hub_f), length(p.xy - hub_r)) - arches.w;
	float outer = smoothstep(0.55, 0.75, abs(p.z));
	float arch = (1.0 - smoothstep(0.0, 0.2, da + (n - 0.5) * 0.08)) * outer;

	// Dust and mud: heavy low on the body, sprayed up and back from each tyre, caked
	// on the arch lips and into the panel gaps; a film on the tops.
	float low = 1.0 - smoothstep(0.42, 1.05, h + (n - 0.5) * 0.3);
	float behind_f = arches.x - p.x;
	float behind_r = arches.y - p.x;
	float spray = 0.0;
	for (int k = 0; k < 2; k++) {
		float bx = k == 0 ? behind_f : behind_r;
		vec2 d = vec2(-bx, h - arches.z);
		float ang = atan(d.y, d.x);
		float rays = vnoise2(vec2(ang * 9.0, length(d) * 1.5 + float(k) * 7.0));
		spray = max(spray, (1.0 - smoothstep(0.1, 1.3, bx)) * smoothstep(-0.25, 0.1, bx)
				* (1.0 - smoothstep(0.55, 1.15, h)) * (0.45 + 0.8 * rays));
	}
	float lip = (1.0 - smoothstep(0.0, 0.07, abs(da + 0.01))) * outer;
	float dirt = clamp(low * 0.75 + spray * 0.6 + lip * 0.6 + (1.0 - ao) * 0.5 + top * 0.18 + 0.06, 0.0, 1.0);
	dirt *= smoothstep(0.15, 0.6, n * 0.7 + smudge * 0.5 + low * 0.35);
	dirt = clamp(dirt * wear * 1.25, 0.0, 1.0) * outside;
	// Inside the bed: scuffed by every load, dust in the corners. Only the floor and
	// the walls' inner faces (the outer skins sit further out than the inner walls).
	float bed = (1.0 - smoothstep(-0.05, 0.1, p.x)) * (1.0 - smoothstep(0.8, 0.84, abs(p.z)))
			* step(0.55, h) * (1.0 - smoothstep(1.15, 1.25, h)) * outside;
	float inward = max(step(0.7, nf.y), step(0.5, -sign(p.z) * nf.z));
	inward = max(inward, max(step(0.5, -nf.x) * step(-1.0, p.x), step(0.5, nf.x) * step(p.x, -1.5)));
	bed *= inward;

	float broad = vnoise3(p * 0.6 + 11.0);
	vec3 base = paint * (0.94 + 0.12 * vnoise3(p * 0.7));
	float rough = roughness + (smudge - 0.6) * 0.12;
	float coat = clearcoat;
	float chalk = 0.0;
	if (fade > 0.0) {
		// Oxidised single-stage paint: pale, grey and flat where the sun beats down,
		// in blotches, milder down the sides.
		// The roof and bonnet are chalky all over, worse in blotches.
		float blotch = vnoise3(p * 1.6) * 0.7 + smudge * 0.3;
		chalk = fade * (0.3 + 0.7 * top) * (0.2 + 1.5 * blotch * blotch) + fade * top * (0.45 + 0.35 * blotch);
		chalk = clamp(chalk, 0.0, 1.0) * outside;
		// Patches where it was polished or touched up stay a shade darker and richer.
		base *= mix(1.0, 0.8 + 0.3 * smoothstep(0.3, 0.7, smudge + broad * 0.5 - 0.25), fade);
		float grey = dot(base, vec3(0.3, 0.59, 0.11));
		base = mix(base, mix(vec3(grey), base, 0.5) * 1.35 + vec3(0.018, 0.018, 0.016), chalk);
		rough = mix(rough, 0.8, chalk);
		coat *= 1.0 - smoothstep(0.15, 0.35, chalk);
	}

	vec3 col = base;
	float metal = metallic;
	vec3 tilt = vec3(0.0);
	float rusted = 0.0;
	if (rust > 0.0) {
		// How far gone each spot is: the sills and door bottoms, the arches, water on
		// flat tops, in patches.
		float sill = 1.0 - smoothstep(0.58, 0.95, h + (n - 0.5) * 0.22 + (broad - 0.5) * 0.3);
		float patchy = vnoise3(p * 1.1 + 3.7) * 0.6 + n * 0.4;
		float sev = rust * (0.06 + 1.1 * sill * vert + 1.2 * arch + 0.1 * top + 0.5 * bed) * (0.3 + 1.2 * patchy) * outside;
		// Spots break through first, then join into scale.
		float t = 1.0 - sev;
		float spot = smoothstep(t, t + 0.07, spots);
		vec3 scale = proj_tex(scale_albedo, p * scale_scale, w, dx * scale_scale, dy * scale_scale).rgb;
		float grain = clamp((dot(scale, vec3(0.33)) - 0.03) / 0.07, 0.0, 1.0);
		float heavy = smoothstep(0.5, 0.68, sev + (grain - 0.5) * 0.35);
		rusted = max(spot, heavy);
		// A bubbled, darker rim of paint lifts around each spot.
		float blister = smoothstep(t - 0.16, t, spots) * (1.0 - rusted);
		// Brown scale, fresher orange at the spots' edges.
		vec3 rc = mix(scale * 1.05, pit * vec3(0.62, 0.5, 0.42), spot * (1.0 - heavy) * 0.35);
		col = mix(col, col * 0.7 + rc * 0.12, blister * 0.8);
		col = mix(col, rc, rusted);
		rough = mix(rough, 0.9, max(rusted, blister * 0.5));
		metal *= 1.0 - max(rusted, blister);
		coat *= 1.0 - max(rusted, blister * 0.7);
		if (detail > 0.5) {
			tilt = proj_tilt(pit_normal, p * pit_scale, w, dx * pit_scale, dy * pit_scale) * (blister * 1.6 + spot * 0.8);
			if (heavy > 0.0) {
				tilt += proj_tilt(scale_normal, p * scale_scale, w, dx * scale_scale, dy * scale_scale) * heavy * 1.1;
			}
		}
		// Rust bleeds down the panels below the spots.
		float above = rust * (0.06 + 0.95 * (1.0 - smoothstep(0.58, 0.95, h - 0.16)) * vert) * (0.3 + 1.2 * patchy);
		float run = vnoise2(vec2(p.x * 26.0 + p.z * 19.0, h * 1.4)) * 0.7 + vnoise2(vec2(p.x * 61.0, h * 3.0)) * 0.3;
		float bleed = smoothstep(0.35, 0.8, above) * smoothstep(0.45, 0.75, run) * side * (1.0 - rusted);
		col = mix(col, col * 0.65 + rc * 0.3, bleed * 0.55);
		rough = mix(rough, 0.75, bleed * 0.5);
	}
	float streak = 0.0;
	if (streaks > 0.0) {
		// Grime run down the sides from the window line and the bed rails.
		float s = vnoise2(vec2(p.x * 17.0 + p.z * 13.0, h * 0.9)) * 0.7 + vnoise2(vec2(p.x * 43.0 + p.z * 29.0, h * 2.2)) * 0.3;
		streak = smoothstep(0.52, 0.8, s) * side * streaks * (1.0 - rusted);
		col = mix(col, col * 0.6 + dirt_color * 0.1, streak * 0.6);
		rough = mix(rough, 0.75, streak * 0.5);
	}

	// Loads scrape the bed floor and walls down to dull, scratched metal.
	float scuff = bed * smoothstep(0.35, 0.75, vnoise2(vec2(p.x * 3.0, p.z * 40.0)) * 0.6 + n * 0.4) * (1.0 - rusted)
			* clamp(wear * 1.2, 0.25, 1.0);
	col = mix(col, mix(col, vec3(0.16, 0.16, 0.15), 0.6), scuff * 0.8);
	rough = mix(rough, 0.55, scuff);
	coat *= 1.0 - scuff;
	dirt = max(dirt, bed * wear * 0.5 * smoothstep(0.3, 0.7, n + (1.0 - top) * 0.2));
	// Dust, darker where it is caked mud, over everything; flaking rust shows through.
	dirt *= 1.0 - 0.6 * rusted;
	vec3 dc = dirt_color * (0.72 + 0.35 * n) * mix(1.0, 0.7, spray * lip);
	col = mix(col, dc, dirt);
	float wet = wetness;
	ALBEDO = col * (1.0 - wet * mix(0.12, 0.35, dirt)) * (1.0 - 0.6 * gap);
	ROUGHNESS = clamp(mix(mix(rough, 0.92, dirt) * mix(1.0, 0.5, wet), 0.7, gap), 0.05, 1.0);
	METALLIC = metal * (1.0 - dirt) * (1.0 - gap);
	SPECULAR = 0.5 * (1.0 - 0.8 * gap);
	// Inside the cab only the windows let the sky's light in.
	AO = ao * mix(0.4, 1.0, outside) * (1.0 - 0.75 * gap);
	CLEARCOAT = coat * (1.0 - smoothstep(0.15, 0.7, dirt)) * (1.0 - gap);
	CLEARCOAT_ROUGHNESS = clamp(clearcoat_roughness + dirt * 0.3 + chalk * 0.2, 0.0, 1.0);
	if (dot(tilt, tilt) > 0.0) {
		NORMAL = normalize(NORMAL + (v_ax * tilt.x + v_ay * tilt.y + v_az * tilt.z) * (1.0 - dirt * 0.6));
	}
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 0.7;
	}
}
