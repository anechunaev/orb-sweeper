## Custom-game difficulty preferences picked by the user. Read by the "new
## game" / "custom game" screens and by [SphericalMinesweeper] when a board
## is generated.
extends Node

var subdivision: int = 3
var density: float = 0.15
var no_guess_mode: bool = false


func _ready() -> void:
	subdivision = SettingsStore.get_value("custom_game", "subdivision", subdivision)
	density = SettingsStore.get_value("custom_game", "density", density)
	no_guess_mode = SettingsStore.get_value("custom_game", "no_guess_mode", no_guess_mode)


## True when no-guess generation is both requested AND permitted for the
## current density. Use this everywhere gameplay needs to branch.
func is_no_guess_effective() -> bool:
	return no_guess_mode and density < NoGuessGenerator.MAX_DENSITY


## Persist the current preferences to [SettingsStore].
func save() -> void:
	SettingsStore.set_value("custom_game", "subdivision", subdivision)
	SettingsStore.set_value("custom_game", "density", density)
	SettingsStore.set_value("custom_game", "no_guess_mode", no_guess_mode)
	SettingsStore.save()
