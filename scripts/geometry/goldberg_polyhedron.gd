## Generates a Goldberg polyhedron as an [ArrayMesh] with face adjacency data.
##
## A Goldberg polyhedron is the dual of a geodesic sphere built from an
## icosahedron. It produces a tiling of [b]hexagons[/b] with exactly
## [b]12 pentagons[/b] — perfect for spherical Minesweeper.
##
## Usage:
## [codeblock]
## var result := GoldbergPolyhedron.generate(3, 2.0)
## $MeshInstance3D.mesh = result.mesh
## result.set_face_color(0, Color.RED)   # paint one cell
## var neighbors = result.adjacency[0]   # int array of neighbor face indices
## [/codeblock]
class_name GoldbergPolyhedron


class Result extends RefCounted:
	## The renderable mesh (one surface, PRIMITIVE_TRIANGLES, flat-shaded).
	var mesh: ArrayMesh
	## World-space center of every face, lying on the sphere surface.
	var face_centers: PackedVector3Array
	## adjacency[i] → Array of face indices neighbouring face i.
	var adjacency: Array            # Array[Array[int]]
	## Number of edges per face (5 = pentagon, 6 = hexagon).
	var face_sides: PackedInt32Array
	## Total face count  (= 10 * subdivision² + 2).
	var face_count: int

	# -- internal bookkeeping for fast recoloring --
	var _surface_arrays: Array
	var _face_vert_offsets: PackedInt32Array   # face i starts at vertex index [i]


## Approximate edge length for a face at the given subdivision level.
static func approx_face_edge(sphere_radius: float, subdivision: int) -> float:
	return sphere_radius * 2.0 / (float(subdivision) * sqrt(3.0))


## Total face count for a Goldberg polyhedron: [code]10 * s² + 2[/code].
static func face_count(subdivision: int) -> int:
	return 10 * subdivision * subdivision + 2


## Generate a Goldberg polyhedron GP([param subdivision], 0).
## [br][br]
## [param subdivision] — frequency (≥ 1).  1 → dodecahedron (12 faces),
## 2 → 42 faces, 3 → 92 faces, etc.
## [br]
## [param radius] — sphere radius in world units.
static func generate(subdivision: int = 2, radius: float = 1.0) -> Result:
	subdivision = maxi(subdivision, 1)

	# 1. Build the geodesic sphere (subdivided icosahedron)
	var geo := _build_geodesic(subdivision, radius)
	var geo_verts: PackedVector3Array  = geo["vertices"]
	var geo_tris:  PackedInt32Array    = geo["triangles"]

	# 2. Compute the dual → Goldberg polyhedron
	return _build_dual(geo_verts, geo_tris, radius)


static func _ico_vertices() -> PackedVector3Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	return PackedVector3Array([
		Vector3(-1,  t,  0), Vector3( 1,  t,  0),
		Vector3(-1, -t,  0), Vector3( 1, -t,  0),
		Vector3( 0, -1,  t), Vector3( 0,  1,  t),
		Vector3( 0, -1, -t), Vector3( 0,  1, -t),
		Vector3( t,  0, -1), Vector3( t,  0,  1),
		Vector3(-t,  0, -1), Vector3(-t,  0,  1),
	])


static func _ico_faces() -> Array:
	# 20 triangles, CCW winding from outside
	return [
		Vector3i(0,11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7),
		Vector3i(0, 7,10), Vector3i(0,10,11),
		Vector3i(1, 5, 9), Vector3i(5,11, 4), Vector3i(11,10,2),
		Vector3i(10,7, 6), Vector3i(7, 1, 8),
		Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6),
		Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4,11), Vector3i(6, 2,10),
		Vector3i(8, 6, 7), Vector3i(9, 8, 1),
	]


