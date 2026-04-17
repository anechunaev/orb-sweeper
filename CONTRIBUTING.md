# Contributing to Orb Sweeper

Thanks for taking the time to contribute! This document captures the conventions the project expects from pull requests and issues. Keep it open while you work — it's short on purpose.

## Table of contents

- [Getting started](#getting-started)
- [Development workflow](#development-workflow)
- [Architecture rules](#architecture-rules)
- [Code style](#code-style)
- [Documentation & comments](#documentation--comments)
- [Commit & PR guidelines](#commit--pr-guidelines)
- [Reporting bugs & requesting features](#reporting-bugs--requesting-features)

---

## Getting started

1. Install **Godot 4.6** (or a later 4.x release on the same minor version). The project targets the **Mobile** rendering backend and uses **Jolt Physics**.
2. Clone the repo and open `project.godot` in Godot — the editor will regenerate any missing `*.uid` files on first load.
3. Press **Play** to run. The main scene is `scenes/main.tscn` (menu hub), which navigates to `scenes/game.tscn` for gameplay.
4. The Android export preset writes the APK to `../orb-sweeper.apk` (`armv7a` + `arm64-v8a`, ETC2/ASTC texture compression).

### Smoke test

A headless scene exercises the no-guess generator:

```sh
godot --headless --quit-after 1 --path . scenes/tests/test_no_guess_generator.tscn
```

Solvable rate must remain 100% on classic presets.

---

## Development workflow

1. Open an issue first for anything non-trivial (new feature, user-visible behavior change, refactor that spans multiple files). For typo fixes and obvious bugs a direct PR is fine.
2. Branch off `main`.
3. Run the game yourself and exercise the code path you changed — type-check and unit tests don't verify feature correctness.
4. Keep PRs focused. If you notice unrelated cleanup while you work, open a separate PR for it.

---

## Architecture rules

These are the non-negotiable rules for new code. They come straight out of the issues surfaced in past code reviews — please don't re-introduce them.

### One domain per script

Every script should represent **one domain** with **one purpose**. If a script drifts into a second concern, split it. Some concrete examples already in the repo:

- `AudioManager`, `HapticsManager`, `BackgroundManager`, `GameConfig`, `SettingsStore` are separate autoloads in `scripts/autoload/`; don't fold new settings into whichever manager is closest — add a focused autoload, or a new section to `SettingsStore`.
- `SphericalMinesweeper` is the game controller in `scripts/game/`. Visual FX (`ExplosionSpawner` in `scripts/rendering/`), collision setup (`SphereColliderSetup` in `scripts/geometry/`), and shared mine-placement math (`MinePlacer` in `scripts/game/`) live in their own files.
- `DifficultyPresets` and `TimeFormatter` live in `scripts/util/`; Goldberg-specific math (`face_count`, etc.) lives on `GoldbergPolyhedron` in `scripts/geometry/`.

### Respect encapsulation

- Do **not** read or write `_underscore_prefixed` members of another class. Add a public accessor on that class instead (e.g. `SphericalMinesweeper.get_face_centers()`, `OrbitCamera.is_drag_active()`).
- Signals are the preferred way to communicate out of gameplay code. UI / HUD components should subscribe, not poll.

### Don't duplicate logic

Shared algorithms live in a helper (`MinePlacer.build_safe_zone`, `MinePlacer.place_mines`, `MinePlacer.compute_neighbor_counts` are the canonical examples). If you find yourself copy-pasting a loop between two scripts, extract it first.

### Autoloads are services, not buckets

Each autoload owns one concern and lives in `scripts/autoload/`. Order in `project.godot` matters — a manager that reads from `SettingsStore` in `_ready()` must be registered after it. When adding a new autoload:

1. Give it a `_ready()` that hydrates from `SettingsStore`.
2. Expose an `apply()` method when the state needs to be pushed somewhere (audio bus, sky material, etc.).
3. Expose a `save()` method that writes its section back through `SettingsStore`.

---

## Code style

- **GDScript**, tabs for indentation, snake\_case for variables and functions, PascalCase for `class_name`s and enums.
- Prefer typed variables and return types. Reach for `PackedByteArray` / `PackedInt32Array` / `PackedVector3Array` over `Array` when the payload is homogeneous — these are what the renderers and solver already use.
- Put `class_name` on anything that's referenced from more than one file or from a scene. Scripts without a `class_name` are fine only if they are scene-local.
- Use `@export` for anything wired up in a scene; avoid `@onready` for external resources — prefer `const X := preload(...)` at the top of the file when the scene is built in.
- No trailing semicolons. No dead / commented-out code.
- Match the sphere-radius convention: `radius = subdivision * 2.0`.

---

## Documentation & comments

### Public API — must be documented

Anything reachable from another file is public: `class_name` classes, `signal`s, and non-underscore methods / properties. Document them with Godot's `##` doc comments so they show up in the editor's inline help.

```gdscript
## Emitted when the player commits a reveal gesture (tap or left click).
signal face_revealed(face_index: int)


## Discard any in-flight press / long-press gesture so the next user input
## starts fresh. Call when a modal UI opens mid-press.
func cancel_input() -> void:
	...
```

Include a class-level `##` header on every `class_name`d file explaining what the script owns.

### Non-public comments — remove unless they explain something non-obvious

The default is **no comment**. Well-named identifiers already describe what the code does. Only write a comment when it captures something a future reader can't see from the code itself:

- Platform quirks (`# GDScript: regular Array = reference type, safe to append`)
- Hacks and workarounds (`# Slightly larger than visual radius so raised tiles are still clickable`)
- Non-obvious invariants (`# shouldn't happen on a closed manifold`)
- Algorithmic rationale that isn't derivable from the code (`# Snapshot because reveals mutate the list…`)

Do **not** write comments that restate the code, narrate the steps (`# 1. Build mesh`, `# Allocate arrays`), or label trivial sections. Reviewers will ask you to remove them.

---

## Commit & PR guidelines

- Commit in logical units. A refactor and a feature change should be separate commits (and ideally separate PRs).
- Commit messages: short imperative subject line, optional body for the "why". Past subjects for reference: `Added settings screen`, `Code review`, `Updated gitignore`.
- Rebase (don't merge) when bringing your branch up to date with `main`.
- In the PR description, include:
  - What the change does and **why**
  - How you tested it (which scenes you ran, devices, edge cases covered)
  - Screenshots or short GIFs for any visible change
- Don't commit generated files such as exported APKs, `.import/`, or IDE-specific settings that aren't already tracked.

---

## Reporting bugs & requesting features

### Bug reports

Please include:

- Godot version and platform (desktop OS, or Android device + API level)
- Difficulty / board parameters at the time of the bug (`subdivision`, `density`, no-guess on/off)
- Steps to reproduce — ideally from a fresh board
- What you expected vs. what happened
- Screenshot, screen recording, or stack trace if available

### Feature requests

Describe the problem before the solution. A good request explains what you're trying to accomplish and why the current behavior doesn't work for you; it's fine to suggest an implementation, but keep it separable from the underlying need.

---

Thanks again for contributing — small polish PRs are as welcome as big ones.
