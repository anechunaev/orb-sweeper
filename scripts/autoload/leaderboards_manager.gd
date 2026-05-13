## Bridges Orb Sweeper records to Google Play Games leaderboards.
## Mobile-only; no-ops on desktop or when the plugin singleton is absent.
extends Node

## Emitted whenever sign-in or plugin-availability state changes. Listeners
## should re-query [member is_authenticated] / [method is_ready_for_use].
signal state_changed

const _PLUGIN := "GodotPlayGameServices"

## True once Play Games has reported a successful sign-in for the current
## session. Always false on desktop or when the plugin is missing.
var is_authenticated: bool = false

var _sign_in: PlayGamesSignInClient
var _leaderboards: PlayGamesLeaderboardsClient


func _enter_tree() -> void:
	if _available():
		GodotPlayGameServices.initialize()


func _ready() -> void:
	if not _available():
		state_changed.emit()
		return
	if GodotPlayGameServices.android_plugin == null:
		state_changed.emit()
		return
	_sign_in = PlayGamesSignInClient.new()
	add_child(_sign_in)
	_leaderboards = PlayGamesLeaderboardsClient.new()
	add_child(_leaderboards)
	_sign_in.user_authenticated.connect(_on_authenticated)
	state_changed.emit()
	_sign_in.is_authenticated()


## True when the leaderboards client is initialized and can accept calls.
## Callers should still expect submissions to silently no-op if not signed in.
func is_ready_for_use() -> bool:
	return _leaderboards != null


## Triggers the Play Games sign-in flow. No-op when the plugin is unavailable.
func request_sign_in() -> void:
	if _sign_in != null:
		_sign_in.sign_in()


func _on_authenticated(authed: bool) -> void:
	is_authenticated = authed
	state_changed.emit()
	if authed:
		_backfill()


## Submits a finished-board time to the Play Games leaderboard that matches the
## given preset. Silently no-ops if the preset has no leaderboard mapping or
## the plugin is unavailable. [param time_usec] is converted to milliseconds
## for the Play Games API.
func submit_score(subdivision: int, density: float, no_guess: bool, time_usec: int) -> void:
	if _leaderboards == null:
		return
	var id := LeaderboardIds.lookup(subdivision, density, no_guess)
	if id.is_empty():
		return
	_leaderboards.submit_score(id, time_usec / 1000)


## Opens the native Play Games "all leaderboards" UI.
func show_all_leaderboards() -> void:
	if _leaderboards == null:
		return
	_leaderboards.show_all_leaderboards()


## Opens the native Play Games UI for the leaderboard matching the given
## preset. No-op if the preset has no mapping.
func show_leaderboard_for(subdivision: int, density: float, no_guess: bool) -> void:
	if _leaderboards == null:
		return
	var id := LeaderboardIds.lookup(subdivision, density, no_guess)
	if not id.is_empty():
		_leaderboards.show_leaderboard(id)


func _backfill() -> void:
	for preset in LeaderboardIds.PRESETS:
		var sub: int = preset[0]
		var den: float = preset[1]
		var ng: bool = preset[2]
		var best_usec: int = RecordsManager.get_best_time(sub, den, ng)
		if best_usec > 0:
			submit_score(sub, den, ng, best_usec)


func _available() -> bool:
	return OS.has_feature("mobile") and has_node("/root/" + _PLUGIN)
