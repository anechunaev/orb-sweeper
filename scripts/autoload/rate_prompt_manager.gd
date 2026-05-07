## Tracks total wins and decides when to show the Google Play rating prompt.
## Persisted via [SettingsStore] under section "rate_prompt".
extends Node

const SECTION := "rate_prompt"
const KEY_WINS_TOTAL := "wins_total"
const KEY_NEXT_PROMPT_AT := "next_prompt_at"
const POSTPONE_WINS := 5
const NEVER := -1
const PLAY_STORE_URL := "market://details?id=com.nechunaev.orb_sweeper&showAllReviews=true"

var wins_total: int = 0
var next_prompt_at: int = 1


func _ready() -> void:
	wins_total = int(SettingsStore.get_value(SECTION, KEY_WINS_TOTAL, 0))
	next_prompt_at = int(SettingsStore.get_value(SECTION, KEY_NEXT_PROMPT_AT, 1))


## Increment the win counter and persist. Call once per won game.
func record_win() -> void:
	wins_total += 1
	SettingsStore.set_value(SECTION, KEY_WINS_TOTAL, wins_total)
	SettingsStore.save()


## True when the rating popup should be shown right now.
func should_prompt() -> bool:
	if OS.get_name() == "Android":
		if next_prompt_at == NEVER:
			return false
		return wins_total >= next_prompt_at
	return false


## Re-prompt after [POSTPONE_WINS] more wins.
func postpone() -> void:
	next_prompt_at = wins_total + POSTPONE_WINS
	SettingsStore.set_value(SECTION, KEY_NEXT_PROMPT_AT, next_prompt_at)
	SettingsStore.save()


## Open the Play Store listing and stop prompting forever.
func mark_rated() -> void:
	next_prompt_at = NEVER
	SettingsStore.set_value(SECTION, KEY_NEXT_PROMPT_AT, next_prompt_at)
	SettingsStore.save()
	OS.shell_open(PLAY_STORE_URL)
