# Integrate Google Play Games leaderboards

## Context

Orb Sweeper currently stores best times only in `user://records.json` via `RecordsManager`. To add social/competitive value on Android, integrate Google Play Games Services leaderboards using the [godot-sdk-integrations/godot-play-game-services](https://github.com/godot-sdk-integrations/godot-play-game-services) plugin (v3.2.0, Godot 4.3+).

**Scope** (chosen with user):
- All 6 preset leaderboards: Easy / Normal / Hard × Classic / No-Guess.
- Auto silent sign-in on launch (plugin default).
- Backfill local bests on first authenticated launch.
- No achievements at this time.
- Custom-difficulty games never submit (no fixed leaderboard ID exists for them).

Times in records are µs; Play Games leaderboards expect ms (`time_usec / 1000`), lower-is-better, "Time, 3 decimals" format.

---

## File-level plan

### A. Plugin install

1. Drop plugin v3.2.0 into `addons/GodotPlayGameServices/` (release zip from the repo).
2. `project.godot` `[editor_plugins]`: `enabled=PackedStringArray("res://addons/GodotPlayGameServices/plugin.cfg")`.
3. Project Settings → Plugins → enable. Open the plugin dock and paste the Play Console **Application ID** — the dock writes it into `/android/build/AndroidManifest.xml` as `com.google.android.gms.games.APP_ID`. The custom build template at `/android/build/` already exists.
4. `export_presets.cfg`: flip `permissions/internet=true` for the Android preset (currently only `vibrate` is on; Play Games requires network).

The plugin auto-registers its own autoload `GodotPlayGameServices` and performs silent sign-in at app start, emitting `sign_in_client.user_authenticated(is_authenticated: bool)`.

### B. New autoload — `scripts/autoload/leaderboard_ids.gd`

Single source of truth for the six leaderboard IDs the user creates in Play Console.

```gdscript
extends Node
## Maps preset (subdivision, density, no_guess) -> Play Games leaderboard ID.
## Empty string means "not configured" — submissions for that preset no-op.

const PRESETS: Array = [
    [3, 0.15, false], [5, 0.20, false], [7, 0.25, false],  # Classic
    [3, 0.15, true],  [5, 0.20, true],  [7, 0.25, true],   # No-Guess
]

const IDS := {
    [3, 0.15, false]: "",
    [5, 0.20, false]: "",
    [7, 0.25, false]: "",
    [3, 0.15, true]:  "",
    [5, 0.20, true]:  "",
    [7, 0.25, true]:  "",
}

static func lookup(subdivision: int, density: float, no_guess: bool) -> String:
    return IDS.get([subdivision, density, no_guess], "")
```

(If the array-key dictionary lookup is fragile in practice, swap to a string key `"%d:%.2f:%d" % [sub, den, int(ng)]` — same shape, same `lookup()` signature.)

### C. New autoload — `scripts/autoload/leaderboards_manager.gd`

```gdscript
extends Node
## Bridges Orb Sweeper records to Google Play Games leaderboards.
## Mobile-only; no-ops on desktop or when the plugin singleton is absent.

const _PLUGIN := "GodotPlayGameServices"

func _ready() -> void:
    if not _available(): return
    _pgs().sign_in_client.user_authenticated.connect(_on_authenticated)

func _on_authenticated(is_authenticated: bool) -> void:
    if is_authenticated:
        _backfill()

func submit_score(subdivision: int, density: float, no_guess: bool, time_usec: int) -> void:
    if not _available(): return
    var id := LeaderboardIds.lookup(subdivision, density, no_guess)
    if id.is_empty(): return
    _pgs().leaderboards_client.submit_score(id, time_usec / 1000)

func show_all_leaderboards() -> void:
    if not _available(): return
    _pgs().leaderboards_client.show_all_leaderboards()

func show_leaderboard_for(subdivision: int, density: float, no_guess: bool) -> void:
    if not _available(): return
    var id := LeaderboardIds.lookup(subdivision, density, no_guess)
    if not id.is_empty():
        _pgs().leaderboards_client.show_leaderboard(id)

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

func _pgs() -> Node:
    return get_node("/root/" + _PLUGIN)
```

`project.godot` `[autoload]`, appended after `RecordsManager`:
```
LeaderboardIds="*res://scripts/autoload/leaderboard_ids.gd"
LeaderboardsManager="*res://scripts/autoload/leaderboards_manager.gd"
```

Reuses existing `RecordsManager.get_best_time(subdivision, density, no_guess)` at `scripts/autoload/records_manager.gd:84`.

### D. Win hook — `scripts/game/spherical_minesweeper.gd:441`

One added line directly after the existing call:
```gdscript
RecordsManager.update_record(subdivision, mine_ratio, _final_time_usec, no_guess)
LeaderboardsManager.submit_score(subdivision, mine_ratio, no_guess, _final_time_usec)
```
Submit on every win, not only on PB. Play Games keeps the best server-side, idempotent submission is cheap, and this avoids duplicating PB-comparison logic the records layer already does.

### E. Records UI button — `scripts/ui/screen_records.gd` (+ scene)

Add one `Button` labelled "View leaderboards" near the tab header. In `_ready`:
```gdscript
view_lb_button.visible = OS.has_feature("mobile")
view_lb_button.pressed.connect(LeaderboardsManager.show_all_leaderboards)
```
No per-card buttons; keep the surface minimal.

---

## Play Console manual steps (user)

1. Play Console → Grow → **Play Games Services** → Setup. Create new game configuration; link package `com.nechunaev.orb_sweeper`.
2. Add OAuth credentials: paste **upload SHA-1** (from `keytool -list -v -keystore <upload>.keystore`) and **Play app-signing SHA-1** (Console → Setup → App integrity).
3. Copy the **Application ID** from the credentials page → paste into the Godot plugin dock.
4. Create six leaderboards: lower-is-better, format = **Time, 3 decimals (ms)**:
   - Classic Easy / Normal / Hard
   - No-Guess Easy / Normal / Hard
5. Copy each leaderboard ID into the matching `LeaderboardIds.IDS` entry.
6. **Publish** the Play Games Services configuration (separate from the APK release toggle).
7. Upload signed AAB to an **internal test track**; add tester Google accounts and have them opt in. Play Games sign-in only works for installs that come through Play (or via a signed test track) — direct ADB installs will fail to sign in.

---

## Verification

- **Desktop run** (editor + Linux export): app still launches; `_available()` returns false; every leaderboard path no-ops.
- **Mobile build**: gradle build via the existing custom template succeeds with the plugin's `.aar`. Verify `INTERNET` permission and `com.google.android.gms.games.APP_ID` meta-data both appear in the merged manifest.
- **Sign-in**: install from the internal test track; on first launch the Play Games welcome chip appears.
- **Backfill**: with pre-existing local records, on first authenticated launch the matching leaderboards receive submissions for the bests.
- **Live submit**: win each of the six presets; confirm the corresponding leaderboard updates within seconds.
- **UI**: "View leaderboards" button in the Records screen opens the native Play Games leaderboard list.
- **Custom games**: win a non-preset combo (e.g. s=4 d=0.18); confirm `LeaderboardIds.lookup` returns "" and no submission is made.

---

## Critical files

- `addons/GodotPlayGameServices/` (new — plugin drop-in)
- `scripts/autoload/leaderboard_ids.gd` (new)
- `scripts/autoload/leaderboards_manager.gd` (new)
- `scripts/game/spherical_minesweeper.gd:441` (one-line hook)
- `scripts/ui/screen_records.gd` + its `.tscn` (one button)
- `project.godot` (two autoload registrations + plugin enable)
- `export_presets.cfg` (`permissions/internet=true`)
