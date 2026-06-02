shader_type canvas_item;
render_mode blend_add;

uniform float intensity : hint_range(0.0, 4.0) = 1.6;
uniform float speed : hint_range(0.0, 2.0) = 0.15;
uniform float depth : hint_range(0.0, 1.0) = 0.0;
uniform bool debug_marker_enabled = false;
uniform vec2 debug_marker_position = vec2(0.5, 0.18);
uniform float debug_marker_radius : hint_range(0.01, 0.25) = 0.08;
uniform vec4 ray_color : source_color = vec4(0.9, 0.98, 1.0, 0.38);

float light_shaft(vec2 uv, float origin_x, float slope, float width, float wave_phase, float drift) {
	float center_x = origin_x + drift + uv.y * slope + sin(uv.y * 5.0 + wave_phase) * 0.018;
	float distance_to_center = abs(uv.x - center_x);
	float core = smoothstep(width, 0.0, distance_to_center);
	float glow = smoothstep(width * 3.6, 0.0, distance_to_center) * 0.18;
	return core + glow;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	float slow_time = TIME * 0.18;
	float beam1_drift = sin(slow_time + 0.3) * 0.035;
	float beam2_drift = sin(slow_time * 0.82 + 2.1) * 0.025;
	float beam3_drift = sin(slow_time * 1.05 + 4.2) * 0.035;

	float beam1 = light_shaft(uv, 0.34, -0.18, 0.026, t + 0.4, beam1_drift);
	float beam2 = light_shaft(uv, 0.50, 0.0, 0.034, -t * 1.15, beam2_drift);
	float beam3 = light_shaft(uv, 0.66, 0.18, 0.026, t * 0.9 + 2.0, beam3_drift);

	// 焦散閃動
	float shimmer = sin(uv.y * 28.0 + t * 8.0) * 0.5 + 0.5;

	// 上亮下暗
	float fade = pow(1.0 - uv.y, 1.8) * smoothstep(0.95, 0.05, uv.y);

	// 合成
	float rays = (beam1 * 0.9 + beam2 * 1.05 + beam3 * 0.9) * fade;
	rays *= 0.75 + shimmer * 0.25;
	rays *= 1.0 - depth * 0.55;

	vec4 output_color = vec4(ray_color.rgb, rays * ray_color.a * intensity);

	if (debug_marker_enabled) {
		vec2 marker_aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
		float marker_distance = length((uv - debug_marker_position) * marker_aspect);
		float marker = 1.0 - smoothstep(debug_marker_radius * 0.82, debug_marker_radius, marker_distance);
		output_color = mix(output_color, vec4(1.0, 0.0, 0.0, 1.0), marker);
	}

	COLOR = output_color;
}
