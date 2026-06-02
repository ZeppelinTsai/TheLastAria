shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 0.012) = 0.004;
uniform float speed : hint_range(0.0, 1.0) = 0.25;
uniform float wave_scale_x : hint_range(4.0, 40.0) = 14.0;
uniform float wave_scale_y : hint_range(4.0, 40.0) = 18.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * speed;

	float dx = sin(uv.y * wave_scale_y + t) * strength;
	float dy = sin(uv.x * wave_scale_x - t * 1.2) * strength * 0.65;
	vec2 offset = vec2(dx, dy);

	COLOR = texture(screen_texture, uv + offset);
}
