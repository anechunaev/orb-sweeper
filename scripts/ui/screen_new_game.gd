## "New game" screen: classic difficulty buttons + no-guess toggle.
class_name ScreenNewGame
extends Control

@export var no_guess_check: CheckButton

@onready var game_scene = preload("res://scenes/game.tscn")


func _ready() -> void:
	no_guess_check.button_pressed = GameConfig.no_guess_mode


func _start_classic(index: int) -> void:
	var preset: Dictionary = DifficultyPresets.CLASSIC[index]
	GameConfig.density = preset["density"]
	GameConfig.subdivision = preset["subdivision"]
	GameConfig.save()
	get_tree().change_scene_to_packed(game_scene)


func _on_no_guess_toggled(pressed: bool) -> void:
	GameConfig.no_guess_mode = pressed
	GameConfig.save()


func _on_easy_mode_pressed() -> void:
	_start_classic(0)


func _on_normal_mode_pressed() -> void:
	_start_classic(1)


func _on_hard_mode_pressed() -> void:
	_start_classic(2)