## Subdivide each icosahedron face into m² triangles, project onto sphere.
static func _build_geodesic(m: int, radius: float) -> Dictionary:
	var ico_v := _ico_vertices()
	for i in ico_v.size():
		ico_v[i] = ico_v[i].normalized()

	var ico_f := _ico_faces()

	var vertices  := PackedVector3Array()
	var triangles := PackedInt32Array()
	# Deduplicate shared edge / corner vertices using snapped position keys.
	var vert_map := {}          # Vector3i → global vertex index

	for fi in ico_f.size():
		var face: Vector3i = ico_f[fi]
		var va: Vector3 = ico_v[face.x]
		var vb: Vector3 = ico_v[face.y]
		var vc: Vector3 = ico_v[face.z]

		var grid: Array = []
		for i in range(m + 1):
			var row := PackedInt32Array()
			for j in range(m + 1 - i):
				var k := m - i - j
				var pos: Vector3 = (float(i) * va + float(j) * vb + float(k) * vc) / float(m)
				pos = pos.normalized() * radius

				var snap := Vector3i(
					roundi(pos.x * 100000.0),
					roundi(pos.y * 100000.0),
					roundi(pos.z * 100000.0),
				)

				if vert_map.has(snap):
					row.append(vert_map[snap])
				else:
					var idx := vertices.size()
					vertices.append(pos)
					vert_map[snap] = idx
					row.append(idx)
			grid.append(row)

		# Emit triangles
		for i in range(m):
			for j in range(m - i):
				# "Upward" triangle
				triangles.append(grid[i][j])
				triangles.append(grid[i + 1][j])
				triangles.append(grid[i][j + 1])
				# "Downward" triangle (exists when not at the diagonal edge)
				if i + j < m - 1:
					triangles.append(grid[i + 1][j])
					triangles.append(grid[i + 1][j + 1])
					triangles.append(grid[i][j + 1])

	return { "vertices": vertices, "triangles": triangles }


static func _build_dual(geo_verts: PackedVector3Array,
						geo_tris: PackedInt32Array,
						radius: float) -> Result:
	var tri_count  := roundi(float(geo_tris.size()) / 3)
	var vert_count := geo_verts.size()

	# --- triangle centroids, projected onto sphere ---
	var centroids := PackedVector3Array()
	centroids.resize(tri_count)
	for ti in tri_count:
		var a := geo_verts[geo_tris[ti * 3]]
		var b := geo_verts[geo_tris[ti * 3 + 1]]
		var c := geo_verts[geo_tris[ti * 3 + 2]]
		centroids[ti] = ((a + b + c) / 3.0).normalized() * radius

	# --- vertex → triangle adjacency ---
	var vert_tris: Array = []
	vert_tris.resize(vert_count)
	for v in vert_count:
		vert_tris[v] = []
	for ti in tri_count:
		for k in 3:
			(vert_tris[geo_tris[ti * 3 + k]] as Array).append(ti)

	# --- edge set → face adjacency ---
	var edge_set := {}
	for ti in tri_count:
		for k in 3:
			var v0 := geo_tris[ti * 3 + k]
			var v1 := geo_tris[ti * 3 + (k + 1) % 3]
			edge_set[Vector2i(mini(v0, v1), maxi(v0, v1))] = true

	var adjacency: Array = []
	adjacency.resize(vert_count)
	for v in vert_count:
		adjacency[v] = []       # regular Array = reference type, safe to append
	for key: Vector2i in edge_set:
		(adjacency[key.x] as Array).append(key.y)
		(adjacency[key.y] as Array).append(key.x)

	# --- sort triangles around each vertex in cyclic order ---
	var sorted_rings: Array = []
	sorted_rings.resize(vert_count)
	for v in vert_count:
		sorted_rings[v] = _sort_ring(v, vert_tris[v], geo_tris)

	# --- face metadata ---
	var face_sides := PackedInt32Array()
	face_sides.resize(vert_count)
	for v in vert_count:
		face_sides[v] = (vert_tris[v] as Array).size()

	# --- build renderable mesh ---
	var mesh_data := _build_mesh(sorted_rings, centroids, geo_verts, radius, vert_count)

	var result        := Result.new()
	result.mesh       = mesh_data["mesh"]
	result.face_centers = geo_verts.duplicate()     # original vertices = face centers
	result.adjacency  = adjacency
	result.face_sides = face_sides
	result.face_count = vert_count
	result._surface_arrays    = mesh_data["arrays"]
	result._face_vert_offsets = mesh_data["offsets"]
	return result


