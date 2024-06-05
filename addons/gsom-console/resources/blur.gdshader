shader_type canvas_item;

uniform float blur: hint_range(0.0, 5.0) = 3.0;
uniform vec4 color: source_color = vec4(0.0, 0.0, 0.0, 0.3);
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec3 tex = texture(SCREEN_TEXTURE, SCREEN_UV, blur).rgb;
	vec3 final = mix(tex, color.rgb, color.a);
	COLOR = vec4(final, 1.0);
}
