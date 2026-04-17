## Spherical Minesweeper — main game controller.
##
## Manages game state, mine placement, cell reveal/flag/chord logic, win/loss
## detection, and renderer coordination. Input handling is delegated to
## [GameInputHandler] and menu UI to [GameMenuController].
class_name SphericalMinesweeper
extends Node3D

@export_group("Sphere")
## Goldberg subdivision level. 1 → 12 faces, 2 → 42, 3 → 92, 4 → 162 …
@export_range(1, 10) var subdivision: int = 3
## Sphere radius in world units. Derived from [member subdivision] in [method _ready].
var radius: float = 6.0

@export_group("Mines")
## Fraction of faces that are mines (0.0–1.0).
@export_range(0.05, 0.50, 0.01) var mine_ratio: float = 0.15
## Minimum safe zone radius around first click (in face-hops).
@export_range(0, 3) var safe_radius: int = 1

@export_group("Sounds")
@export var sound_click: AudioStreamPlayer
@export var sound_chord: AudioStreamPlayer
@export var sound_flag: AudioStreamPlayer
@export var sound_reveal: AudioStreamPlayer
@export var sound_stop: AudioStreamPlayer
@export var sound_won: AudioStreamPlayer
@export var sound_lost: AudioStreamPlayer

@export_group("References")
@export var sky_material: PanoramaSkyMaterial
@export var mesh_instance: MeshInstance3D
@export var camera: OrbitCamera
@export var input_handler: GameInputHandler
@export var menu_controller: GameMenuController
@export var shader: Shader
@export var number_shader: Shader
@export var flag_shader: Shader
## Optional custom flag mesh. Vertex color R=0 for pole, R=1 for cloth.
## Model convention: Y = up (pole), X = right (faces camera).
@export var flag_mesh: Mesh
@export var mine_shader: Shader
@export var outline_shader: Shader
## Optional custom mine mesh.
## Model convention: Y = up (face normal), X = right (faces camera).
@export var mine_mesh: Mesh

@export var core_sphere: Node3D
@export var game_ui_timer: Timer
var _start_time_usec: int
var _final_time_usec: int
@export var winning_ps: GPUParticles2D

## Emitted when the game is won (all non-mine cells cleared).
signal game_won
## Emitted when a mine is revealed.
signal game_lost
## Emitted whenever face counts change.
## [param cleared]: cells cleared so far.
## [param flagged]: cells currently flagged.
## [param total_mines]: total mines on the board.
## [param total_cells]: total cells on the board.
signal stats_updated(cleared: int, flagged: int, total_mines: int, total_cells: int)
## Emitted when the game is ready to start. Fires after the mesh, collision body,
## cell manager, number renderer, flag renderer, and mine renderer are all initialized.
signal game_ready
## Emitted on game timer tick
signal game_timer_tick(current_time_usec: int)
## Emitted when the no-guess generator is working. [param active] toggles the
## spinner/overlay; HUD listens to show or hide the "Generating…" indicator.
signal no_guess_generating(active: bool)
## Emitted once if the no-guess generator couldn't produce a fully solvable
## board within its wall-clock budget. HUD shows a brief warning toast.
signal no_guess_warning

enum GamePhase { WAITING_FIRST, GENERATING, PLAYING, WON, LOST }

## True for this game session if no-guess generation was requested AND
## permitted by [member NoGuessGenerator.MAX_DENSITY]. Locked in at
## board-generation time so records and the game menu stay consistent even
## if the user toggles the setting mid-session.
var no_guess: bool = false

var phase: GamePhase = GamePhase.WAITING_FIRST

## Wall-clock budget for the no-guess generator, in milliseconds.
const NO_GUESS_BUDGET_MSEC := 3000

var _result:  GoldbergPolyhedron.Result
var _manager: GoldbergCellManager
var _number_renderer: CellNumberRenderer
var _flag_renderer: FlagRenderer
var _mine_renderer: MineRenderer

var _is_mine:        PackedByteArray
var _neighbor_count: PackedInt32Array
var _revealed:       PackedByteArray
var _flagged:        PackedByteArray

var _mine_indices: PackedInt32Array
var _mine_count:   int = 0
var _face_count:   int = 0

var _cleared_count: int = 0
var _flagged_count: int = 0

var _ng_thread: Thread = null
var _ng_pending_first_click: int = -1

var _explosion_spawner: ExplosionSpawner


