## Holds the user's input/control preferences. Currently just the
## one-finger-zoom toggle, which lets a held second tap drive zoom via vertical
## motion (off by default — see [OrbitCamera] for the gesture itself).
extends Node

var one_finger_zoom_enabled: bool = false


func _ready() -> void:
	one_finger_zoom_enabled = SettingsStore.get_value(
		"input", "one_finger_zoom_enabled", one_finger_zoom_enabled)


## Persist the current preference to [SettingsStore].
func save() -> void:
	SettingsStore.set_value("input", "one_finger_zoom_enabled", one_finger_zoom_enabled)
	SettingsStore.save()
