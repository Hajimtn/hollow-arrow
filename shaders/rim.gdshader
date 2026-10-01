shader_type canvas_item;
// One-pixel coloured rim around a sprite. The pack's reaper/wizard are almost pure black, so tinting does nothing:
// the rim colour is what tells the boss forms (and the dark arenas) apart.
uniform vec4 rim_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
uniform float rim_size = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * rim_size;
	float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	if (c.a < 0.1 && a > 0.1) {
		COLOR = rim_color;
	} else {
		COLOR = c;
	}
}
