shader_type spatial;

uniform sampler2D ground_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_roughness : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap, repeat_enable;
uniform sampler2D edited_columns : filter_nearest, repeat_disable;
uniform bool mask_edits = false;
uniform float texture_scale = 0.22;
uniform float detail_distance = 40.0;
varying vec3 terrain_position;
varying vec3 terrain_normal;

void vertex() {
	terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 0.0001);
}
vec3 projected(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z;
}
vec3 projected_roughness(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z;
}
vec3 normal_detail(sampler2D tex, vec3 p, vec3 w, vec3 n) {
	vec3 x = texture(tex, p.zy).xyz * 2.0 - 1.0;
	vec3 y = texture(tex, p.xz).xyz * 2.0 - 1.0;
	vec3 z = texture(tex, p.xy).xyz * 2.0 - 1.0;
	// Flat normal maps leave the geometric normal unchanged on every slope.
	return (vec3((x.z - 1.0) * sign(n.x), x.y, x.x) * w.x
		+ vec3(y.x, (y.z - 1.0) * sign(n.y), y.y) * w.y
		+ vec3(z.x, z.y, (z.z - 1.0) * sign(n.z)) * w.z);
}
void fragment() {
	vec2 mask_uv = (terrain_position.xz + vec2(480.0)) / 960.0;
	if (mask_edits && texture(edited_columns, clamp(mask_uv, vec2(0.0), vec2(1.0))).r > 0.5) { discard; }
	vec3 n = normalize(terrain_normal);
	vec3 w = weights(n);
	vec3 p = terrain_position * texture_scale;
	float rock_mix = smoothstep(0.15, 0.48, 1.0 - clamp(n.y, 0.0, 1.0));
	rock_mix = max(rock_mix, smoothstep(30.0, 50.0, terrain_position.y) * 0.55);
	vec3 grass = projected(ground_color, p, w);
	vec3 rock = projected(rock_color, p * 0.73, w);
	float patches = 0.96 + sin(terrain_position.x * 0.019 + cos(terrain_position.z * 0.026)) * 0.04;
	ALBEDO = mix(grass, rock, rock_mix) * mix(vec3(0.69, 0.76, 0.59), vec3(0.86, 0.85, 0.80), rock_mix) * patches;
	ROUGHNESS = mix(0.96, 0.87, rock_mix);
	SPECULAR = 0.20;
	if (distance(terrain_position, CAMERA_POSITION_WORLD) < detail_distance) {
		vec3 detail = mix(normal_detail(ground_normal, p, w, n), normal_detail(rock_normal, p * 0.73, w, n), rock_mix);
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n + detail * 0.45), 0.0)).xyz);
		ROUGHNESS = clamp(mix(projected_roughness(ground_roughness, p, w).r, projected_roughness(rock_roughness, p * 0.73, w).r, rock_mix), 0.65, 1.0);
	}
}
