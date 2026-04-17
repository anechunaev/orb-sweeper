shader_type spatial;
render_mode cull_back;

uniform sampler2D cell_states : filter_nearest, repeat_disable;

uniform float raise_height  : hint_range(0.0, 0.3) = 0.1;
uniform float gap_expansion : hint_range(0.0, 0.1) = 0.01;

uniform vec3 color_unopened  : source_color = vec3(0.36, 0.42, 0.50);
uniform vec3 color_cleared   : source_color = vec3(0.20, 0.26, 0.32);
uniform vec3 color_highlight : source_color = vec3(0.95, 0.15, 0.10);
uniform vec3 color_flagged   : source_color = vec3(0.45, 0.72, 0.55);

uniform float seam_width  : hint_range(0.0, 0.15) = 0.015;
uniform float seam_darken : hint_range(0.0, 1.0)  = 0.80;

uniform float bevel_width     : hint_range(0.0, 0.5) = 0.18;
uniform float bevel_highlight : hint_range(0.0, 1.0) = 0.35;

uniform float rim_power    : hint_range(1.0, 8.0) = 3.5;
uniform float rim_strength : hint_range(0.0, 1.5) = 1.1;
uniform vec3  rim_color    : source_color = vec3(0.55, 0.78, 1.0);

uniform float bevel_glow    : hint_range(0.0, 2.0) = 0.005;
uniform float bevel_roughness : hint_range(0.0, 1.0) = 0.35;

uniform float cliff_darken : hint_range(0.0, 1.0) = 0.15;

uniform float rivet_inset  : hint_range(0.0, 0.5) = 0.08;
uniform float rivet_radius : hint_range(0.0, 0.3) = 0.05;
uniform float rivet_darken : hint_range(0.0, 1.0) = 0.4;

// Mechanical detail variants. Draw subtle sci-fi features (vents, LEDs, ports,
// grilles, chevrons, circuit traces) on a random subset of raised tiles, using
// the same tangent-plane polar system as the rivets. Variant is picked from
// hash(face_uv, detail_seed), so reshuffle by setting detail_seed per game.
uniform float detail_seed     : hint_range(0.0, 1.0) = 0.0;
uniform float detail_density  : hint_range(0.0, 1.0) = 0.28;
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3  detail_emission_color : source_color = vec3(1.0, 0.18, 0.10);

varying float v_state_raw;
varying float v_edge;
varying vec2  v_uv2;
// Rivet frame — ALL in model space. Godot's vertex-shader NORMAL/TANGENT are
// model-local, but the fragment-shader NORMAL is view-space. Don't mix them.
varying vec3  v_face_offset;  // in-plane offset from face center
varying vec3  v_tangent;      // per-face tangent = dir from face_center to ring[0]
varying vec3  v_binormal;     // cross(NORMAL, TANGENT), computed in vertex
varying float v_ring_radius;  // distance from face center to corners

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void vertex() {
	float raw = texture(cell_states, vec2(UV.x, 0.5)).r;
	v_state_raw = raw;

	int state = int(round(raw * 255.0));

	v_face_offset = VERTEX - NORMAL * dot(VERTEX, NORMAL);
	v_tangent     = TANGENT;
	v_binormal    = cross(NORMAL, TANGENT);
	v_ring_radius = COLOR.r;

	bool raised = (state == 0 || state == 2 || state == 5);
	if (raised) {
		VERTEX += NORMAL * raise_height;

		vec3 on_axis = NORMAL * dot(VERTEX, NORMAL);
		vec3 lateral = VERTEX - on_axis;
		VERTEX += lateral * gap_expansion;
	}

	v_edge = UV.y;
	v_uv2  = UV2;
}

