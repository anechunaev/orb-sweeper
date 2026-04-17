shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 camera_right = vec3(1.0, 0.0, 0.0);

uniform float outline_width = 0.1;
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

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

	vec3 oriented_normal =
		right * NORMAL.x +
		pole * NORMAL.y +
		forward * NORMAL.z;

	oriented += oriented_normal * outline_width;

	VERTEX = oriented;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
