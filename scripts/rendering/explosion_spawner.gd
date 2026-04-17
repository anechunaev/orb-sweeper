## Spawns mine-detonation FX (explosion particles + blast decal) at a
## requested position on the sphere. Keeps a handle to the most recent blast
## decal so it can be cleared on restart or exit.
class_name ExplosionSpawner
extends Node

const EXPLOSION_SCENE := preload("res://nodes/explosion.tscn")
const BLAST_DECAL_SCENE := preload("res://nodes/blast.tscn")

var _blast_decal: Node3D


## Spawn explosion FX at [param pos] oriented along [param norm]. The
## accompanying blast decal persists until [method clear] is called, replacing
## any previous decal from an earlier detonation.
func spawn(pos: Vector3, norm: Vector3) -> void:
	var up := norm.normalized()
	var tangent: Vector3 = Vector3.RIGHT if abs(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var right := tangent.cross(up).normalized()
	var forward := up.cross(right).normalized()
	var obj_basis := Basis(right, up, forward)
	var t := Transform3D(obj_basis, pos - norm * 0.01)

	var explosion := EXPLOSION_SCENE.instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_transform = t

	clear()
	_blast_decal = BLAST_DECAL_SCENE.instantiate()
	get_tree().current_scene.add_child(_blast_decal)
	_blast_decal.global_transform = t


## Remove any leftover blast decal from a previous detonation.
func clear() -> void:
	if _blast_decal and is_instance_valid(_blast_decal):
		_blast_decal.queue_free()
		_blast_decal = null
