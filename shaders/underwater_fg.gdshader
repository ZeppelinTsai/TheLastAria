shader_type canvas_item;

uniform float time_scale : hint_range(0.1, 3.0) = 1.0;
uniform float bubble_count : hint_range(5.0, 50.0) = 40.0;
uniform float bubble_size : hint_range(0.001, 0.02) = 0.01;
uniform vec4 bubble_color : source_color = vec4(0.6, 0.85, 1.0, 0.28);
uniform vec4 caustic_color : source_color = vec4(0.4, 0.7, 1.0, 0.10);

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * time_scale;
    vec4 result = vec4(0.0);

    // 泡泡
    for (float i = 0.0; i < 20.0; i++) {
        if (i >= bubble_count) break;
        vec2 seed = vec2(i * 0.1731, i * 0.3497);
        float bx = rand(seed) + sin(t * 0.3 + i) * 0.015;
        float speed = 0.04 + rand(seed + 0.5) * 0.06;
        float by = 1.0 - fract(rand(seed + 1.0) + t * speed);
        float wobble = sin(t * 2.0 + i * 1.7) * 0.008;
        vec2 bpos = vec2(bx + wobble, by);
        float dist = length(uv - bpos);
        float size = bubble_size * (0.5 + rand(seed + 2.0) * 0.5);
        float bubble = smoothstep(size, size * 0.3, dist);
        result += bubble_color * bubble;
    }

    // 光影焦散
    float caustic = sin(uv.x * 8.0 + t * 0.7) * sin(uv.y * 6.0 + t * 0.5);
    caustic += sin(uv.x * 13.0 - t * 0.4) * sin(uv.y * 9.0 + t * 0.3);
    caustic = caustic * 0.25 + 0.25;
    result += caustic_color * caustic;

    COLOR = result;
}