void fragment() {
	int state = int(round(v_state_raw * 255.0));

	vec3 base;
	if      (state == 0) { base = color_unopened;  }
	else if (state == 1) { base = color_cleared;   }
	else if (state == 2) { base = color_flagged;   }
	else if (state == 3) { base = color_cleared;   }
	else if (state == 4) { base = color_highlight; }
	else                 { base = color_highlight; }

	bool raised = (state == 0 || state == 2 || state == 5);

	// Mechanical-detail contributions, populated inside the raised block below
	// and consumed by the EMISSION/ROUGHNESS blocks further down.
	vec3  detail_emission    = vec3(0.0);
	float detail_rough_delta = 0.0;

	// Black panel line at the outermost slice.
	float seam_mask = smoothstep(0.0, seam_width, v_edge);
	base *= mix(1.0 - seam_darken, 1.0, seam_mask);

	if (raised) {
		// Bright chamfered bevel just inside the seam.
		float bevel_mask = 1.0 - smoothstep(seam_width, seam_width + bevel_width, v_edge);
		base *= 1.0 + bevel_highlight * bevel_mask;

		// Rivets at each face corner.
		// Build face-local polar coordinates from the interpolated tangent-plane
		// offset. r_norm and theta are smooth everywhere on the face (no fan seams).
		float rx     = dot(v_face_offset, v_tangent);
		float ry     = dot(v_face_offset, v_binormal);
		float r_norm = sqrt(rx * rx + ry * ry) / max(v_ring_radius, 1e-6);
		float theta  = atan(ry, rx);                        // [-PI, PI]

		float sides     = v_uv2.y;
		float a         = theta * sides / (2.0 * 3.14159265); // corners at integer a
		float ang_dist  = abs(a - round(a));                  // 0..0.5 (units of "sides")
		float ang_rad   = ang_dist * 6.28318531 / sides;      // angular distance in radians
		float corner_r  = 1.0 - rivet_inset;
		// Euclidean-ish distance from fragment to nearest-corner rivet center.
		float dx        = r_norm - corner_r;
		float dy        = r_norm * ang_rad;
		float rivet_d   = sqrt(dx * dx + dy * dy);
		float rivet_mask = 1.0 - smoothstep(rivet_radius * 0.7, rivet_radius, rivet_d);
		base *= 1.0 - rivet_darken * rivet_mask;

		// ---- Mechanical detail variants ----
		// Stay inside r_norm < ~0.7 so features don't collide with the rivets
		// (which sit at r_norm ~0.92) or the chamfer/seam ring (v_edge near 0).
		float h0 = hash11(UV.x * 1024.0 + detail_seed * 17.3);
		if (h0 < detail_density) {
			float h1 = hash11(UV.x * 513.0 + detail_seed * 91.7 + 7.0);
			float h2 = hash11(UV.x *  77.0 + detail_seed * 43.1 + 13.0);
			int   variant = int(floor(h1 * 6.0)) + 1;   // 1..6
			float rot     = h2 * 6.28318531;

			// Rotated tangent-plane coords: xr along the feature's primary axis.
			float cr = cos(-rot);
			float sr = sin(-rot);
			float px = r_norm * cos(theta);
			float py = r_norm * sin(theta);
			float xr = cr * px - sr * py;
			float yr = sr * px + cr * py;

			float alb_mul = 1.0;
			vec3  emit    = vec3(0.0);
			float rough_d = 0.0;

			if (variant == 1) {
				// Hatch cover: rectangular plate with a double-line beveled border.
				// Outer line is lit (highlight), inner line is shadowed (recess).
				float half_w = 0.40;
				float half_h = 0.26;
				float soft   = 0.006;
				float inset  = min(half_w - abs(xr), half_h - abs(yr));
				float outer  = smoothstep(-soft, soft, inset) *
				               (1.0 - smoothstep(0.022 - soft, 0.022 + soft, inset));
				float inner  = smoothstep(0.034 - soft, 0.034 + soft, inset) *
				               (1.0 - smoothstep(0.052 - soft, 0.052 + soft, inset));
				alb_mul += 0.35 * outer;
				alb_mul -= 0.45 * inner;
				rough_d += 0.15 * inner;
			} else if (variant == 2) {
				// Indicator LED: small red emissive disc offset from center.
				float d    = length(vec2(xr - 0.35, yr));
				float led  = 1.0 - smoothstep(0.045, 0.070, d);
				float halo = (1.0 - smoothstep(0.070, 0.170, d)) * 0.25;
				alb_mul *= mix(1.0, 0.35, led);
				emit    += detail_emission_color * (led * 1.4 + halo);
			} else if (variant == 3) {
				// Access port: dark inner disc + brighter thin ring.
				float inner = 1.0 - smoothstep(0.10, 0.13, r_norm);
				float ring  = (1.0 - smoothstep(0.22, 0.25, r_norm)) *
				              smoothstep(0.17, 0.20, r_norm);
				alb_mul *= mix(1.0, 0.50, inner);
				alb_mul *= mix(1.0, 1.22, ring);
				rough_d -= 0.15 * ring;
				rough_d += 0.20 * inner;
			} else if (variant == 4) {
				// Grille: parallel fine lines within a band.
				float band    = (1.0 - smoothstep(0.36, 0.42, abs(xr))) *
				                (1.0 - smoothstep(0.24, 0.30, abs(yr)));
				float stripes = smoothstep(0.55, 0.95, abs(sin(yr * 32.0)));
				alb_mul -= 0.45 * band * stripes;
			} else if (variant == 5) {
				// Hazard chevrons in one rectangular patch.
				float half_w = 0.34;
				float half_h = 0.18;
				float soft   = 0.02;
				float mask   = (1.0 - smoothstep(half_w - soft, half_w + soft, abs(xr))) *
				               (1.0 - smoothstep(half_h - soft, half_h + soft, abs(yr)));
				float chev   = smoothstep(0.45, 0.55, fract((xr + yr) * 4.5));
				alb_mul -= 0.40 * mask * chev;
			} else {
				// Variant 6 — Circuit trace: thin emissive line + end pad.
				float in_x  = smoothstep(-0.02, 0.01, xr) *
				              (1.0 - smoothstep(0.50, 0.56, xr));
				float thin  = 1.0 - smoothstep(0.012, 0.022, abs(yr));
				float line  = in_x * thin;
				float pad_d = length(vec2(xr - 0.55, yr));
				float pad   = 1.0 - smoothstep(0.030, 0.050, pad_d);
				emit    += detail_emission_color * (line * 0.35 + pad * 0.85);
				alb_mul -= 0.15 * line;
			}

			// Global dial so the whole effect can be faded out from the inspector.
			alb_mul = mix(1.0, alb_mul, detail_strength);
			emit   *= detail_strength;
			rough_d *= detail_strength;

			base              *= alb_mul;
			detail_emission    = emit;
			detail_rough_delta = rough_d;
		}
	}

	if (!raised) {
		float nearness = 1.0 - smoothstep(0.0, 0.4, v_edge);
		base *= mix(1.0, 1.0 - cliff_darken, nearness);
	}

	ALBEDO = base;

	if (raised) {
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
		// Recompute bevel_mask for emission (cheap, compiler will share).
		float bevel_mask_e = 1.0 - smoothstep(seam_width, seam_width + bevel_width, v_edge);
		EMISSION = rim_color * fresnel * rim_strength
				 + rim_color * bevel_mask_e * bevel_glow
				 + detail_emission;
	} else {
		EMISSION = vec3(0.0);
	}

	if (raised) {
		float bevel_mask_r = 1.0 - smoothstep(seam_width, seam_width + bevel_width, v_edge);
		METALLIC  = 0.25;
		ROUGHNESS = clamp(mix(0.55, bevel_roughness, bevel_mask_r) + detail_rough_delta, 0.0, 1.0);
		SPECULAR  = 0.5;
	} else {
		METALLIC  = 0.0;
		ROUGHNESS = 0.9;
		SPECULAR  = 0.05;
	}
}
