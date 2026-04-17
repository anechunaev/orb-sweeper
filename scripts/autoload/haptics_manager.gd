## Wraps the platform vibration API and holds the user's haptics preference.
## All gameplay vibration calls flow through here so the preference is always
## respected.
extends Node

var vibration_enabled: bool = true


func _ready() -> void:
	vibration_enabled = SettingsStore.get_value(
		"haptics", "vibration_enabled", vibration_enabled)


## Vibrate the device for [param duration_ms] milliseconds. No-op if
## [member vibration_enabled] is false or the device has no vibrator.
func vibrate(duration_ms: int) -> void:
	if vibration_enabled:
		Input.vibrate_handheld(duration_ms)


## Play a descending "game-over" vibration pattern: four pulses of decreasing
## length, scheduled via scene-tree timers so they don't block the caller.
func vibrate_descending() -> void:
	var durations := [150, 100, 60, 30]
	var delay := 0.0
	for i in durations.size():
		get_tree().create_timer(delay).timeout.connect(vibrate.bind(durations[i]))
		delay += (durations[i] / 1000.0) + 0.08


## Persist the current preference to [SettingsStore].
func save() -> void:
	SettingsStore.set_value("haptics", "vibration_enabled", vibration_enabled)
	SettingsStore.save()
