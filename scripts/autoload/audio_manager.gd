## Owns the user's audio bus volume preferences (Master and Music) and
## applies them to the [AudioServer]. Persists through [SettingsStore].
extends Node

var master_volume: float = 1.0
var music_volume: float = 1.0


func _ready() -> void:
	master_volume = SettingsStore.get_value("audio", "master_volume", master_volume)
	music_volume = SettingsStore.get_value("audio", "music_volume", music_volume)
	apply()


## Push current volumes to the audio server. Call after mutating
## [member master_volume] or [member music_volume].
func apply() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)


## Persist the current volumes to [SettingsStore].
func save() -> void:
	SettingsStore.set_value("audio", "master_volume", master_volume)
	SettingsStore.set_value("audio", "music_volume", music_volume)
	SettingsStore.save()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.0001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
