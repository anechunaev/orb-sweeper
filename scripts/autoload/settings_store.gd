## Thin wrapper around [ConfigFile] for persistent user settings. Other
## manager autoloads (audio, haptics, background, game config) read and write
## their own sections through this singleton and call [method save] after
## mutations.
extends Node

const SETTINGS_PATH := "user://settings.cfg"

var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	_config.load(SETTINGS_PATH)


## Read [param key] from [param section], returning [param default] if missing.
func get_value(section: String, key: String, default):
	return _config.get_value(section, key, default)


## Write [param value] to [param section]/[param key]. Not persisted until
## [method save] is called.
func set_value(section: String, key: String, value) -> void:
	_config.set_value(section, key, value)


## Flush all buffered writes to disk.
func save() -> void:
	_config.save(SETTINGS_PATH)
