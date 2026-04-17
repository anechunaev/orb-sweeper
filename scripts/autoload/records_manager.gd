## Autoload that persists best-time records to [code]user://records.json[/code].
## Records are keyed by subdivision + density + no-guess flag so classic and
## no-guess runs on the same difficulty are tracked separately.
extends Node

const SAVE_PATH := "user://records.json"

var records: Dictionary = {}


func _init():
	load_records()


## Build the lookup key used for records storage. Appends [code]_ng[/code]
## when [param no_guess] is true so classic/no-guess scores never collide.
func get_key(subdivision: int, density: float, no_guess: bool = false) -> String:
	var suffix := "_ng" if no_guess else ""
	return "%d_%.2f%s" % [subdivision, density, suffix]


## True iff [param key] was produced with no_guess=true.
func is_no_guess_key(key: String) -> bool:
	return key.ends_with("_ng")


## Flush the in-memory records dictionary to disk.
func save_records() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(records))


## Load records from disk into [member records] and return the dictionary.
## Returns an empty dictionary (and resets [member records]) if the file is
## missing or unreadable.
func load_records() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		records = {}
		return records

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		records = {}
		return records
	var content = file.get_as_text()
	var parsed = JSON.parse_string(content)

	if typeof(parsed) == TYPE_DICTIONARY:
		records = parsed
	else:
		records = {}

	return records


## Store [param new_time] as the best record for the given difficulty if it
## beats the current record (or no record exists yet). Persists on write.
func update_record(subdivision: int, density: float, new_time: int, no_guess: bool = false) -> void:
	var key = get_key(subdivision, density, no_guess)

	if not records.has(key) or new_time < records[key]["time"]:
		records[key] = {
			"time": new_time,
			"date": _get_now_string()
		}
		save_records()


## Return the stored record dictionary ([code]{time, date}[/code]) for the
## given difficulty, or an empty dictionary if none exists.
func get_record(subdivision: int, density: float, no_guess: bool = false) -> Dictionary:
	var key = get_key(subdivision, density, no_guess)

	if records.has(key):
		return records[key]

	return {}


## Return the best time (in microseconds) for the given difficulty, or
## [code]-1[/code] if no record is stored yet.
func get_best_time(subdivision: int, density: float, no_guess: bool = false) -> int:
	var record = get_record(subdivision, density, no_guess)
	if record.has("time"):
		return record["time"]
	return -1


func _get_now_string() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second
	]
