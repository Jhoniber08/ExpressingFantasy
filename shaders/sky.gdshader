// Cielo procedural: degradado día/noche, atardecer, sol, luna neón y estrellas
shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float day : hint_range(0.0, 1.0) = 1.0;
uniform float dusk : hint_range(0.0, 1.0) = 0.0;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 day_top = vec3(0.16, 0.38, 0.78);
	vec3 day_hor = vec3(0.66, 0.80, 0.95);
	vec3 night_top = vec3(0.008, 0.012, 0.045);
	vec3 night_hor = vec3(0.045, 0.05, 0.14);
	vec3 dusk_hor = vec3(1.0, 0.45, 0.22);
	vec3 dusk_top = vec3(0.32, 0.20, 0.45);

	float t = pow(1.0 - clamp(h, 0.0, 1.0), 2.6);
	vec3 top = mix(night_top, day_top, day);
	top = mix(top, dusk_top, dusk * 0.6);
	vec3 hor = mix(night_hor, day_hor, day);
	float sun_side = clamp(dot(normalize(d.xz + 1e-4), normalize(sun_dir.xz + 1e-4)) * 0.5 + 0.5, 0.0, 1.0);
	hor = mix(hor, dusk_hor, dusk * (0.35 + 0.65 * sun_side));
	vec3 col = mix(top, hor, t);
	if (h < 0.0) {
		col = mix(hor * 0.7, mix(vec3(0.02, 0.03, 0.06), vec3(0.18, 0.26, 0.36), day), clamp(-h * 4.0, 0.0, 1.0));
	}
	// sol
	vec3 sd = normalize(sun_dir);
	float s = max(dot(d, sd), 0.0);
	float sun_vis = smoothstep(-0.08, 0.05, sd.y);
	col += vec3(1.0, 0.9, 0.7) * smoothstep(0.9993, 0.9997, s) * 12.0 * sun_vis;
	col += vec3(1.0, 0.7, 0.4) * pow(s, 12.0) * 0.35 * sun_vis;
	// luna neón
	vec3 md = normalize(moon_dir);
	float m = max(dot(d, md), 0.0);
	float moon_vis = smoothstep(-0.05, 0.08, md.y) * (1.0 - day * 0.85);
	float disk = smoothstep(0.99905, 0.99935, m);
	col = mix(col, vec3(0.86, 0.98, 1.0) * 1.6, disk * moon_vis);
	col += vec3(0.25, 0.85, 1.0) * pow(m, 900.0) * 2.5 * moon_vis;
	col += vec3(0.55, 0.30, 1.0) * pow(m, 60.0) * 0.35 * moon_vis;
	// estrellas
	if (h > 0.0) {
		vec3 cell = floor(d * 260.0);
		float r = hash3(cell);
		float star = step(0.9978, r) * smoothstep(0.02, 0.25, h) * (1.0 - day);
		col += vec3(0.85, 0.9, 1.0) * star * (0.6 + 0.4 * hash3(cell + 7.0));
	}
	COLOR = col;
}
