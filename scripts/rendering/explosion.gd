## One-shot explosion FX node: kicks off every attached GPUParticles3D and
## fades the point light, then frees itself when [member timer] expires.
class_name Explosion
extends Node3D

@export var particles: Array[GPUParticles3D]
@export var explode_on_init: bool = false
@export var explosion_light: OmniLight3D
@export var timer: Timer

## Start emitting particles and begin the self-destruct timer.
func explode() -> void:
	timer.start()
	if particles && particles.size() > 0:
		for ps in particles:
			ps.emitting = true

func _ready() -> void:
	timer.timeout.connect(_done)
	if explode_on_init:
		explode()

func _done() -> void:
	queue_free()

func _process(delta: float) -> void:
	if explosion_light && explosion_light.light_energy > 0:
		explosion_light.light_energy -= delta * 10 * 2
		if explosion_light.light_energy < 0:
			explosion_light.light_energy = 0
