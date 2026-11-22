// Pantalla de inicio: viñeta, líneas de escaneo y rejilla animada
shader_type canvas_item;

uniform float intensity = 1.0;

void fragment() {
	vec2 uv = UV;
	float vig = smoothstep(1.15, 0.25, length((uv - vec2(0.38, 0.5)) * vec2(1.25, 1.0)));
	float lines = 0.5 + 0.5 * sin(uv.y * 900.0);
	float sweep = smoothstep(0.0, 0.02, fract(uv.y * 0.5 - TIME * 0.08)) * (1.0 - smoothstep(0.02, 0.06, fract(uv.y * 0.5 - TIME * 0.08)));
	vec2 g = fract(uv * vec2(48.0, 27.0) + vec2(0.0, TIME * 0.05));
	float grid = (step(g.x, 0.02) + step(g.y, 0.03)) * 0.05 * smoothstep(0.55, 0.0, uv.x);
	vec3 col = vec3(0.0, 0.85, 1.0) * (grid + sweep * 0.06);
	float side = smoothstep(0.62, 0.0, uv.x) * 0.62;
	float a = (1.0 - vig) * 0.7 + side + lines * 0.04 + grid + sweep * 0.05;
	COLOR = vec4(mix(vec3(0.0, 0.01, 0.04), col, 0.6), clamp(a * intensity, 0.0, 1.0));
}
