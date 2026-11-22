// Terreno: color por vértice + roca en pendientes + detalle procedural
shader_type spatial;
render_mode cull_back, diffuse_burley;

varying vec3 wpos;
varying vec3 wnorm;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), u.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float n1 = vnoise(wpos.xz * 0.45);
	float n2 = vnoise(wpos.xz * 2.3);
	float detail = 0.86 + 0.18 * n1 + 0.08 * n2;
	float slope = 1.0 - wnorm.y;
	vec3 rock = vec3(0.42, 0.40, 0.38) * (0.85 + 0.25 * vnoise(wpos.xz * 0.9 + wpos.y * 0.3));
	float rock_w = smoothstep(0.28, 0.45, slope) * (1.0 - COLOR.a);
	vec3 col = mix(base * detail, rock, rock_w);
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
