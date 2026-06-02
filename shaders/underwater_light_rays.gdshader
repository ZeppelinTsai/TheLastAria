shader_type canvas_item;

uniform float intensity : hint_range(0.0, 2.0) = 0.9;
uniform float speed : hint_range(0.0, 3.0) = 0.4;
uniform float depth : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ray_color : source_color = vec4(0.9, 0.95, 1.0, 0.12);

void fragment() {
    vec2 uv = UV;
    float t = TIME * speed;
    // multiple angled streaks
    float rays = 0.0;
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * 0.523598776; // 30 degrees steps
        vec2 dir = vec2(cos(angle), sin(angle));
        float v = dot(uv - vec2(0.5, 0.0), dir) * 4.0;
        v += sin(t * (0.6 + float(i) * 0.08) + float(i) * 1.3) * 0.25;
        rays += smoothstep(0.0, 0.25, fract(v) * (1.0 - abs(dir.y)));
    }
rays = clamp(rays * intensity * 0.25, 0.0, 1.0);
	COLOR = ray_color * rays;
	COLOR.rgb *= (1.0 - depth * 0.25);
}
