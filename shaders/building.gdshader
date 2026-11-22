// Edificios: ventanas procedurales que se encienden de noche
shader_type spatial;
render_mode cull_back;

global uniform float night;
varying vec3 wpos;
varying vec3 wn;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float win_mask = COLOR.a; // 1 = fachada con ventanas
	vec3 col = base;
	vec3 emis = vec3(0.0);
	if (win_mask > 0.5 && abs(wn.y) < 0.3) {
		float u = (abs(wn.x) > abs(wn.z)) ? wpos.z : wpos.x;
		float v = wpos.y;
		vec2 cell = vec2(floor(u / 2.4), floor(v / 3.2));
		vec2 f = vec2(fract(u / 2.4), fract(v / 3.2));
		float inside = step(0.22, f.x) * step(f.x, 0.78) * step(0.28, f.y) * step(f.y, 0.82);
		float floor_line = step(f.y, 0.06);
		col = mix(col, col * 0.8, floor_line);
		vec3 glass = vec3(0.16, 0.22, 0.30);
		col = mix(col, glass, inside);
		float lit = step(0.58, hash2(cell + floor(wpos.xz / 23.0)));
		vec3 warm = mix(vec3(1.0, 0.78, 0.45), vec3(0.6, 0.85, 1.0), step(0.85, hash2(cell * 1.7)));
		emis = warm * inside * lit * night * 0.75;
		if (v < 1.0) { emis *= 0.0; }
	}
	ALBEDO = col;
	EMISSION = emis;
	ROUGHNESS = 0.75;
}
