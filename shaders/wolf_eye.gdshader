shader_type spatial;
// The grey wolf's eyes (WolfRig, tools/blender/build_wolf.py): the eye mesh lies over the
// head's eye openings; UV2 is the spot in the opening's oval (-1 .. 1, along the head
// and up; glTF stores V from the top, so up is 1 - UV2.y). Painted here: the lids'
// almond opening with black skin round it, and in it a yellow-amber iris with darker
// flecks and rim round a black pupil, under a glossy wet cornea.
// Eye-shine: the layer behind the retina (tapetum lucidum) throws light back the way it
// came, so a light near the one looking (headlights, a fire beside him) makes the eyes
// glow green-gold to him, brightest straight along the light; a light from elsewhere
// gives only the cornea's glint. `shine` scales it (the instance's `shine_amount`: none
// once dead).
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 iris_color : source_color = vec3(0.86, 0.62, 0.2);
uniform vec3 iris_dark : source_color = vec3(0.45, 0.27, 0.06);
uniform vec3 shine_color : source_color = vec3(0.62, 0.95, 0.42);
uniform float shine = 45.0;
// How narrow the shine's cone is (higher: only right along the light).
uniform float shine_power = 28.0;
// The pupil's radius (share of the iris's): wide open, the wolves come by night.
uniform float pupil_size = 0.42;
// Per wolf: 1 alive, 0 dead (no shine).
instance uniform float shine_amount : instance_index(0) = 1.0;

varying float v_open;

float hash(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	vec2 e = vec2(UV2.x, 1.0 - UV2.y);
	// The lids' opening: an almond, its outer corner a little higher; outside it the
	// lids' black skin.
	float ex = e.x;
	float ey = e.y - 0.12 * ex;
	float open_h = 0.62 * pow(max(1.0 - abs(ex) * abs(ex), 0.0), 0.7);
	float lid = smoothstep(-0.06, 0.04, abs(ey) - open_h);
	// The eyeball: a round iris (amber, with darker flecks and rim) filling most of the
	// opening, the pupil in its middle (wide at night).
	vec2 c = e - vec2(0.05, 0.02);
	float r = length(c) / 0.62;
	float ang = atan(c.y, c.x);
	float fleck = mix(0.75, 1.15, hash(floor(ang * 9.0)) * 0.6 + hash(floor(ang * 23.0) + 7.0) * 0.4);
	vec3 iris = mix(iris_color, iris_dark, smoothstep(0.35, 0.95, r)) * fleck;
	float pupil = 1.0 - smoothstep(pupil_size - 0.06, pupil_size, r);
	float in_iris = 1.0 - smoothstep(0.92, 1.0, r);
	vec3 col = mix(vec3(0.05, 0.035, 0.02), iris, in_iris);
	col = mix(col, vec3(0.004), pupil);
	col = mix(col, vec3(0.012, 0.01, 0.009), lid);
	ALBEDO = col;
	ROUGHNESS = mix(0.05, 0.6, lid);
	SPECULAR = 0.5;
	// How much of the shine shows here: through the pupil most, the iris a little.
	v_open = (pupil + in_iris * 0.3) * (1.0 - lid);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI;
	// The wet cornea's tight glint.
	vec3 hv = normalize(LIGHT + VIEW);
	float glint = pow(clamp(dot(NORMAL, hv), 0.0, 1.0), 180.0) * 1.6;
	SPECULAR_LIGHT += glint * ndl * ATTENUATION * LIGHT_COLOR;
	// Eye-shine: back toward a light near the viewer.
	float retro = pow(clamp(dot(LIGHT, VIEW), 0.0, 1.0), shine_power);
	SPECULAR_LIGHT += shine_color * retro * shine * shine_amount * v_open * ATTENUATION * LIGHT_COLOR / PI;
}
