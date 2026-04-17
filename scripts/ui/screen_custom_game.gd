## "Custom game" screen: size and density sliders with a live difficulty readout.
class_name ScreenCustomGame
extends Control

@export var tiles_count_label: Label
@export var mines_density_percent_label: Label
@export var mines_count_label: Label
@export var difficulty_label: Label
@export var size_slider: HSlider
@export var density_slider: HSlider
@export var no_guess_check: CheckButton
@export var no_guess_hint_label: Label

@onready var game_scene = preload("res://scenes/game.tscn")

var _size: int = 3
var _cells_count: int = 92
var _density: float = 0.15
var _no_guess: bool = false


func _ready():
	_size = GameConfig.subdivision
	_density = GameConfig.density
	_no_guess = GameConfig.no_guess_mode
	size_slider.value = _size
	density_slider.value = _density
	no_guess_check.button_pressed = _no_guess
	_set_labels_text()
	_refresh_no_guess_availability()


func _set_labels_text() -> void:
	_cells_count = GoldbergPolyhedron.face_count(_size)
	tiles_count_label.text = str(_cells_count) + " tiles"
	mines_density_percent_label.text = str(_density * 100) + "%"
	mines_count_label.text = str(roundi(_cells_count * _density)) + " mines"
	difficulty_label.text = DifficultyPresets.get_difficulty_name(_density)


## Greys out the no-guess checkbox above the density cap. Stored preference is
## kept untouched so toggling density back below the cap restores the user's
## prior choice.
func _refresh_no_guess_availability() -> void:
	var allowed := _density < NoGuessGenerator.MAX_DENSITY
	no_guess_check.disabled = not allowed
	no_guess_hint_label.modulate.a = 1.0 if not allowed else 0.6
	if allowed:
		no_guess_check.button_pressed = _no_guess
	else:
		no_guess_check.button_pressed = false


func _on_start_game_pressed() -> void:
	GameConfig.subdivision = _size
	GameConfig.density = _density
	GameConfig.no_guess_mode = _no_guess
	GameConfig.save()
	get_tree().change_scene_to_packed(game_scene)


func _on_size_changed(value: float) -> void:
	_size = int(value)
	_set_labels_text()


func _on_density_changed(value: float) -> void:
	_density = value
	_set_labels_text()
	_refresh_no_guess_availability()


func _on_no_guess_toggled(pressed: bool) -> void:
	if no_guess_check.disabled:
		return
	_no_guess = pressed
