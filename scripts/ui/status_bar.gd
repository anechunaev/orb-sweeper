## In-game HUD status bar: mine counter, elapsed timer, and no-guess indicator.
##
## Subscribes to [SphericalMinesweeper] signals rather than polling every frame.
class_name StatusBar
extends Node

@export var game_manager: SphericalMinesweeper
@export var label_mines: Label
@export var label_timer: Label
@export var no_guess_indicator: Panel
@export var no_guess_label: Label
@export var ng_style_red: StyleBox
@export var ng_style_green: StyleBox

func _ready() -> void:
	game_manager.stats_updated.connect(_on_status_change)
	game_manager.game_ready.connect(_on_game_ready)
	game_manager.game_timer_tick.connect(_on_timer_tick)
	game_manager.no_guess_warning.connect(_on_no_guess_warning)
	_refresh_no_guess_indicator()

func _on_status_change(_clrd: int, flagged: int, total_mines: int, _total_cells: int) -> void:
	label_mines.text = str(total_mines - flagged)

func _on_timer_tick(current_time: int) -> void:
	label_timer.text = str(roundi(current_time / 1_000_000.0))

func _on_game_ready() -> void:
	var stats = game_manager.get_stats()
	if stats:
		label_mines.text = str(stats.mine_count)
	_refresh_no_guess_indicator()

func _on_no_guess_warning() -> void:
	_set_no_guess_indicator(false)

func _refresh_no_guess_indicator() -> void:
	_set_no_guess_indicator(GameConfig.is_no_guess_effective())

func _set_no_guess_indicator(no_guess: bool) -> void:
	if no_guess:
		no_guess_indicator.add_theme_stylebox_override("panel", ng_style_green)
		no_guess_label.text = "NG"
	else:
		no_guess_indicator.add_theme_stylebox_override("panel", ng_style_red)
		no_guess_label.text = "G"
