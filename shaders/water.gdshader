// Agua: olas suaves, reflejo de Fresnel y brillo especular
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.02, 0.16, 0.30);
uniform vec3 shallow_color : source_color = vec3(0.08, 0.45, 0.55);
uniform float wave_height = 0.35;
uniform float alpha_base = 0.82;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(wpos.x * 0.05 + TIME * 0.9) * 0.6 + sin(wpos.z * 0.07 + TIME * 1.2) * 0.4 + sin((wpos.x + wpos.z) * 0.11 + TIME * 1.7) * 0.25;
	VERTEX.y += w * wave_height;
}

void fragment() {
	float ripple = sin(wpos.x * 0.6 + TIME * 2.0) * sin(wpos.z * 0.5 - TIME * 1.6);
	vec3 n = normalize(vec3(ripple * 0.06, 1.0, cos(wpos.x * 0.3 + TIME) * 0.04));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(shallow_color, deep_color, 0.55 + 0.45 * fres);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = clamp(alpha_base + fres * 0.18, 0.0, 1.0);
}
