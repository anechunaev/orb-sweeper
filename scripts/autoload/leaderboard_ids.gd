## Single source of truth mapping preset difficulty
## (subdivision, density, no_guess) to its Play Games leaderboard ID.
## Empty string means "not configured" — submissions for that preset no-op.
extends Node

const PRESETS: Array = [
	[3, 0.15, false], [5, 0.20, false], [7, 0.25, false],
	[3, 0.15, true],  [5, 0.20, true],  [7, 0.25, true],
]

const IDS := {
	"3:0.15:0": "CgkI6eCRqp4dEAIQAQ",
	"5:0.20:0": "CgkI6eCRqp4dEAIQAg",
	"7:0.25:0": "CgkI6eCRqp4dEAIQAw",
	"3:0.15:1": "CgkI6eCRqp4dEAIQBA",
	"5:0.20:1": "CgkI6eCRqp4dEAIQBQ",
	"7:0.25:1": "CgkI6eCRqp4dEAIQBg",
}

static func lookup(subdivision: int, density: float, no_guess: bool) -> String:
	var key := "%d:%.2f:%d" % [subdivision, density, int(no_guess)]
	return IDS.get(key, "")
