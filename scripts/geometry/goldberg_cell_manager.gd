## Manages per-face cell state for a [GoldbergPolyhedron] via a DataTexture.
##
## Drives the [code]goldberg_cell.gdshader[/code] — each face is one pixel in a
## 1×N R8 texture.  States map to byte values 0‒5.
##
## [codeblock]
## var result  := GoldbergPolyhedron.generate(3, 2.0)
## var shader  := preload("res://shaders/goldberg_cell.gdshader")
## var manager := GoldbergCellManager.create(result, shader)
## $MeshInstance3D.mesh              = result.mesh
## $MeshInstance3D.material_override = manager.material
##
## manager.clear_cell(42)
## manager.flag_cell(7)
## manager.reveal_mine(13)
## [/codeblock]
class_name GoldbergCellManager
extends RefCounted

enum CellState {
	UNOPENED       = 0,
	CLEARED        = 1,
	FLAGGED        = 2,
	MINE_REVEALED  = 3,   ## Unflagged mine shown on game over (neutral color)
	TRIGGERED_MINE = 4,   ## The mine the player clicked (red)
	WRONG_FLAG     = 5,   ## Flag on a non-mine tile (red)
}

## The [ShaderMaterial] to assign to your [MeshInstance3D].
var material: ShaderMaterial

## Total face count (matches [member GoldbergPolyhedron.Result.face_count]).
var face_count: int

var _image:   Image
var _texture: ImageTexture
var _states:  PackedByteArray      # fast CPU-side mirror
var _dirty:   bool = false

# Precomputed colors for the 6 states (R channel only, FORMAT_R8).
static var _state_colors: Array = [
	Color(0.0, 0.0, 0.0, 1.0),             # UNOPENED        → 0
	Color(1.0 / 255.0, 0.0, 0.0, 1.0),     # CLEARED         → 1
	Color(2.0 / 255.0, 0.0, 0.0, 1.0),     # FLAGGED         → 2
	Color(3.0 / 255.0, 0.0, 0.0, 1.0),     # MINE_REVEALED   → 3
	Color(4.0 / 255.0, 0.0, 0.0, 1.0),     # TRIGGERED_MINE  → 4
	Color(5.0 / 255.0, 0.0, 0.0, 1.0),     # WRONG_FLAG      → 5
]

## Create a new cell manager wired to the given Goldberg [param result] and
## [param shader] resource.  All cells start as [constant UNOPENED].
static func create(result: GoldbergPolyhedron.Result, shader: Shader) -> GoldbergCellManager:
	var mgr := GoldbergCellManager.new()
	mgr.face_count = result.face_count

	# CPU-side state mirror
	mgr._states = PackedByteArray()
	mgr._states.resize(result.face_count)
	mgr._states.fill(CellState.UNOPENED)

	# 1×N R8 image  (one pixel per face)
	mgr._image = Image.create(result.face_count, 1, false, Image.FORMAT_R8)
	mgr._image.fill(Color(0, 0, 0, 1))       # all unopened

	mgr._texture = ImageTexture.create_from_image(mgr._image)

	mgr.material = ShaderMaterial.new()
	mgr.material.shader = shader
	mgr.material.set_shader_parameter("cell_states", mgr._texture)

	return mgr

## Set a cell to any [enum CellState].
func set_cell_state(face_idx: int, state: CellState) -> void:
	if face_idx < 0 or face_idx >= face_count:
		return
	_states[face_idx] = state
	_image.set_pixel(face_idx, 0, _state_colors[state])
	_dirty = true

## Convenience: flag a cell.
func flag_cell(face_idx: int) -> void:
	set_cell_state(face_idx, CellState.FLAGGED)

## Convenience: reveal a mine (neutral color, for game-over display).
func reveal_mine(face_idx: int) -> void:
	set_cell_state(face_idx, CellState.MINE_REVEALED)

## Convenience: mark the mine the player clicked (red highlight).
func mark_triggered_mine(face_idx: int) -> void:
	set_cell_state(face_idx, CellState.TRIGGERED_MINE)

## Convenience: mark a wrong flag (flag on non-mine, red highlight).
func mark_wrong_flag(face_idx: int) -> void:
	set_cell_state(face_idx, CellState.WRONG_FLAG)

## Read back the current state of a cell.
func get_cell_state(face_idx: int) -> CellState:
	return _states[face_idx] as CellState

## Set every cell to [param state].
func set_all(state: CellState) -> void:
	_states.fill(state)
	_image.fill(_state_colors[state])
	_dirty = true

## Reset all cells to [constant UNOPENED].
func reset() -> void:
	set_all(CellState.UNOPENED)

## Flood-clear from [param start] using the Goldberg adjacency data.
## Calls [param count_fn] to get the mine neighbour count for a face index.
## Returns the list of face indices that were cleared.
## [br][br]
## [param count_fn] signature: [code]func(face_idx: int) -> int[/code]
func flood_clear(start: int,
				 adjacency: Array,
				 count_fn: Callable) -> PackedInt32Array:
	var cleared := PackedInt32Array()
	var queue   := [start]
	var visited := {}
	visited[start] = true

	while queue.size() > 0:
		var fi: int = queue.pop_front()
		if _states[fi] != CellState.UNOPENED:
			continue

		set_cell_state(fi, CellState.CLEARED)
		cleared.append(fi)

		if count_fn.call(fi) == 0:
			var neighbours: Array = adjacency[fi]
			for ni: int in neighbours:
				if not visited.has(ni):
					visited[ni] = true
					queue.append(ni)

	return cleared

## Push pending pixel changes to the GPU.
## [br]
## Single-cell helpers mark the texture as dirty but do not upload.
## Call [method flush] after batching changes, or use [method process] each frame.
func flush() -> void:
	if _dirty:
		_texture.update(_image)
		_dirty = false

## Convenience: call in [method Node._process] to auto-flush.
func process() -> void:
	flush()
