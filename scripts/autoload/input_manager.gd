## Holds the user's input/control preferences: the one-finger-zoom toggle and
## its direction flip (see [OrbitCamera] for the gesture itself), plus a
## rotation-sensitivity multiplier applied to orbit drag.
extends Node

var one_finger_zoom_enabled: bool = false
var reverse_zoom_direction: bool = false
var rotation_sensitivity: float = 1.0


func _ready() -> void:
	one_finger_zoom_enabled = SettingsStore.get_value(
		"input", "one_finger_zoom_enabled", one_finger_zoom_enabled)
	reverse_zoom_direction = SettingsStore.get_value(
		"input", "reverse_zoom_direction", reverse_zoom_direction)
	rotation_sensitivity = SettingsStore.get_value(
		"input", "rotation_sensitivity", rotation_sensitivity)


## Persist the current preferences to [SettingsStore].
func save() -> void:
	SettingsStore.set_value("input", "one_finger_zoom_enabled", one_finger_zoom_enabled)
	SettingsStore.set_value("input", "reverse_zoom_direction", reverse_zoom_direction)
	SettingsStore.set_value("input", "rotation_sensitivity", rotation_sensitivity)
	SettingsStore.save()
