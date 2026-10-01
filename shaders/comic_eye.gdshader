// A cartoon eyeball (ComicEyes, the "Komik hayvanlar" setting): a glossy white ball with
// a round black pupil where it looks (gaze, in the ball's own space: +Z straight out of
// the head, +Y up) and a little white catch-light on the pupil; an eyelid of the
// animal's own colour coming down from the top as it blinks; out cold (mode 1) the pupil
// gives way to a black X. Drawn on a unit sphere.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 white : source_color = vec3(0.97, 0.96, 0.93);
// Angular radius of the pupil (radians) and of its catch-light.
uniform float pupil = 0.5;
uniform float glint = 0.12;

// Where it looks (unit vector, ball space); how far shut (0 open .. 1 shut); 1 = an X.
instance uniform vec3 gaze = vec3(0.0, 0.0, 1.0);
instance uniform float blink = 0.0;
instance uniform float mode = 0.0;
instance uniform vec4 lid : source_color = vec4(0.75, 0.3, 0.22, 1.0);

varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

// 1 inside a disc of angular radius r round direction c, antialiased.
float spot(vec3 d, vec3 c, float r) {
	float a = acos(clamp(dot(d, c), -1.0, 1.0));
	float w = max(fwidth(a), 0.002);
	return 1.0 - smoothstep(r - w, r + w, a);
}

void fragment() {
	vec3 d = normalize(dir);
	vec3 g = normalize(gaze);
	vec3 col = white;
	float rough = 0.12;
	if (mode < 0.5) {
		col = mix(col, vec3(0.015), spot(d, g, pupil));
		// The catch-light: up and to one side of the pupil's middle.
		vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), g) + vec3(0.0001));
		vec3 h = normalize(g + (vec3(0.0, 1.0, 0.0) * 0.42 + side * 0.3) * pupil);
		col = mix(col, vec3(1.0), spot(d, h, glint));
	} else {
		// Out cold: an X across the front of the ball.
		vec2 p = d.xy;
		float arm = min(abs(p.x - p.y), abs(p.x + p.y)) * 0.7071;
		float w = max(fwidth(arm), 0.002);
		float x = (1.0 - smoothstep(0.1 - w, 0.1 + w, arm)) * step(max(abs(p.x), abs(p.y)), 0.58) * step(0.0, d.z);
		col = mix(col, vec3(0.015), x);
	}
	// The eyelid: down from the top as it blinks.
	float edge = 1.0 - 2.05 * blink;
	float lw = max(fwidth(d.y), 0.004);
	float shut = smoothstep(edge - lw, edge + lw, d.y) * step(0.001, blink);
	col = mix(col, lid.rgb, shut);
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.75, shut);
	SPECULAR = mix(0.7, 0.3, shut);
	CLEARCOAT = 1.0 - shut;
	CLEARCOAT_ROUGHNESS = 0.06;
}