func _ready() -> void:
	if sky_material:
		BackgroundManager.register_sky_material(sky_material)
		BackgroundManager.apply()

	if GameConfig.density > 0:
		mine_ratio = GameConfig.density
	if GameConfig.subdivision > 0:
		subdivision = GameConfig.subdivision
		radius = subdivision * 2.0

	no_guess = GameConfig.is_no_guess_effective()

	_explosion_spawner = ExplosionSpawner.new()
	add_child(_explosion_spawner)

	_generate_board()
	_setup_camera()
	game_ui_timer.timeout.connect(_emit_tick)

	input_handler.face_revealed.connect(_on_reveal)
	input_handler.face_flagged.connect(_on_flag)

	menu_controller.restart_requested.connect(_on_restart_requested)
	menu_controller.exit_requested.connect(_on_exit_requested)


func _process(_delta: float) -> void:
	if _manager:
		_manager.process()
	if _ng_thread != null and not _ng_thread.is_alive():
		_finish_ng_generation()


func _exit_tree() -> void:
	# Drain the generation thread so we don't leak it on scene teardown.
	if _ng_thread != null:
		_ng_thread.wait_to_finish()
		_ng_thread = null


## Ask the input handler to discard any in-flight press / long-press so the
## next user input starts a fresh gesture. Call this before opening modal UI.
func cancel_input() -> void:
	input_handler.cancel_input()

func _generate_board() -> void:
	_result = GoldbergPolyhedron.generate(subdivision, radius)
	_face_count = _result.face_count
	mesh_instance.mesh = _result.mesh

	SphereColliderSetup.attach(mesh_instance, radius)

	_manager = GoldbergCellManager.create(_result, shader)
	mesh_instance.material_override = _manager.material

	_is_mine        = PackedByteArray()
	_is_mine.resize(_face_count)
	_neighbor_count = PackedInt32Array()
	_neighbor_count.resize(_face_count)
	_revealed       = PackedByteArray()
	_revealed.resize(_face_count)
	_flagged        = PackedByteArray()
	_flagged.resize(_face_count)

	_mine_indices  = PackedInt32Array()
	_mine_count    = 0
	_cleared_count = 0
	_flagged_count = 0

	phase = GamePhase.WAITING_FIRST

	if _number_renderer:
		_number_renderer.queue_free()
	_number_renderer = CellNumberRenderer.new()
	add_child(_number_renderer)
	_number_renderer.setup(camera, _face_count, radius, subdivision, number_shader)

	if _flag_renderer:
		_flag_renderer.queue_free()
	_flag_renderer = FlagRenderer.new()
	add_child(_flag_renderer)
	_flag_renderer.setup(camera, _face_count, radius, subdivision,
		flag_shader, flag_mesh)

	if _mine_renderer:
		_mine_renderer.queue_free()
	_mine_renderer = MineRenderer.new()
	add_child(_mine_renderer)
	_mine_renderer.setup(camera, _face_count, radius, subdivision,
		mine_shader, mine_mesh, outline_shader)

	core_sphere.scale.x = radius * 2.0 - 0.1
	core_sphere.scale.y = radius * 2.0 - 0.1
	core_sphere.scale.z = radius * 2.0 - 0.1

	_mine_count = clampi(roundi(_face_count * mine_ratio), 1, _face_count - 1)

	game_ready.emit()
	_emit_stats()


## Place mines, avoiding the safe zone around [param safe_face].
func _place_mines(safe_face: int) -> void:
	var safe_zone := MinePlacer.build_safe_zone(
		_result.adjacency, _face_count, safe_face, safe_radius)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_is_mine = MinePlacer.place_mines(_face_count, safe_zone, _mine_count, rng)

	_mine_indices = PackedInt32Array()
	for fi in _face_count:
		if _is_mine[fi] == 1:
			_mine_indices.append(fi)
	_mine_count = _mine_indices.size()

	_neighbor_count = MinePlacer.compute_neighbor_counts(
		_result.adjacency, _face_count, _is_mine)

func _setup_camera() -> void:
	if camera:
		camera.transform.origin.x = -1.0 * radius - 15.0
		camera.set_distance(abs(camera.transform.origin.x), radius + 5.0, radius + 40.0)

