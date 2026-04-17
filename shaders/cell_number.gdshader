shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform sampler2D digit_atlas : filter_linear, source_color;
uniform vec3 camera_up    = vec3(0.0, 1.0, 0.0);
uniform vec3 camera_right = vec3(1.0, 0.0, 0.0);

varying float v_digit_idx;

void vertex() {
	vec3 face_normal = normalize(INSTANCE_CUSTOM.rgb * 2.0 - 1.0);
	v_digit_idx = INSTANCE_CUSTOM.a;

	vec3 up = camera_up - face_normal * dot(camera_up, face_normal);
	float up_len = length(up);

	if (up_len < 0.001) {
		up = camera_right - face_normal * dot(camera_right, face_normal);
		up = normalize(up);
	} else {
		up = up / up_len;
	}

	vec3 right = cross(up, face_normal);

	vec3 oriented = right * VERTEX.x + up * VERTEX.y;
	VERTEX = oriented;
}

void fragment() {
	float digit = round(v_digit_idx * 7.0);
	vec2 atlas_uv = vec2((UV.x + digit) / 8.0, UV.y);

	vec4 tex = texture(digit_atlas, atlas_uv);

	ALBEDO = COLOR.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}
