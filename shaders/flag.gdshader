shader_type spatial;
render_mode cull_disabled;

uniform vec3 camera_right = vec3(1.0, 0.0, 0.0);
uniform vec3 color_pole  : source_color = vec3(0.35, 0.35, 0.35);
uniform vec3 color_cloth : source_color = vec3(0.95, 0.25, 0.20);

varying float v_is_cloth;

void vertex() {
	vec3 pole = normalize(INSTANCE_CUSTOM.rgb * 2.0 - 1.0);

	vec3 right = camera_right - pole * dot(camera_right, pole);
	float r_len = length(right);
	if (r_len < 0.001) {
		right = vec3(1.0, 0.0, 0.0);
	} else {
		right = right / r_len;
	}
	vec3 forward = cross(pole, right);

	vec3 oriented = right * VERTEX.x + pole * VERTEX.y + forward * VERTEX.z;
	VERTEX = oriented;

	v_is_cloth = COLOR.r;
}

void fragment() {
	ALBEDO = v_is_cloth > 0.5 ? color_cloth : color_pole;
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
}
