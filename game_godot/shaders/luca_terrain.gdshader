shader_type spatial;
render_mode world_vertex_coords;

uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec3 ground_tint : source_color = vec3(1.0);
uniform vec3 soil_tint : source_color = vec3(1.0);
uniform vec3 rock_tint : source_color = vec3(1.0);
uniform float texture_scale = 0.11;
uniform float rock_start = 0.24;
uniform float rock_full = 0.62;
uniform float soil_strength = 0.34;

vec3 triplanar_color(sampler2D tex, vec3 p, vec3 n) {
	vec3 weights = pow(abs(n), vec3(5.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 x_axis = texture(tex, p.zy).rgb;
	vec3 y_axis = texture(tex, p.xz).rgb;
	vec3 z_axis = texture(tex, p.xy).rgb;
	return x_axis * weights.x + y_axis * weights.y + z_axis * weights.z;
}
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 sample_pos = VERTEX * texture_scale;
	vec3 ground = triplanar_color(ground_tex, sample_pos, n) * ground_tint;
	vec3 soil = triplanar_color(soil_tex, sample_pos * 0.93, n) * soil_tint;
	vec3 rock = triplanar_color(rock_tex, sample_pos * 0.78, n) * rock_tint;

	float macro_a = sin(VERTEX.x * 0.027 + sin(VERTEX.z * 0.013));
	float macro_b = cos(VERTEX.z * 0.021 - sin(VERTEX.x * 0.017));
	float macro = clamp(0.5 + 0.25 * macro_a + 0.25 * macro_b, 0.0, 1.0);
	float soil_mix = smoothstep(0.40, 0.78, macro) * soil_strength;
	soil_mix = max(soil_mix, clamp(COLOR.r, 0.0, 1.0) * 0.88);

	float slope = 1.0 - clamp(n.y, 0.0, 1.0);
	float rock_mix = smoothstep(rock_start, rock_full, slope);
	vec3 earth = mix(ground, soil, soil_mix);
	ALBEDO = mix(earth, rock, rock_mix);
	ROUGHNESS = mix(0.94, 0.80, rock_mix);
	SPECULAR = 0.18;
}
