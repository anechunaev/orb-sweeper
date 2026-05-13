## Settings screen: vibration, audio volumes, background style.
class_name ScreenSettings
extends Control

@export var vibration_checkbox: CheckButton
@export var one_finger_zoom_checkbox: CheckButton
@export var reverse_zoom_row: Control
@export var reverse_zoom_checkbox: CheckButton
@export var rotation_sensitivity_slider: HSlider
@export var master_volume_slider: HSlider
@export var music_volume_slider: HSlider
@export var background_style_option: OptionButton


func _ready() -> void:
	if background_style_option.item_count == 0:
		background_style_option.add_item("Gradient", 0)
		background_style_option.add_item("Clouds", 1)

	vibration_checkbox.set_pressed_no_signal(HapticsManager.vibration_enabled)
	one_finger_zoom_checkbox.set_pressed_no_signal(InputManager.one_finger_zoom_enabled)
	reverse_zoom_checkbox.set_pressed_no_signal(InputManager.reverse_zoom_direction)
	rotation_sensitivity_slider.set_value_no_signal(InputManager.rotation_sensitivity)
	master_volume_slider.set_value_no_signal(AudioManager.master_volume)
	music_volume_slider.set_value_no_signal(AudioManager.music_volume)
	background_style_option.select(
		0 if BackgroundManager.background_style == BackgroundManager.BG_GRADIENT else 1)
	_update_reverse_zoom_visibility()


func _update_reverse_zoom_visibility() -> void:
	reverse_zoom_row.visible = InputManager.one_finger_zoom_enabled


func _on_vibration_toggled(pressed: bool) -> void:
	HapticsManager.vibration_enabled = pressed
	HapticsManager.save()


func _on_one_finger_zoom_toggled(pressed: bool) -> void:
	InputManager.one_finger_zoom_enabled = pressed
	InputManager.save()
	_update_reverse_zoom_visibility()


func _on_reverse_zoom_toggled(pressed: bool) -> void:
	InputManager.reverse_zoom_direction = pressed
	InputManager.save()


func _on_rotation_sensitivity_changed(value: float) -> void:
	InputManager.rotation_sensitivity = value
	InputManager.save()


func _on_master_volume_changed(value: float) -> void:
	AudioManager.master_volume = value
	AudioManager.apply()
	AudioManager.save()


func _on_music_volume_changed(value: float) -> void:
	AudioManager.music_volume = value
	AudioManager.apply()
	AudioManager.save()


func _on_background_style_selected(index: int) -> void:
	BackgroundManager.background_style = \
		BackgroundManager.BG_CLOUDS if index == 1 else BackgroundManager.BG_GRADIENT
	BackgroundManager.apply()
	BackgroundManager.save()
