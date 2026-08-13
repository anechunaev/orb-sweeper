## A single row card displaying one record entry in the records screen.
class_name RecordCard
extends Control

@export var difficulty_label: Label
@export var time_label: Label
@export var dif_key_label: Label
@export var date_label: Label
@export var efficiency_label: Label

## Populate the card from a stored record dictionary as written by
## [RecordsManager] — [code]{time, efficiency, date, best_efficiency,
## best_efficiency_date}[/code]. Pass an empty dictionary for "no record yet"
## rows; records saved before efficiency tracking simply omit those fields.
func display_record(record: Dictionary, subdivision: int, ratio: float, no_guess: bool = false) -> void:
	difficulty_label.text = DifficultyPresets.get_difficulty_name(ratio)
	if no_guess:
		difficulty_label.text += " · No Guess"

	var time: int = record.get("time", -1)
	var run_efficiency: float = record.get("efficiency", -1.0)
	time_label.text = TimeFormatter.format_time(time)
	if run_efficiency > 0.0:
		time_label.text += " · " + EfficiencyFormatter.format_efficiency(run_efficiency)

	dif_key_label.text = _get_difficulty_key(subdivision, ratio)
	var date: String = record.get("date", "")
	date_label.text = date if date != "" else "---"

	var best_efficiency: float = record.get("best_efficiency", -1.0)
	efficiency_label.text = EfficiencyFormatter.format_efficiency(best_efficiency)
	var best_efficiency_date: String = record.get("best_efficiency_date", "")
	if best_efficiency > 0.0 and best_efficiency_date != "":
		efficiency_label.text += " · " + best_efficiency_date


func _get_difficulty_key(subdivision: int, ratio: float) -> String:
	var rat_str = "d=" + str(int(ratio * 100)) + "%"
	var sbd_str = "s=" + str(subdivision)
	return rat_str + " " + sbd_str
