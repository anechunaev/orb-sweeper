## Renders mine-count numbers on cleared Goldberg faces using a single
## [MultiMeshInstance3D] draw call.
##
## Quads always face outward from the sphere and rotate around their face
## normal so the text stays upright relative to the camera — even during
## roll or tumble.  All orientation math runs on the GPU via the shader;
## the CPU only updates two vec3 uniforms per frame.
##
## [codeblock]
## # Setup (in SphericalMinesweeper._ready or similar):
## var number_renderer := CellNumberRenderer.new()
## add_child(number_renderer)
## number_renderer.setup(camera, result.face_count, sphere_radius, subdivision)
##
## # When a cell is revealed:
## if count > 0:
##     number_renderer.show_number(face_id, count, face_center, face_normal)
##
## # On restart:
## number_renderer.clear_all()
## [/codeblock]
class_name CellNumberRenderer
extends Node3D

## Classic Minesweeper digit colors.
const DIGIT_COLORS: Array[Color] = [
	Color(0.15, 0.25, 0.95),   # 1 — blue
	Color(0.10, 0.55, 0.15),   # 2 — green
	Color(0.90, 0.15, 0.10),   # 3 — red
	Color(0.10, 0.10, 0.60),   # 4 — dark blue
	Color(0.60, 0.10, 0.10),   # 5 — maroon
	Color(0.10, 0.55, 0.55),   # 6 — teal
	Color(0.15, 0.15, 0.15),   # 7 — dark gray
	Color(0.45, 0.45, 0.45),   # 8 — gray
]

## 5 × 7 bitmap patterns for digits 1–8.  '#' = filled pixel.
const DIGIT_PATTERNS: Array[Array] = [
	[  # 1
		"..#..",
		".##..",
		"..#..",
		"..#..",
		"..#..",
		"..#..",
		".###.",
	],
	[  # 2
		".###.",
		"#...#",
		"....#",
		"..##.",
		".#...",
		"#....",
		"#####",
	],
	[  # 3
		".###.",
		"#...#",
		"....#",
		"..##.",
		"....#",
		"#...#",
		".###.",
	],
	[  # 4
		"...#.",
		"..##.",
		".#.#.",
		"#..#.",
		"#####",
		"...#.",
		"...#.",
	],
	[  # 5
		"#####",
		"#....",
		"####.",
		"....#",
		"....#",
		"#...#",
		".###.",
	],
	[  # 6
		".###.",
		"#....",
		"#....",
		"####.",
		"#...#",
		"#...#",
		".###.",
	],
	[  # 7
		"#####",
		"....#",
		"...#.",
		"..#..",
		"..#..",
		".#...",
		".#...",
	],
	[  # 8
		".###.",
		"#...#",
		"#...#",
		".###.",
		"#...#",
		"#...#",
		".###.",
	],
]

const _BMP_W := 5
const _BMP_H := 7
const _SCALE := 5          # render each bitmap pixel as _SCALE × _SCALE
const _PAD   := 3          # padding around glyph inside cell

const _CELL_W := _BMP_W * _SCALE + _PAD * 2   # 31
const _CELL_H := _BMP_H * _SCALE + _PAD * 2   # 41

var _multi_mesh: MultiMesh
var _mmi: MultiMeshInstance3D
var _material: ShaderMaterial
var _camera: Camera3D

var _active_count: int = 0
var _quad_size: float = 0.15   # world-space half-extent of each number quad

var _shader: Shader

## Initialise the renderer.
## [param cam] — the [Camera3D] used for orientation.
## [param max_faces] — maximum number of faces (pre-allocates instance buffer).
## [param sphere_radius] — used to compute appropriate quad size.
## [param subdivision] — Goldberg subdivision level (affects quad sizing).
## [param number_shader] — the [code]cell_number.gdshader[/code] resource.
func setup(cam: Camera3D, max_faces: int, sphere_radius: float,
		   subdivision: int, number_shader: Shader) -> void:
	_camera = cam
	_shader = number_shader

	var edge_approx := GoldbergPolyhedron.approx_face_edge(sphere_radius, subdivision)
	_quad_size = edge_approx * 0.55

	var atlas := _generate_atlas()

	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.set_shader_parameter("digit_atlas", atlas)

	var quad := _create_quad_mesh()

	_multi_mesh = MultiMesh.new()
	_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_multi_mesh.use_colors = true
	_multi_mesh.use_custom_data = true
	_multi_mesh.instance_count = max_faces
	_multi_mesh.visible_instance_count = 0
	_multi_mesh.mesh = quad

	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _multi_mesh
	_mmi.material_override = _material
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)


## Display a number on a cleared face.
## [param face_id] — only used externally; internally the instance index is auto-incremented.
## [param count] — mine neighbour count (1–8).
## [param center] — world-space face center on the sphere.
## [param normal] — outward face normal (unit vector).
func show_number(_face_id: int, count: int, center: Vector3, normal: Vector3) -> void:
	if count < 1 or count > 8:
		return

	var idx := _active_count
	_active_count += 1
	_multi_mesh.visible_instance_count = _active_count

	var t := Transform3D()
	t = t.scaled(Vector3(_quad_size, _quad_size, _quad_size))
	t.origin = center
	_multi_mesh.set_instance_transform(idx, t)

	_multi_mesh.set_instance_color(idx, DIGIT_COLORS[count - 1])

	# Custom data layout read by the shader: rgb = encoded normal, a = digit index / 7.
	var encoded_normal := Color(
		(normal.x + 1.0) / 2.0,
		(normal.y + 1.0) / 2.0,
		(normal.z + 1.0) / 2.0,
		float(count - 1) / 7.0,
	)
	_multi_mesh.set_instance_custom_data(idx, encoded_normal)


## Remove all numbers (e.g. on game restart).
func clear_all() -> void:
	_active_count = 0
	if _multi_mesh:
		_multi_mesh.visible_instance_count = 0


func _process(_delta: float) -> void:
	if _camera and _material:
		var cambasis := _camera.global_transform.basis
		_material.set_shader_parameter("camera_up", cambasis.y)
		_material.set_shader_parameter("camera_right", cambasis.x)


func _generate_atlas() -> ImageTexture:
	var atlas_w := _CELL_W * 8
	var atlas_h := _CELL_H
	var img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for d in 8:
		var pattern: Array = DIGIT_PATTERNS[d]
		var ox: int = d * _CELL_W + _PAD    # x-offset for this digit cell
		var oy: int = _PAD                    # y-offset

		for row in _BMP_H:
			var line: String = pattern[row]
			for col in _BMP_W:
				if line[col] == "#":
					# Fill a _SCALE × _SCALE block
					for sy in _SCALE:
						for sx in _SCALE:
							var px: int = ox + col * _SCALE + sx
							var py: int = oy + row * _SCALE + sy
							img.set_pixel(px, py, Color.WHITE)

	return ImageTexture.create_from_image(img)


func _create_quad_mesh() -> ArrayMesh:
	var verts := PackedVector3Array([
		Vector3(-0.5, -0.5, 0.0),
		Vector3( 0.5, -0.5, 0.0),
		Vector3( 0.5,  0.5, 0.0),
		Vector3(-0.5,  0.5, 0.0),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX]  = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