func _on_reveal(fi: int) -> void:
	if phase == GamePhase.GENERATING:
		return

	if _flagged[fi] == 1:
		sound_stop.play()
		return

	if _revealed[fi] == 1:
		_try_chord(fi)
		return

	sound_reveal.play()
	match phase:
		GamePhase.WAITING_FIRST:
			if no_guess:
				_start_ng_generation(fi)
			else:
				_place_mines(fi)
				phase = GamePhase.PLAYING
				_start_time_usec = Time.get_ticks_usec()
				game_ui_timer.start()
				_reveal_cell(fi)
		GamePhase.PLAYING:
			_reveal_cell(fi)


# ---- no-guess generation (background Thread) ---------------------------


func _start_ng_generation(fi: int) -> void:
	phase = GamePhase.GENERATING
	_ng_pending_first_click = fi
	no_guess_generating.emit(true)
	_ng_thread = Thread.new()
	_ng_thread.start(_ng_thread_entry.bind(fi))


## Thread body. Runs the pure solver/generator and returns its [Result].
func _ng_thread_entry(fi: int) -> NoGuessGenerator.Result:
	var gen := NoGuessGenerator.new()
	return gen.generate(_result.adjacency, _face_count, _mine_count,
		fi, safe_radius, NO_GUESS_BUDGET_MSEC)


func _finish_ng_generation() -> void:
	var result: NoGuessGenerator.Result = _ng_thread.wait_to_finish()
	_ng_thread = null

	_is_mine = result.is_mine.duplicate()
	_neighbor_count = result.neighbor_count.duplicate()

	_mine_indices = PackedInt32Array()
	for face_id in _face_count:
		if _is_mine[face_id] == 1:
			_mine_indices.append(face_id)
	_mine_count = _mine_indices.size()

	no_guess_generating.emit(false)
	if not result.solvable:
		no_guess = false
		no_guess_warning.emit()

	phase = GamePhase.PLAYING
	_start_time_usec = Time.get_ticks_usec()
	game_ui_timer.start()

	var first_click := _ng_pending_first_click
	_ng_pending_first_click = -1
	_reveal_cell(first_click)


func _reveal_cell(fi: int) -> void:
	if _revealed[fi] == 1 or _flagged[fi] == 1:
		return

	if _is_mine[fi] == 1:
		_game_over(fi)
		return

	var cleared := _manager.flood_clear(
		fi,
		_result.adjacency,
		func(face_idx: int) -> int: return _neighbor_count[face_idx]
	)

	for ci: int in cleared:
		_revealed[ci] = 1
		_cleared_count += 1
		if _neighbor_count[ci] > 0 and _number_renderer:
			_number_renderer.show_number(
				ci, _neighbor_count[ci],
				_result.face_centers[ci],
				_result.face_centers[ci].normalized()
			)

	_manager.flush()
	_emit_stats()
	_check_win()


## Chord: if a revealed cell's flag-count matches its mine-count,
## auto-reveal all unflagged neighbours.
func _try_chord(fi: int) -> void:
	if _neighbor_count[fi] == 0:
		sound_stop.play()
		return

	var flag_count := 0
	var neighbours: Array = _result.adjacency[fi]
	for ni: int in neighbours:
		if _flagged[ni] == 1:
			flag_count += 1

	if flag_count != _neighbor_count[fi]:
		sound_stop.play()
		return
	
	sound_chord.play()

	for ni: int in neighbours:
		if _revealed[ni] == 0 and _flagged[ni] == 0:
			_reveal_cell(ni)


func _on_flag(fi: int) -> void:
	if phase != GamePhase.PLAYING and phase != GamePhase.WAITING_FIRST:
		return
	if _revealed[fi] == 1:
		return

	if _flagged[fi] == 0:
		sound_flag.play()
		_flagged[fi] = 1
		_flagged_count += 1
		_manager.flag_cell(fi)
		if _flag_renderer:
			_flag_renderer.add_flag(fi, _result.face_centers[fi],
				_result.face_centers[fi].normalized())
	else:
		sound_flag.play()
		_flagged[fi] = 0
		_flagged_count -= 1
		_manager.set_cell_state(fi, GoldbergCellManager.CellState.UNOPENED)
		if _flag_renderer:
			_flag_renderer.remove_flag(fi)

	_manager.flush()
	_emit_stats()
	if _is_touch_device():
		HapticsManager.vibrate(50)


