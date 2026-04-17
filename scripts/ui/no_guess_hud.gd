## Transient HUD overlay for no-guessing mode.
##
## Two responsibilities:
## [br] • Show a "Generating…" indicator while the background solver runs so
##   the player understands why the board hasn't appeared yet.
## [br] • Show a one-shot warning toast if the generator gave up and accepted
##   a board that may still need a guess.
class_name NoGuessHud
extends Control

@export var game: SphericalMinesweeper
@export var generating_label: Control
@export var warning_label: Control
@export var warning_seconds: float = 3.0

var _warning_timer: SceneTreeTimer


func _ready() -> void:
	generating_label.visible = false
	warning_label.visible = false
	game.no_guess_generating.connect(_on_generating)
	game.no_guess_warning.connect(_on_warning)


func _on_generating(active: bool) -> void:
	generating_label.visible = active


func _on_warning() -> void:
	warning_label.visible = true
	_warning_timer = get_tree().create_timer(warning_seconds)
	_warning_timer.timeout.connect(_hide_warning)


func _hide_warning() -> void:
	warning_label.visible = false
	_warning_timer = null
