## "About" screen: renders the rules summary and the credits / license /
## source-code links in two BBCode-formatted [RichTextLabel]s.
class_name ScreenAbout
extends Control

@export var rules_label: RichTextLabel
@export var info_label: RichTextLabel

const _RULES_BBCODE := """[b]Goal[/b]
Reveal all safe cells on the sphere without hitting a mine.

[b]Controls[/b]
Tap a cell to reveal it.
Long-press a cell to place or remove a flag.
Tap a revealed number to chord (reveal all unflagged neighbors if the correct number of flags is placed around it).
Drag to rotate the sphere. Pinch or scroll to zoom.

[b]How numbers work[/b]
Each revealed cell shows how many of its neighbors are mines. Hexagons have 6 neighbors, pentagons have 5.

[b]Winning & losing[/b]
You win when every non-mine cell is revealed. You lose if you reveal a mine.

[b]Efficiency[/b]
Efficiency compares your run to the fewest taps the board could have been cleared in: minimum taps divided by your taps.
Every input counts as a tap (reveals, flags, unflags and chords), including ones that do nothing, like tapping a flagged cell.
Chording can push you above 100%; flagging pushes it down.
Your best efficiency is tracked per difficulty next to your best time.

[b]No-guess mode[/b]
When enabled, the generated puzzle is guaranteed to be solvable through logic alone — no guessing required.
When game is on, there is an indicator at the top middle of the screen representing current state of the game. Green square with letters "NG" means that No-Guess mode is on, and the board is guaranteed to be solved. Red square with letter "G" means that you probably will need to guess eventually."""

const _INFO_BBCODE := """All SFX and music made by [url=https://www.zapsplat.com/]ZapSplat[/url] ([url=https://www.zapsplat.com/license-type/standard-license/]License[/url])

Author: [url=mailto:artem@nechunaev.com]Artem Nechunaev[/url]

Source code: [url=https://github.com/anechunaev/orb-sweeper]github.com/anechunaev/orb-sweeper[/url]

Code license: MIT"""


func _ready() -> void:
	rules_label.text = _RULES_BBCODE
	info_label.text = _INFO_BBCODE


func _on_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))
