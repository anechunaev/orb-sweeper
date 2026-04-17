class_name ScreenAbout
extends Control

@export var rules_label: RichTextLabel
@export var info_label: RichTextLabel

const _RULES_BBCODE := """[b]Goal[/b]
Reveal all safe cells on the sphere without hitting a mine.

[b]Controls[/b]
[indent]Tap a cell to reveal it.
Long-press a cell to place or remove a flag.
Tap a revealed number to chord (reveal all unflagged neighbors if the correct number of flags is placed around it).
Drag to rotate the sphere. Pinch or scroll to zoom.[/indent]

[b]How numbers work[/b]
[indent]Each revealed cell shows how many of its neighbors are mines. Hexagons have 6 neighbors, pentagons have 5.[/indent]

[b]Winning & losing[/b]
[indent]You win when every non-mine cell is revealed. You lose if you reveal a mine.[/indent]

[b]No-guess mode[/b]
[indent]When enabled, the generated puzzle is guaranteed to be solvable through logic alone — no guessing required.[/indent]
[indent]When game is on, there is an indicator at the top middle of the screen representing current state of the game. Green square with letters "NG" means that No-Guess mode is on, and the board is guaranteed to be solved. Red square with letter "G" means that you probably will need to guess eventually.[/indent]"""

const _INFO_BBCODE := """All SFX and music made by [url=https://www.zapsplat.com/]ZapSplat[/url] ([url=https://www.zapsplat.com/license-type/standard-license/]License[/url])

Author: [url=mailto:artem@nechunaev.com]Artem Nechunaev[/url]

Source code: [url=https://github.com/anechunaev/orb-sweeper]github.com/anechunaev/orb-sweeper[/url]

Code license: MIT"""


func _ready() -> void:
	rules_label.text = _RULES_BBCODE
	info_label.text = _INFO_BBCODE


func _on_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))
