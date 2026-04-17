## Attaches a [StaticBody3D] with a [SphereShape3D] to a mesh instance so
## physics raycasts can hit the board. Idempotent: reuses any existing body
## and collision shape children on repeat calls.
class_name SphereColliderSetup


## Ensure [param mesh_instance] has a collision body sized for a sphere of
## [param radius]. The collider is slightly larger than the visual radius so
## raised tiles are still clickable.
static func attach(mesh_instance: MeshInstance3D, radius: float) -> void:
	var body: StaticBody3D
	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			body = child
			break

	if not body:
		body = StaticBody3D.new()
		mesh_instance.add_child(body)

	var col: CollisionShape3D
	for child in body.get_children():
		if child is CollisionShape3D:
			col = child
			break

	if not col:
		col = CollisionShape3D.new()
		body.add_child(col)

	var shape := SphereShape3D.new()
	shape.radius = radius * 1.06
	col.shape = shape
