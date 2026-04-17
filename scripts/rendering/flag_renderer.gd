## Renders flag markers on flagged Goldberg faces using a single
## [MultiMeshInstance3D] draw call.
##
## Flags stand perpendicular to the tile surface (pole along face normal)
## and rotate so the cloth always faces the camera.
##
## Vertex colors distinguish pole (R=0) from cloth (R=1).
## For custom meshes: paint pole verts black, cloth verts red.
##
## [codeblock]
## var flag_renderer := FlagRenderer.new()
## add_child(flag_renderer)
## flag_renderer.setup(camera, face_count, sphere_radius, subdivision, flag_shader)
##
## flag_renderer.add_flag(face_id, face_center, face_normal)
## flag_renderer.remove_flag(face_id)
## flag_renderer.clear_all()
## [/codeblock]
class_name FlagRenderer
extends Node3D

var _multi_mesh: MultiMesh
var _mmi: MultiMeshInstance3D
var _material: ShaderMaterial
var _camera: Camera3D

var _active_count: int = 0
var _flag_size: float = 0.1

# Mapping for O(1) add/remove with swap-last strategy
var _face_to_idx: Dictionary = {}    # face_id → instance index
var _idx_to_face: Dictionary = {}    # instance index → face_id

# Store per-instance data for swaps
var _transforms: Array = []          # Transform3D per instance
var _custom_data: Array = []         # Color per instance

## Initialise the renderer.
## [param flag_shader] — single shader; uses vertex color R to distinguish
## pole (R=0) and cloth (R=1).
## [param custom_mesh] — optional mesh.  Must use vertex colors for
## pole/cloth distinction if the shader relies on them.
func setup(cam: Camera3D, max_faces: int, sphere_radius: float,
		   subdivision: int, flag_shader: Shader,
		   custom_mesh: Mesh = null) -> void:
	_camera = cam

	var edge_approx := GoldbergPolyhedron.approx_face_edge(sphere_radius, subdivision)
	_flag_size = edge_approx * 0.35

	_material = ShaderMaterial.new()
	_material.shader = flag_shader

	var flag_mesh: Mesh = custom_mesh if custom_mesh else _create_flag_mesh()

	_multi_mesh = MultiMesh.new()
	_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_multi_mesh.use_colors = true
	_multi_mesh.use_custom_data = true
	_multi_mesh.instance_count = max_faces
	_multi_mesh.visible_instance_count = 0
	_multi_mesh.mesh = flag_mesh

	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _multi_mesh
	_mmi.material_override = _material
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)

	_transforms.resize(max_faces)
	_custom_data.resize(max_faces)


## Place a flag on a face.
func add_flag(face_id: int, center: Vector3, normal: Vector3) -> void:
	if _face_to_idx.has(face_id):
		return

	var idx := _active_count
	_active_count += 1
	_multi_mesh.visible_instance_count = _active_count

	_face_to_idx[face_id] = idx
	_idx_to_face[idx] = face_id

	var t := Transform3D()
	t = t.scaled(Vector3(_flag_size, _flag_size, _flag_size))
	t.origin = center + normal * 0.06
	_transforms[idx] = t
	_multi_mesh.set_instance_transform(idx, t)

	_multi_mesh.set_instance_color(idx, Color.WHITE)

	var encoded_normal := Color(
		(normal.x + 1.0) / 2.0,
		(normal.y + 1.0) / 2.0,
		(normal.z + 1.0) / 2.0,
		1.0,
	)
	_custom_data[idx] = encoded_normal
	_multi_mesh.set_instance_custom_data(idx, encoded_normal)


## Remove a flag from a face.
func remove_flag(face_id: int) -> void:
	if not _face_to_idx.has(face_id):
		return

	var idx: int = _face_to_idx[face_id]
	var last_idx := _active_count - 1

	if idx != last_idx:
		var last_face: int = _idx_to_face[last_idx]

		_multi_mesh.set_instance_transform(idx, _transforms[last_idx])
		_multi_mesh.set_instance_color(idx, Color.WHITE)
		_multi_mesh.set_instance_custom_data(idx, _custom_data[last_idx])

		_transforms[idx] = _transforms[last_idx]
		_custom_data[idx] = _custom_data[last_idx]

		_face_to_idx[last_face] = idx
		_idx_to_face[idx] = last_face

	_face_to_idx.erase(face_id)
	_idx_to_face.erase(last_idx)

	_active_count -= 1
	_multi_mesh.visible_instance_count = _active_count


## Remove all flags (game restart).
func clear_all() -> void:
	_active_count = 0
	_face_to_idx.clear()
	_idx_to_face.clear()
	if _multi_mesh:
		_multi_mesh.visible_instance_count = 0


func _process(_delta: float) -> void:
	if _camera and _material:
		var cambasis := _camera.global_transform.basis
		_material.set_shader_parameter("camera_right", cambasis.x)


# Local coordinates: Y = up (face normal in shader), X = right (faces camera).
# Pole: thin box Y=0..pole_height (vertex color R=0).
# Cloth: single quad from pole top (vertex color R=1), cull_disabled renders both sides.
func _create_flag_mesh() -> ArrayMesh:
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()

	var pw := 0.06    # pole half-width
	var ph := 1.2     # pole height

	var fw := 0.55    # flag width (extends in +X from pole)
	var fh := 0.35    # flag height (hangs down from top)
	var ft := ph      # flag top Y

	_add_quad(verts, normals, colors, indices,
		Vector3(-pw, 0, pw), Vector3(pw, 0, pw),
		Vector3(pw, ph, pw), Vector3(-pw, ph, pw),
		Vector3(0, 0, 1), Color(0, 0, 0))

	_add_quad(verts, normals, colors, indices,
		Vector3(pw, 0, -pw), Vector3(-pw, 0, -pw),
		Vector3(-pw, ph, -pw), Vector3(pw, ph, -pw),
		Vector3(0, 0, -1), Color(0, 0, 0))

	_add_quad(verts, normals, colors, indices,
		Vector3(pw, 0, pw), Vector3(pw, 0, -pw),
		Vector3(pw, ph, -pw), Vector3(pw, ph, pw),
		Vector3(1, 0, 0), Color(0, 0, 0))

	_add_quad(verts, normals, colors, indices,
		Vector3(-pw, 0, -pw), Vector3(-pw, 0, pw),
		Vector3(-pw, ph, pw), Vector3(-pw, ph, -pw),
		Vector3(-1, 0, 0), Color(0, 0, 0))

	# Cloth is a single quad; cull_disabled in the shader handles both sides.
	_add_quad(verts, normals, colors, indices,
		Vector3(pw, ft, 0.0), Vector3(pw + fw, ft, 0.0),
		Vector3(pw + fw, ft - fh, 0.0), Vector3(pw, ft - fh, 0.0),
		Vector3(0, 0, 1), Color(1, 0, 0))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_INDEX]  = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _add_quad(verts: PackedVector3Array, normals: PackedVector3Array,
					  colors: PackedColorArray, indices: PackedInt32Array,
					  a: Vector3, b: Vector3, c: Vector3, d: Vector3,
					  normal: Vector3, color: Color) -> void:
	var base := verts.size()
	verts.append(a); verts.append(b); verts.append(c); verts.append(d)
	for _i in 4:
		normals.append(normal)
		colors.append(color)
	indices.append(base);     indices.append(base + 1); indices.append(base + 2)
	indices.append(base);     indices.append(base + 2); indices.append(base + 3)
