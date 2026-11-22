// Minimapa circular que gira con la cámara (estilo GTA)
shader_type canvas_item;

uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform vec2 center_uv = vec2(0.5);
uniform float span = 0.12;   // fracción del mapa visible (radio)
uniform float angle = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float c = cos(angle), s = sin(angle);
	vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	vec2 uv = center_uv + q * span;
	vec4 m = texture(map_tex, uv);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { m = vec4(0.04, 0.16, 0.28, 1.0); }
	float rim = smoothstep(0.90, 1.0, r);
	vec3 col = mix(m.rgb, vec3(0.0, 0.8, 1.0), rim * 0.8);
	COLOR = vec4(col, 0.94);
}
