// Haz de luz del destino (estilo GPS)
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.25, 0.9, 1.0);

void fragment() {
	float edge = pow(1.0 - abs(UV.x - 0.5) * 2.0, 1.5);
	float fade = 1.0 - UV.y;
	float pulse = 0.75 + 0.25 * sin(TIME * 4.0);
	ALBEDO = color.rgb;
	ALPHA = edge * fade * pulse * 0.6;
}
