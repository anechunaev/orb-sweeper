## Difficulty presets and density-to-name mapping for Orb Sweeper.
class_name DifficultyPresets

## Classic preset rows used by the main menu and the records screen.
const CLASSIC: Array[Dictionary] = [
	{ "label": "Easy",   "subdivision": 3, "density": 0.15 },
	{ "label": "Normal", "subdivision": 5, "density": 0.2  },
	{ "label": "Hard",   "subdivision": 7, "density": 0.25 },
]


## Map a mine density ratio (0.0–1.0) to a human-readable difficulty name.
static func get_difficulty_name(ratio: float) -> String:
	if ratio < 0.1:
		return "Very Easy"
	elif ratio < 0.2:
		return "Easy"
	elif ratio < 0.25:
		return "Normal"
	elif ratio < 0.33:
		return "Hard"
	else:
		return "Very Hard"