func _game_over(triggered_face: int) -> void:
	sound_lost.play()
	phase = GamePhase.LOST
	_final_time_usec = Time.get_ticks_usec() - _start_time_usec
	game_ui_timer.stop()

	_manager.mark_triggered_mine(triggered_face)
	if _mine_renderer:
		var pos := _result.face_centers[triggered_face]
		var norm := pos.normalized()
		_mine_renderer.show_mine(triggered_face, pos, norm)
		_explosion_spawner.spawn(pos, norm)

	for mi: int in _mine_indices:
		if mi == triggered_face:
			continue
		if _flagged[mi] == 1:
			continue
		_manager.set_cell_state(mi, GoldbergCellManager.CellState.MINE_REVEALED)
		if _mine_renderer:
			_mine_renderer.show_mine(mi,
				_result.face_centers[mi],
				_result.face_centers[mi].normalized())

	for fi in _face_count:
		if _flagged[fi] == 1 and _is_mine[fi] == 0:
			_manager.mark_wrong_flag(fi)

	_manager.flush()
	_emit_stats()
	game_lost.emit()
	if _is_touch_device():
		HapticsManager.vibrate_descending()


func _check_win() -> void:
	if _cleared_count >= _face_count - _mine_count:
		phase = GamePhase.WON
		_final_time_usec = Time.get_ticks_usec() - _start_time_usec
		game_ui_timer.stop()
		for mi: int in _mine_indices:
			if _flagged[mi] == 0:
				_flagged[mi] = 1
				_flagged_count += 1
				_manager.flag_cell(mi)
				if _flag_renderer:
					_flag_renderer.add_flag(mi, _result.face_centers[mi],
						_result.face_centers[mi].normalized())
		_manager.flush()
		sound_won.play()
		RecordsManager.update_record(subdivision, mine_ratio, _final_time_usec, no_guess)
		_emit_stats()
		game_won.emit()
		winning_ps.restart()
		if _is_touch_device():
			HapticsManager.vibrate_descending()

## Restart the game with the same settings.
func restart() -> void:
	# Re-evaluate no-guess from global settings: a prior game may have cleared
	# the flag after a generator failure, but the user's intent persists.
	no_guess = GameConfig.is_no_guess_effective()
	_is_mine.fill(0)
	_neighbor_count.fill(0)
	_revealed.fill(0)
	_flagged.fill(0)
	_mine_indices = PackedInt32Array()
	_mine_count = clampi(roundi(_face_count * mine_ratio), 1, _face_count - 1)
	_cleared_count = 0
	_flagged_count = 0
	_manager.reset()
	_manager.flush()
	if _number_renderer:
		_number_renderer.clear_all()
	if _flag_renderer:
		_flag_renderer.clear_all()
	if _mine_renderer:
		_mine_renderer.clear_all()
	phase = GamePhase.WAITING_FIRST
	_start_time_usec = 0
	_final_time_usec = 0
	_emit_stats()
	_emit_tick()

	_explosion_spawner.clear()

	camera.reset_position()


## Total face count for the current board, matching
## [member GoldbergPolyhedron.Result.face_count].
func get_face_count() -> int:
	return _face_count


## World-space face centres for the current board, indexed by face id.
## Intended for read-only use (e.g. raycast resolution).
func get_face_centers() -> PackedVector3Array:
	return _result.face_centers


## Returns true if face [param fi] is a mine.
func is_mine(fi: int) -> bool:
	return _is_mine[fi] == 1


## Returns true if face [param fi] has been revealed.
func is_revealed(fi: int) -> bool:
	return _revealed[fi] == 1


## Returns true if face [param fi] is flagged.
func is_flagged(fi: int) -> bool:
	return _flagged[fi] == 1

## Returns elapsed game time in microseconds.
func get_current_time() -> int:
	if _final_time_usec != 0:
		return _final_time_usec
	if _start_time_usec == 0:
		return 0
	return Time.get_ticks_usec() - _start_time_usec

## Returns face count, mine count, cleared count, flagged count.
func get_stats() -> Dictionary:
	return {
		"face_count":    _face_count,
		"mine_count":    _mine_count,
		"cleared_count": _cleared_count,
		"flagged_count": _flagged_count,
		"current_time": get_current_time()
	}

func _emit_stats() -> void:
	stats_updated.emit(_cleared_count, _flagged_count, _mine_count, _face_count)


func _emit_tick() -> void:
	game_timer_tick.emit(get_current_time())


func _is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available()


func _on_restart_requested() -> void:
	restart()


func _on_exit_requested() -> void:
	_explosion_spawner.clear()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_button_pressed() -> void:
	sound_click.play()
