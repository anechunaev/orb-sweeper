## Renders mine models on revealed mine faces using a single
## [MultiMeshInstance3D] draw call.
##
## Mines sit on the tile surface and rotate to face the camera,
## same orientation system as flags.
##
## [codeblock]
## var mine_renderer := MineRenderer.new()
## add_child(mine_renderer)
## mine_renderer.setup(camera, face_count, sphere_radius, subdivision, mine_shader)
##
## mine_renderer.show_mine(face_id, face_center, face_normal)
## mine_renderer.clear_all()
## [/codeblock]
class_name MineRenderer
extends Node3D

var _multi_mesh: MultiMesh
var _mmi: MultiMeshInstance3D
var _material: ShaderMaterial
var _camera: Camera3D

var _active_count: int = 0
var _mine_size: float = 0.1

var _outline: ShaderMaterial

## Initialise the renderer.
## [param mine_shader] — shader for the mine model.
## [param custom_mesh] — optional custom mesh.
## Model convention: Y = up (face normal), X = right (faces camera).
func setup(cam: Camera3D, max_faces: int, sphere_radius: float,
		   subdivision: int, mine_shader: Shader,
		   custom_mesh: Mesh = null, outline_shader: Shader = null) -> void:
	_camera = cam

	var edge_approx := GoldbergPolyhedron.approx_face_edge(sphere_radius, subdivision)
	_mine_size = edge_approx * 0.30

	_material = ShaderMaterial.new()
	_material.shader = mine_shader
	
	if outline_shader:
		_outline = ShaderMaterial.new()
		_outline.shader = outline_shader
		_material.next_pass = _outline

	var mine_mesh: Mesh = custom_mesh if custom_mesh else _create_mine_mesh()

	_multi_mesh = MultiMesh.new()
	_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_multi_mesh.use_colors = true
	_multi_mesh.use_custom_data = true
	_multi_mesh.instance_count = max_faces
	_multi_mesh.visible_instance_count = 0
	_multi_mesh.mesh = mine_mesh

	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _multi_mesh
	_mmi.material_override = _material
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)


## Show a mine model on a face.
func show_mine(_face_id: int, center: Vector3, normal: Vector3) -> void:
	var idx := _active_count
	_active_count += 1
	_multi_mesh.visible_instance_count = _active_count

	var t := Transform3D()
	t = t.scaled(Vector3(_mine_size, _mine_size, _mine_size))
	t.origin = center - normal * 0.03
	_multi_mesh.set_instance_transform(idx, t)

	_multi_mesh.set_instance_color(idx, Color.WHITE)

	var encoded_normal := Color(
		(normal.x + 1.0) / 2.0,
		(normal.y + 1.0) / 2.0,
		(normal.z + 1.0) / 2.0,
		1.0,
	)
	_multi_mesh.set_instance_custom_data(idx, encoded_normal)


## Remove all mine models (game restart).
func clear_all() -> void:
	_active_count = 0
	if _multi_mesh:
		_multi_mesh.visible_instance_count = 0


func _process(_delta: float) -> void:
	if _camera and _material:
		var cam_basis := _camera.global_transform.basis
		_material.set_shader_parameter("camera_right", cam_basis.x)
		if _outline:
			_outline.set_shader_parameter("camera_right", cam_basis.x)


# Local coordinates: Y = up (face normal in shader), X = right (faces camera).
# Body: UV sphere at Y=0.5. Spikes: cones along +/-X, +/-Y, +/-Z.
func _create_mine_mesh() -> ArrayMesh:
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var center := Vector3(0.0, 0.5, 0.0)
	var body_r := 0.35

	_add_sphere(verts, normals, indices, center, body_r, 12, 8)

	var spike_len := 0.2
	var spike_r   := 0.06
	var spike_dirs := [
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -1),
	]
	for dir: Vector3 in spike_dirs:
		var tip: Vector3 = center + dir * (body_r + spike_len)
		var base_pos: Vector3 = center + dir * (body_r * 0.7)
		_add_spike(verts, normals, indices, base_pos, tip, spike_r, dir)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX]  = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Add a UV sphere at [param c] with radius [param r].
static func _add_sphere(verts: PackedVector3Array, norms: PackedVector3Array,
						indices: PackedInt32Array, c: Vector3, r: float,
						segments: int, rings: int) -> void:
	var base := verts.size()

	for ring in range(rings + 1):
		var lat := PI * float(ring) / float(rings) - PI / 2.0
		var y  := sin(lat)
		var xz := cos(lat)
		for seg in range(segments + 1):
			var lon := TAU * float(seg) / float(segments)
			var n := Vector3(xz * cos(lon), y, xz * sin(lon))
			verts.append(c + n * r)
			norms.append(n)

	var cols := segments + 1
	for ring in range(rings):
		for seg in range(segments):
			var i0 := base + ring * cols + seg
			var i1 := i0 + 1
			var i2 := i0 + cols
			var i3 := i2 + 1
			indices.append(i0); indices.append(i2); indices.append(i1)
			indices.append(i1); indices.append(i2); indices.append(i3)


## Add a cone/spike from [param base_pos] to [param tip].
static func _add_spike(verts: PackedVector3Array, norms: PackedVector3Array,
					   indices: PackedInt32Array, base_pos: Vector3,
					   tip: Vector3, r: float, axis: Vector3) -> void:
	var base := verts.size()
	var segs := 6

	# Build tangent frame for the base circle
	var up := axis
	var perp := Vector3(0, 1, 0) if absf(up.y) < 0.9 else Vector3(1, 0, 0)
	var right := up.cross(perp).normalized()
	var forward := up.cross(right).normalized()

	for i in segs:
		var angle := TAU * float(i) / float(segs)
		var offset := (right * cos(angle) + forward * sin(angle)) * r
		var p := base_pos + offset
		var n := offset.normalized()
		verts.append(p)
		norms.append(n)

	verts.append(tip)
	norms.append(axis)

	var tip_idx := base + segs
	for i in segs:
		indices.append(base + i)
		indices.append(base + (i + 1) % segs)
		indices.append(tip_idx)
