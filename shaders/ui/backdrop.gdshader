shader_type canvas_item;
// Full-screen backdrop behind menus: the game view blurred, darkened and
// vignetted so the window in front stands out.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 2.4;
uniform float dim = 0.45;
uniform float vignette = 0.55;
uniform float fade = 1.0;

void fragment() {
	vec2 o = SCREEN_PIXEL_SIZE * exp2(blur) * 0.9;
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb * 0.36;
	c += textureLod(screen_tex, SCREEN_UV + vec2(o.x, o.y), blur).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-o.x, o.y), blur).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV + vec2(o.x, -o.y), blur).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-o.x, -o.y), blur).rgb * 0.16;
	vec2 q = UV - 0.5;
	float vig = 1.0 - vignette * smoothstep(0.2, 0.85, length(q * vec2(1.3, 1.0)));
	vec3 col = c * (1.0 - dim) * vig;
	vec3 orig = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(mix(orig, col, fade), 1.0);
}
