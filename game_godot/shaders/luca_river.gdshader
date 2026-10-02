shader_type spatial;
render_mode blend_mix, cull_disabled, depth_prepass_alpha;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.34, 0.38, 0.68);
uniform vec4 deep_color : source_color = vec4(0.035, 0.13, 0.19, 0.82);
uniform float flow_speed = 1.8;
uniform float wave_height = 0.075;
uniform float wave_scale = 0.48;

void vertex() {
	float along = VERTEX.x * wave_scale;
	float cross_wave = VERTEX.z * 0.32;
	float wave_a = sin(along + TIME * flow_speed) * wave_height;
	float wave_b = sin(cross_wave - TIME * flow_speed * 0.63) * wave_height * 0.55;
	VERTEX.y += wave_a + wave_b;
}
void fragment() {
	float band_a = sin((VERTEX.x + TIME * 4.2) * 0.72);
	float band_b = sin((VERTEX.z - TIME * 2.7) * 1.17);
	float foam = smoothstep(1.25, 1.78, band_a + band_b);
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.5);
	vec3 base = mix(shallow_color.rgb, deep_color.rgb, 0.42 + fresnel * 0.36);
	ALBEDO = mix(base, vec3(0.82, 0.92, 0.92), foam * 0.22);
	ROUGHNESS = mix(0.16, 0.30, foam);
	METALLIC = 0.04;
	ALPHA = mix(shallow_color.a, deep_color.a, fresnel);
}
