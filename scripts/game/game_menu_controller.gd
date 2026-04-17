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
@export var ui_exit_button: Button
@export var menu_delay_timer: Timer


func _ready() -> void:
	menu_delay_timer.timeout.connect(_show_menu_endgame)
	game.game_won.connect(_on_game_ended)
	game.game_lost.connect(_on_game_ended)


func _on_game_ended() -> void:
	menu_delay_timer.start()


## Show or hide the menu overlay. When showing, refreshes the status / time /
## difficulty / record labels from the current game state.
func toggle_menu(show_menu: bool = false) -> void:
	if show_menu:
		game.cancel_input()

		var status := "Game is on!"
		var time := TimeFormatter.format_time(0)
		if game.phase == SphericalMinesweeper.GamePhase.WON:
			status = "You won!"
			time = TimeFormatter.format_time(game.get_current_time())
		elif game.phase == SphericalMinesweeper.GamePhase.LOST:
			status = "You lost!"
			time = TimeFormatter.format_time(game.get_current_time())
		var record_str := TimeFormatter.format_time(
			RecordsManager.get_best_time(game.subdivision, game.mine_ratio, game.no_guess))
		ui_menu_status.text = status
		ui_menu_time.text = time
		ui_menu_record.text = record_str
		var diff_name := DifficultyPresets.get_difficulty_name(game.mine_ratio)
		if game.no_guess:
			diff_name += " · No Guess"
		ui_menu_difficulty_name.text = diff_name
		ui_menu_difficulty_params.text = "d=" + str(int(game.mine_ratio * 100)) + "% s=" + str(game.subdivision)
	camera.toggle_input_handling(!show_menu)
	ui_menu.visible = show_menu


## Returns true when the menu overlay is currently on-screen.
func is_menu_visible() -> bool:
	return ui_menu.visible


func _show_menu_endgame() -> void:
	toggle_menu(true)


func _on_new_game_button_pressed() -> void:
	toggle_menu(false)
	restart_requested.emit()


func _on_menu_button_pressed() -> void:
	toggle_menu(!ui_menu.visible)


func _on_exit_to_main_menu_pressed() -> void:
	exit_requested.emit()


func _on_close_button_pressed() -> void:
	toggle_menu(false)
