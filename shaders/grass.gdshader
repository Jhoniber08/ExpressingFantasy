// Pasto: viento, se aparta del jugador y se oscurece en la base
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

global uniform vec3 player_pos;
uniform float wind_strength = 0.22;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 root = MODEL_MATRIX[3].xyz;
	float k = UV.y * UV.y;
	float w = sin(TIME * 1.8 + root.x * 0.35 + root.z * 0.27) + 0.5 * sin(TIME * 3.1 + root.z * 0.8);
	VERTEX.x += w * wind_strength * k;
	VERTEX.z += w * wind_strength * 0.5 * k;
	vec3 away = root - player_pos;
	float d = length(away.xz);
	if (d < 1.4) {
		vec2 push = normalize(away.xz + vec2(0.001)) * (1.4 - d) * 0.9 * k;
		mat3 inv = inverse(mat3(MODEL_MATRIX));
		vec3 lp = inv * vec3(push.x, 0.0, push.y);
		VERTEX += lp;
		VERTEX.y -= (1.4 - d) * 0.25 * k;
	}
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = COLOR.rgb * mix(0.42, 0.92, UV.y);
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.10, 0.14, 0.05);
}
