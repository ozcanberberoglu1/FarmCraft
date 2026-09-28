shader_type canvas_item;
// Frosted glass panel: blurred backdrop, dark tint, a faint top sheen, hairline
// border, optional accent glow on the inner edge, and a soft drop shadow drawn in
// the margin around the panel. Drawn as one textured rect covering panel + margin.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// Drawn rect (panel plus `margin` on every side), in canvas units.
uniform vec2 rect_size = vec2(100.0);
uniform float margin = 28.0;
uniform float radius = 14.0;
uniform vec4 tint : source_color = vec4(0.043, 0.055, 0.05, 0.78);
uniform float blur = 3.2;
uniform vec4 border : source_color = vec4(1.0, 1.0, 1.0, 0.12);
uniform vec4 accent : source_color = vec4(0.91, 0.72, 0.31, 0.0);
uniform float shadow = 0.55;
uniform float sheen = 0.06;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 backdrop(vec2 uv, vec2 px) {
	vec2 o = px * exp2(blur) * 0.85;
	vec3 c = textureLod(screen_tex, uv, blur).rgb * 0.36;
	c += textureLod(screen_tex, uv + vec2(o.x, o.y), blur).rgb * 0.16;
	c += textureLod(screen_tex, uv + vec2(-o.x, o.y), blur).rgb * 0.16;
	c += textureLod(screen_tex, uv + vec2(o.x, -o.y), blur).rgb * 0.16;
	c += textureLod(screen_tex, uv + vec2(-o.x, -o.y), blur).rgb * 0.16;
	return c;
}

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	vec2 half_size = rect_size * 0.5 - vec2(margin);
	float d = rounded_box(p, half_size, radius);
	float px = max(fwidth(p.x), 0.0001);
	float inside = clamp(0.5 - d / px, 0.0, 1.0);

	vec3 col = mix(backdrop(SCREEN_UV, SCREEN_PIXEL_SIZE), tint.rgb, tint.a);
	float v = clamp((p.y + half_size.y) / max(2.0 * half_size.y, 1.0), 0.0, 1.0);
	col += sheen * (1.0 - v) * (1.0 - v);
	col = mix(col, accent.rgb, accent.a * (1.0 - smoothstep(0.0, 14.0, -d)));
	float edge = 1.0 - smoothstep(0.0, px * 1.25, abs(d + px * 0.6));
	col = mix(col, border.rgb, edge * border.a);

	float sd = rounded_box(p - vec2(0.0, margin * 0.22), half_size, radius);
	float sh = shadow * (1.0 - smoothstep(-margin * 0.25, margin, sd));
	COLOR = mix(vec4(0.0, 0.0, 0.0, sh * (1.0 - inside)), vec4(col, 1.0), inside);
}
