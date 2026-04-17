shader_type spatial;
render_mode cull_front;

uniform vec3 camera_right = vec3(1.0, 0.0, 0.0);
uniform vec3 color_mine : source_color = vec3(0.24, 0.30, 0.40);

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
}

void fragment() {
	ALBEDO = color_mine;
	ROUGHNESS = 0.3;
	SPECULAR = 0.6;
	METALLIC = 0.7;
}
