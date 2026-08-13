## Controls the in-game menu overlay (pause / win / loss popup).
class_name GameMenuController
extends Node

## Emitted when the player picks "New game" in the menu.
signal restart_requested
## Emitted when the player picks "Exit to main menu" in the menu.
signal exit_requested

@export var game: SphericalMinesweeper
@export var camera: OrbitCamera

@export_group("Menu UI")
@export var ui_menu: Control
@export var ui_menu_status: Label
@export var ui_menu_time: Label
@export var ui_menu_difficulty_name: Label
@export var ui_menu_difficulty_params: Label
@export var ui_menu_record: Label
@export var ui_menu_efficiency: Label
@export var ui_menu_record_efficiency: Label
@export var ui_exit_button: Button
@export var ui_pause_menu_nutton: Button
@export var menu_delay_timer: Timer

@export_group("Rate Prompt UI")
@export var ui_rate_prompt: Control
@export var ui_rate_later_button: Button
@export var ui_rate_now_button: Button
@export var rate_prompt_delay_timer: Timer


func _ready() -> void:
	menu_delay_timer.timeout.connect(_show_menu_endgame)
	game.game_won.connect(_on_game_ended)
	game.game_lost.connect(_on_game_ended)
	rate_prompt_delay_timer.timeout.connect(_maybe_show_rate_prompt)
	ui_rate_later_button.pressed.connect(_on_rate_later_pressed)
	ui_rate_now_button.pressed.connect(_on_rate_now_pressed)


func _on_game_ended() -> void:
	menu_delay_timer.start()


## Show or hide the menu overlay. When showing, refreshes the status / time /
## difficulty / record labels from the current game state.
func toggle_menu(show_menu: bool = false) -> void:
	if show_menu:
		game.cancel_input()

		var status := "Game is on!"
		var time := TimeFormatter.format_time(0)
		var efficiency := EfficiencyFormatter.format_efficiency(0.0)
		if game.phase == SphericalMinesweeper.GamePhase.WON:
			status = "You won!"
			time = TimeFormatter.format_time(game.get_current_time())
			efficiency = EfficiencyFormatter.format_efficiency(game.get_efficiency())
		elif game.phase == SphericalMinesweeper.GamePhase.LOST:
			status = "You lost!"
			time = TimeFormatter.format_time(game.get_current_time())
			efficiency = EfficiencyFormatter.format_efficiency(game.get_efficiency())
		var record_str := TimeFormatter.format_time(
			RecordsManager.get_best_time(game.subdivision, game.mine_ratio, game.no_guess))
		var record_efficiency_str := EfficiencyFormatter.format_efficiency(
			RecordsManager.get_best_efficiency(game.subdivision, game.mine_ratio, game.no_guess))
		ui_menu_status.text = status
		ui_menu_time.text = time
		ui_menu_efficiency.text = efficiency
		ui_menu_record.text = record_str
		ui_menu_record_efficiency.text = record_efficiency_str
		var diff_name := DifficultyPresets.get_difficulty_name(game.mine_ratio)
		if game.no_guess:
			diff_name += " · No Guess"
		ui_menu_difficulty_name.text = diff_name
		ui_menu_difficulty_params.text = "d=" + str(int(game.mine_ratio * 100)) + "% s=" + str(game.subdivision)

		ui_exit_button.visible = true
		ui_pause_menu_nutton.visible = false
	camera.toggle_input_handling(!show_menu)
	ui_menu.visible = show_menu
	if not show_menu:
		_hide_rate_prompt()
		ui_exit_button.visible = false
		ui_pause_menu_nutton.visible = true


## Returns true when the menu overlay is currently on-screen.
func is_menu_visible() -> bool:
	return ui_menu.visible


func _show_menu_endgame() -> void:
	toggle_menu(true)
	if game.phase == SphericalMinesweeper.GamePhase.WON and RatePromptManager.should_prompt():
		rate_prompt_delay_timer.start()


func _maybe_show_rate_prompt() -> void:
	if not ui_menu.visible:
		return
	if not RatePromptManager.should_prompt():
		return
	ui_rate_prompt.visible = true


func _hide_rate_prompt() -> void:
	rate_prompt_delay_timer.stop()
	ui_rate_prompt.visible = false


func _on_rate_later_pressed() -> void:
	RatePromptManager.postpone()
	_hide_rate_prompt()


func _on_rate_now_pressed() -> void:
	RatePromptManager.mark_rated()
	_hide_rate_prompt()


func _on_new_game_button_pressed() -> void:
	toggle_menu(false)
	restart_requested.emit()


func _on_menu_button_pressed() -> void:
	toggle_menu(!ui_menu.visible)


func _on_exit_to_main_menu_pressed() -> void:
	exit_requested.emit()


func _on_close_button_pressed() -> void:
	toggle_menu(false)
