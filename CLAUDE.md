# CLAUDE.md

## Project Overview
Orb Sweeper is a 3D minesweeper game played on a Goldberg polyhedron (sphere of hexagons and pentagons), built with Godot 4.6 and GDScript. It targets mobile (Android) with portrait orientation (400x800 viewport).

## Running the Project
Open `project.godot` in Godot 4.6. The main scene is `scenes/main.tscn` (menu hub) which navigates to `scenes/game.tscn` for gameplay.
Android export outputs to `../orb-sweeper.apk` (armv7a + arm64-v8a).

## Architecture
### Scene & Script Structure
- `scenes/main.tscn` — Main menu with screen navigation (new game, custom game, records)
- `scenes/game.tscn` — Gameplay scene containing the sphere, camera, HUD, and renderers

### Script Organization (`scripts/`)
Scripts are grouped into subdirectories by concern:
- **`game/`** — Core gameplay: `spherical_minesweeper.gd` (game controller), `game_input_handler.gd`, `game_menu_controller.gd`, `mine_placer.gd`, `no_guess_generator.gd`
- **`geometry/`** — Goldberg polyhedron: `goldberg_polyhedron.gd` (procedural mesh, 10s²+2 faces), `goldberg_cell_manager.gd` (1×N R8 data texture, states 0-5), `sphere_collider_setup.gd`
- **`rendering/`** — Visual: `cell_number_renderer.gd`, `flag_renderer.gd`, `mine_renderer.gd` (MultiMesh), `orbit_camera.gd` (quaternion + inertia), `explosion.gd`, `explosion_spawner.gd`
- **`ui/`** — Screens & HUD: `main_screen_controller.gd`, `screen_*.gd` (new game, custom, records, settings, about), `status_bar.gd`, `no_guess_hud.gd`, `record_card.gd`, `menu_sphere.gd`
- **`autoload/`** — Singleton services (registered in project.godot)
- **`util/`** — Pure utilities: `difficulty_presets.gd`, `time_formatter.gd`

### Rendering Pipeline
Three visual layers, all GPU-efficient:
1. **Base sphere** — `goldberg_cell.gdshader` reads the cell state data texture for per-face color, height displacement, fresnel glow, bevel shadows, and seam lines
2. **Number overlays** — `cell_number_renderer.gd` + `cell_number.gdshader`: MultiMeshInstance3D quads with bitmap digit patterns, camera-facing
3. **Flags/Mines** — `flag_renderer.gd` / `mine_renderer.gd`: MultiMeshInstance3D (single draw call each). Flag model uses vertex color R channel to separate pole (static) from cloth (animated)

### Autoload Singletons (`scripts/autoload/`)
- **`SettingsStore`** — Thin `ConfigFile` wrapper at `user://settings.cfg` used by the other managers to persist their sections
- **`AudioManager`** — `master_volume`, `music_volume`, applied to the `AudioServer` bus
- **`HapticsManager`** — `vibrate(duration_ms)` / `vibrate_descending()` respecting the user's `vibration_enabled` preference
- **`BackgroundManager`** — Registers scene sky materials and applies the selected panorama texture
- **`GameConfig`** — Holds custom-game preferences (`subdivision`, `density`, `no_guess_mode`) and `is_no_guess_effective()`
- **`RecordsManager`** — High scores persisted to `user://records.json`, keyed as `"{subdivision}_{density:.2f}"`

### Input Model
- **Desktop:** Left-click = reveal, right-click = flag, click revealed cell = chord
- **Touch:** Tap = reveal, long-press (0.4s) = flag
- **Camera:** Drag to orbit, scroll/pinch to zoom

### Difficulty System
Controlled by two parameters passed via `GameConfig`:
- `subdivision` (1-10): sphere density (s=3→92 faces, s=5→262, s=9→812)
- `density` (0.05-0.5): fraction of faces that are mines

Presets: Easy (s=3, 15%), Normal (s=5, 20%), Hard (s=7, 25%)

## Shader Files
- `goldberg_cell.gdshader` — Main sphere rendering with state-driven visuals
- `cell_number.gdshader` — Billboard number rendering
- `flag.gdshader` — Flag with cloth animation
- `mine.gdshader` / `outline3.gdshader` — Mine model + outline effect

## Key Conventions
- Mobile rendering backend with ETC2/ASTC compression
- Jolt Physics for 3D raycasting (face selection via dot product to face centers)
- Sphere radius scales with subdivision: `radius = subdivision * 2.0`
- Face adjacency stored as flat arrays for efficient BFS traversal
