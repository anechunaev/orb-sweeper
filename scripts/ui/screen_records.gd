## Records screen controller.
##
## Expected scene tree:
## [codeblock]
## RecordsScreen         (this script)
## ├─ TabContainer
## │   ├─ Classic         (VBoxContainer or similar)
## │   ├─ No Guess        (VBoxContainer or similar)
## │   └─ Custom          (VBoxContainer)
## │       ├─ SortBar     (HBoxContainer)
## │       │   ├─ SortByOption   (OptionButton)
## │       │   └─ SortDirOption  (OptionButton)
## │       └─ CustomList  (VBoxContainer — cards go here)
## [/codeblock]
class_name RecordsScreen
extends Control

const CLASSIC_DIFFICULTIES := DifficultyPresets.CLASSIC

@export var classic_container: VBoxContainer
@export var no_guess_container: VBoxContainer
@export var custom_list: VBoxContainer
@export var sort_by_option: OptionButton
@export var sort_dir_option: OptionButton

@onready var _record_card_scene: PackedScene = preload("res://nodes/record_card.tscn")

enum SortField { DENSITY, TIME, DATE }
enum SortDir   { ASCENDING, DESCENDING }

var _custom_entries: Array[Dictionary] = []
var _current_sort_field: SortField = SortField.TIME
var _current_sort_dir: SortDir = SortDir.ASCENDING

func _ready() -> void:
	_setup_sort_controls()
	refresh()


func _on_visibility_changed() -> void:
	if visible:
		refresh()


## Reload records from RecordsManager and rebuild all tabs.
func refresh() -> void:
	var records: Dictionary = RecordsManager.load_records()
	_build_classic_tab(records)
	_build_no_guess_tab(records)
	_build_custom_tab(records)

func _setup_sort_controls() -> void:
	sort_by_option.clear()
	sort_by_option.add_item("Time", SortField.TIME)
	sort_by_option.add_item("Difficulty", SortField.DENSITY)
	sort_by_option.add_item("Date", SortField.DATE)
	sort_by_option.selected = 0

	sort_dir_option.clear()
	sort_dir_option.add_item("Ascending", SortDir.ASCENDING)
	sort_dir_option.add_item("Descending", SortDir.DESCENDING)
	sort_dir_option.selected = 0

	sort_by_option.item_selected.connect(_on_sort_changed)
	sort_dir_option.item_selected.connect(_on_sort_changed)


func _on_sort_changed(_index: int) -> void:
	_current_sort_field = sort_by_option.get_selected_id() as SortField
	_current_sort_dir = sort_dir_option.get_selected_id() as SortDir
	_sort_and_display_custom()

func _build_classic_tab(records: Dictionary) -> void:
	_clear_container(classic_container)
	for diff: Dictionary in CLASSIC_DIFFICULTIES:
		_add_preset_card(classic_container, records, diff, false)


func _build_no_guess_tab(records: Dictionary) -> void:
	_clear_container(no_guess_container)
	for diff: Dictionary in CLASSIC_DIFFICULTIES:
		if diff["density"] < NoGuessGenerator.MAX_DENSITY:
			_add_preset_card(no_guess_container, records, diff, true)


func _add_preset_card(container: VBoxContainer, records: Dictionary,
		diff: Dictionary, no_guess: bool) -> void:
	var key := RecordsManager.get_key(diff["subdivision"], diff["density"], no_guess)
	var card := _record_card_scene.instantiate()
	container.add_child(card)

	if records.has(key):
		var rec: Dictionary = records[key]
		card.display_record(rec["time"], rec["date"],
			diff["subdivision"], diff["density"], no_guess)
	else:
		card.display_record(-1, "",
			diff["subdivision"], diff["density"], no_guess)


func _build_custom_tab(records: Dictionary) -> void:
	_custom_entries.clear()

	var classic_keys := {}
	for diff: Dictionary in CLASSIC_DIFFICULTIES:
		classic_keys[RecordsManager.get_key(diff["subdivision"], diff["density"], false)] = true
		classic_keys[RecordsManager.get_key(diff["subdivision"], diff["density"], true)] = true

	for key: String in records:
		if classic_keys.has(key):
			continue

		var no_guess := RecordsManager.is_no_guess_key(key)
		var core := key.trim_suffix("_ng") if no_guess else key
		var parts := core.split("_")
		if parts.size() < 2:
			continue

		var subdivision := parts[0].to_int()
		var density := parts[1].to_float()
		var rec: Dictionary = records[key]

		_custom_entries.append({
			"subdivision": subdivision,
			"density": density,
			"no_guess": no_guess,
			"time": rec["time"],
			"date": rec["date"],
		})

	_sort_and_display_custom()


func _sort_and_display_custom() -> void:
	_custom_entries.sort_custom(_compare_entries)
	_clear_container(custom_list)

	for entry: Dictionary in _custom_entries:
		var card := _record_card_scene.instantiate()
		custom_list.add_child(card)
		card.display_record(entry["time"], entry["date"],
			entry["subdivision"], entry["density"], entry.get("no_guess", false))


func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var val_a: Variant
	var val_b: Variant

	match _current_sort_field:
		SortField.DENSITY:
			val_a = a["density"]
			val_b = b["density"]
		SortField.TIME:
			val_a = a["time"]
			val_b = b["time"]
		SortField.DATE:
			val_a = a["date"]
			val_b = b["date"]

	if _current_sort_dir == SortDir.ASCENDING:
		return val_a < val_b
	else:
		return val_a > val_b

static func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()