static func _sort_ring(v: int, tri_list: Array, geo_tris: PackedInt32Array) -> PackedInt32Array:
	var n := tri_list.size()
	if n <= 1:
		return PackedInt32Array(tri_list)

	# For each triangle find the two vertices that are not v.
	var others := {}       # tri_index → [u1, u2]
	for ti: int in tri_list:
		var pair := PackedInt32Array()
		for k in 3:
			var vi := geo_tris[ti * 3 + k]
			if vi != v:
				pair.append(vi)
		others[ti] = pair

	# Map: shared_vertex → list of triangles touching edge (v, shared_vertex)
	var edge_tris := {}
	for ti: int in tri_list:
		for u: int in others[ti]:
			if not edge_tris.has(u):
				edge_tris[u] = []
			(edge_tris[u] as Array).append(ti)

	# Walk the fan: start at tri_list[0], follow edge connectivity
	var sorted := PackedInt32Array()
	sorted.append(tri_list[0])
	var current: int  = tri_list[0]
	var next_u: int   = (others[current] as PackedInt32Array)[1]

	for _step in range(n - 1):
		var found := false
		for t: int in edge_tris[next_u]:
			if t != current:
				sorted.append(t)
				current = t
				var pair: PackedInt32Array = others[current]
				next_u = pair[1] if pair[0] == next_u else pair[0]
				found = true
				break
		if not found:
			break            # shouldn't happen on a closed manifold

	return sorted


static func _build_mesh(sorted_rings: Array,
						centroids: PackedVector3Array,
						face_centers: PackedVector3Array,
						_radius: float,
						faces_count: int) -> Dictionary:
	var verts    := PackedVector3Array()
	var norms    := PackedVector3Array()
	var tangents := PackedFloat32Array()  # per-vertex 4 floats: tangent.xyz, sign
	var colors   := PackedColorArray()    # COLOR.r = ring_radius (in-plane corner distance)
	var uvs      := PackedVector2Array()
	var uv2s     := PackedVector2Array()  # (azimuth 0..1, n_sides)
	var indices  := PackedInt32Array()
	var offsets  := PackedInt32Array()    # face_vert_offsets

	for fi in faces_count:
		offsets.append(verts.size())
		var ring: PackedInt32Array = sorted_rings[fi]
		var n_sides := ring.size()
		var normal  := face_centers[fi].normalized()
		var center  := face_centers[fi]
		var uv_x    := (float(fi) + 0.5) / float(faces_count)  # texel center

		# Polygon vertices = centroids of surrounding triangles
		var poly := PackedVector3Array()
		poly.resize(n_sides)
		for i in n_sides:
			poly[i] = centroids[ring[i]]

		# Ensure CCW winding when viewed from outside
		if n_sides >= 3:
			var cross := (poly[1] - poly[0]).cross(poly[2] - poly[0])
			if cross.dot(normal) < 0.0:
				poly.reverse()

		# Per-face tangent basis: direction from face_center to ring[0], projected
		# onto the face's tangent plane. Shader uses this to build face-local polar
		# coords so rivet placement is C¹ continuous across fan triangles.
		var to_first := poly[0] - center
		var tangent_in_plane := to_first - normal * to_first.dot(normal)
		var ring_radius := tangent_in_plane.length()
		var tangent_dir := tangent_in_plane / ring_radius if ring_radius > 0.0 else Vector3.RIGHT
		var face_color := Color(ring_radius, 0.0, 0.0, 1.0)

		var ci := verts.size()
		verts.append(center)
		norms.append(normal)
		tangents.append_array([tangent_dir.x, tangent_dir.y, tangent_dir.z, 1.0])
		colors.append(face_color)
		uvs.append(Vector2(uv_x, 0.5))
		uv2s.append(Vector2(0.0, float(n_sides)))

		# Ring vertices — emit n_sides + 1 so UV2.x can wrap monotonically
		# 0 → 1 around the face (last vertex duplicates the first position).
		for i in n_sides + 1:
			verts.append(poly[i % n_sides])
			norms.append(normal)
			tangents.append_array([tangent_dir.x, tangent_dir.y, tangent_dir.z, 1.0])
			colors.append(face_color)
			uvs.append(Vector2(uv_x, 0.0))
			uv2s.append(Vector2(float(i) / float(n_sides), float(n_sides)))

		for i in n_sides:
			indices.append(ci)
			indices.append(ci + 1 + i + 1)
			indices.append(ci + 1 + i)

	# Final sentinel so offset look-ups work for the last face
	offsets.append(verts.size())

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]   = verts
	arrays[Mesh.ARRAY_NORMAL]   = norms
	arrays[Mesh.ARRAY_TANGENT]  = tangents
	arrays[Mesh.ARRAY_COLOR]    = colors
	arrays[Mesh.ARRAY_TEX_UV]   = uvs
	arrays[Mesh.ARRAY_TEX_UV2]  = uv2s
	arrays[Mesh.ARRAY_INDEX]    = indices

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return { "mesh": arr_mesh, "arrays": arrays, "offsets": offsets }
