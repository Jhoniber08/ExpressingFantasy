// Árboles y arbustos: color por vértice; las hojas (alfa=1) se mecen con el viento
shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float leaf = COLOR.a;
	float k = clamp(VERTEX.y * 0.12, 0.0, 1.5) * leaf;
	float w = sin(TIME * 1.3 + root.x * 0.2 + root.z * 0.15) * 0.12 + sin(TIME * 3.7 + VERTEX.y + root.x) * 0.03;
	VERTEX.x += w * k;
	VERTEX.z += w * 0.6 * k;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.06, 0.09, 0.03) * COLOR.a;
}
