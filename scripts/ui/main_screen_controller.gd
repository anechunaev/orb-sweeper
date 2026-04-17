## Root controller for the main-menu scene. Handles navigation between the
## various menu screens (main, new game, custom game, records, settings, about).
## Visual decoration (the spinning sphere) lives on [MenuSphere].
class_name MainScreenController
extends Node3D

@export var click_sound: AudioStreamPlayer

@export var screen_main_menu: Control
@export var screen_new_game: Control
@export var screen_custom_game: Control
@export var screen_records: Control
@export var screen_settings: Control
@export var screen_about: Control

@export var menu_sky_material: PanoramaSkyMaterial


func _ready() -> void:
	if menu_sky_material:
		BackgroundManager.register_sky_material(menu_sky_material)
		BackgroundManager.apply()
	_switch_to_screen("main")


func _switch_to_screen(screen_name: String) -> void:
	screen_main_menu.visible = screen_name == "main"
	screen_new_game.visible = screen_name == "new_game"
	screen_custom_game.visible = screen_name == "custom_game"
	screen_records.visible = screen_name == "records"
	screen_settings.visible = screen_name == "settings"
	screen_about.visible = screen_name == "about"


func _on_back_to_new_game_menu_pressed() -> void:
	_switch_to_screen("new_game")


func _on_custom_mode_pressed() -> void:
	_switch_to_screen("custom_game")


func _on_back_to_main_menu_pressed() -> void:
	_switch_to_screen("main")


func _on_new_game_pressed() -> void:
	_switch_to_screen("new_game")


func _on_back_to_main_screen_from_records_pressed() -> void:
	_switch_to_screen("main")


func _on_records_pressed() -> void:
	_switch_to_screen("records")


func _on_settings_pressed() -> void:
	_switch_to_screen("settings")


func _on_about_pressed() -> void:
	_switch_to_screen("about")


func _on_back_to_main_from_settings_pressed() -> void:
	_switch_to_screen("main")


func _on_back_to_main_from_about_pressed() -> void:
	_switch_to_screen("main")


func _on_exit_button_pressed() -> void:
	get_tree().quit(0)


func _on_button_pressed() -> void:
	click_sound.play()
