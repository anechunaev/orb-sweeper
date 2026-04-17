## Decorative Goldberg sphere rendered behind the main menu. Builds its own
## mesh on ready and spins slowly each frame.
class_name MenuSphere
extends MeshInstance3D

@export_range(1, 10) var subdivision: int = 3
## Rotation speed in radians per second.
@export var spin_speed: float = 0.033
@export var shader: Shader

var _manager: GoldbergCellManager


func _ready() -> void:
	var result := GoldbergPolyhedron.generate(subdivision, subdivision * 2.0)
	mesh = result.mesh
	_manager = GoldbergCellManager.create(result, shader)
	material_override = _manager.material


func _process(delta: float) -> void:
	if _manager:
		_manager.process()
	rotate_y(spin_speed * delta)
