## A single row card displaying one record entry in the records screen.
class_name RecordCard
extends Control

@export var difficulty_label: Label
@export var time_label: Label
@export var dif_key_label: Label
@export var date_label: Label

## Populate the card from a stored record. Pass [code]time = -1[/code] and
## [code]date = ""[/code] for "no record yet" rows.
func display_record(time: int, date: String, subdivision: int, ratio: float, no_guess: bool = false) -> void:
	difficulty_label.text = DifficultyPresets.get_difficulty_name(ratio)
	if no_guess:
		difficulty_label.text += " · No Guess"
	time_label.text = TimeFormatter.format_time(time)
	dif_key_label.text = _get_difficulty_key(subdivision, ratio)
	date_label.text = date if date != "" else "---"


func _get_difficulty_key(subdivision: int, ratio: float) -> String:
	var rat_str = "d=" + str(int(ratio * 100)) + "%"
	var sbd_str = "s=" + str(subdivision)
	return rat_str + " " + sbd_str
