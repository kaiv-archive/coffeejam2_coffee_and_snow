shader_type spatial;

render_mode cull_disabled;

uniform sampler2D tex;

// сила и частота ветра
uniform float wind_strength = 0.2;
uniform float wind_speed = 1.5;
uniform vec2 wind_dir = vec2(1.0, 0.3); // направление ветра в мире

void vertex() {
	// локальная позиция вершины
	vec3 local_pos = VERTEX;

	// ослабление около ствола:
	// чем ближе к (0,0) по XZ, тем меньше эффект
	float trunk_mask = length(local_pos.xz);
	trunk_mask = smoothstep(0.0, 5.0, trunk_mask);

	// глобальная позиция вершины
	vec3 world_pos = (MODEL_MATRIX * vec4(local_pos, 1.0)).xyz;

	// фаза ветра в мировых координатах
	float wind_phase =
		dot(world_pos.xz, normalize(wind_dir)) +
		TIME * wind_speed;

	// смещение ветра
	float wind_offset = sin(wind_phase) * wind_strength * trunk_mask;

	// применяем смещение
	VERTEX.x += wind_dir.x * wind_offset;
	VERTEX.z += wind_dir.y * wind_offset;
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	if (c.a > 0.5) {
		ALPHA = 1.0;
	} else {
		ALPHA = 0.0;
	}
}