## Autoload that persists best-time and best-efficiency records to
## [code]user://records.json[/code]. Records are keyed by subdivision + density
## + no-guess flag so classic and no-guess runs on the same difficulty are
## tracked separately.
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


## Store a finished run under the given difficulty. Best time and best
## efficiency are tracked as independent personal bests, so a slow but tidy run
## can hold the efficiency record while a fast sloppy one holds the time.
## [param efficiency] is a percentage; pass [code]0.0[/code] when unknown.
## Persists only when something actually improved.
func update_record(subdivision: int, density: float, new_time: int,
		no_guess: bool = false, efficiency: float = 0.0) -> void:
	var key = get_key(subdivision, density, no_guess)
	var now = _get_now_string()
	var record: Dictionary = records.get(key, {})
	var dirty := false

	if not record.has("time") or new_time < record["time"]:
		record["time"] = new_time
		record["efficiency"] = efficiency
		record["date"] = now
		dirty = true

	if efficiency > 0.0 and efficiency > record.get("best_efficiency", 0.0):
		record["best_efficiency"] = efficiency
		record["best_efficiency_time"] = new_time
		record["best_efficiency_date"] = now
		dirty = true

	if dirty:
		records[key] = record
		save_records()


## Return the stored record dictionary for the given difficulty, or an empty
## dictionary if none exists. Entries written before efficiency tracking carry
## only [code]{time, date}[/code], so always read the efficiency fields with a
## default.
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


## Return the best efficiency (percentage) for the given difficulty, or
## [code]-1.0[/code] if none is stored yet.
func get_best_efficiency(subdivision: int, density: float, no_guess: bool = false) -> float:
	var record = get_record(subdivision, density, no_guess)
	return record.get("best_efficiency", -1.0)


## Return the efficiency achieved during the best-*time* run, or
## [code]-1.0[/code] if none is stored yet.
func get_record_efficiency(subdivision: int, density: float, no_guess: bool = false) -> float:
	var record = get_record(subdivision, density, no_guess)
	return record.get("efficiency", -1.0)


func _get_now_string() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second
	]
