## No-guessing mine generator for Orb Sweeper.
##
## Produces a mine layout that can be solved end-to-end using pure logical
## inference from a given first-click tile — no lucky guesses required.
##
## Strategy: generate random layouts and simulate a perfect solver over each
## until one plays out to completion. The solver runs three deduction tiers
## (per-cell, pair subset, global mine-count) over dense PackedArrays, with
## no scene or engine dependencies so it can execute inside a [Thread].
##
## Usage:
## [codeblock]
## var gen := NoGuessGenerator.new()
## var result := gen.generate(adjacency, face_count, mine_count,
##                             first_click, safe_radius, 900)
## if not result.solvable:
##     push_warning("Fell back to random placement after %d attempts" % result.attempts)
## [/codeblock]
class_name NoGuessGenerator
extends RefCounted

## Densities at or above this threshold disable no-guess generation — the
## solver's acceptance rate falls off a cliff and even bounded repair can't
## find solvable configurations within the wall-clock budget. UI consumers
## read this to grey out the "No Guess" option above the cap.
const MAX_DENSITY := 0.3

const MAX_ATTEMPTS := 10000


## Return value of [method generate].
class Result extends RefCounted:
	## 1 = face is a mine; 0 = safe. Length == face_count.
	var is_mine: PackedByteArray
	## Pre-computed neighbor-mine counts per face. Length == face_count.
	var neighbor_count: PackedInt32Array
	## True iff the returned layout is fully solvable by logic from the first click.
	var solvable: bool = false
	## How many full generate-and-solve attempts it took.
	var attempts: int = 0
	## Total wall time spent inside [method generate], in milliseconds.
	var elapsed_msec: int = 0
	## Count of cells the solver could NOT resolve on the best attempt
	## (0 means fully solved; larger = more guessing needed).
	var unresolved_cells: int = 0


var _adj: Array                          # reference to immutable adjacency data
var _n: int                              # total face count
var _mine_count: int
var _safe_radius: int
var _first_click: int

var _is_mine: PackedByteArray            # current attempt's ground truth
var _neighbor_count: PackedInt32Array    # mine count per face

const _S_UNKNOWN := 0
const _S_REVEALED := 1
const _S_MINE := 2
var _state: PackedByteArray

var _c_remaining: PackedInt32Array
var _c_unknowns: Array                   # Array[PackedInt32Array]
var _c_dirty: PackedByteArray            # 1 iff constraint id is in _dirty_queue
var _c_active: PackedByteArray           # 0 once a constraint is fully resolved
var _c_count: int = 0

var _dirty_queue: PackedInt32Array

var _cell_to_c: Array                    # Array[PackedInt32Array]

var _unknown_left: int = 0               # cells still in _S_UNKNOWN
var _mines_marked: int = 0               # cells in _S_MINE
var _safe_zone: PackedByteArray          # 1 = excluded from mine placement


## Generate a mine layout that is fully solvable by logic starting from
## [param first_click].
##
## [param adjacency] — [code]Array[Array[int]][/code] from [member
## GoldbergPolyhedron.Result.adjacency]; treated as immutable.
## [br]
## [param face_count] — total faces.
## [br]
## [param mine_count] — desired mine count; will be clamped to the number
## of candidate cells outside the safe zone.
## [br]
## [param first_click] — face index the player clicked first.
## [br]
## [param safe_radius] — BFS safe-zone radius around the first click.
## [br]
## [param budget_msec] — maximum wall time to spend retrying; once exceeded
## the best attempt so far is returned with [member Result.solvable] false.
func generate(adjacency: Array,
			  face_count: int,
			  mine_count: int,
			  first_click: int,
			  safe_radius: int,
			  budget_msec: int) -> Result:
	var start_usec := Time.get_ticks_usec()

	_adj = adjacency
	_n = face_count
	_mine_count = mine_count
	_first_click = first_click
	_safe_radius = safe_radius

	_safe_zone = MinePlacer.build_safe_zone(_adj, _n, _first_click, _safe_radius)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var result := Result.new()
	result.unresolved_cells = face_count + 1   # sentinel, beaten by any attempt
	var deadline_usec := start_usec + budget_msec * 1000

	var attempt := 0
	while attempt < MAX_ATTEMPTS:
		attempt += 1
		_is_mine = MinePlacer.place_mines(_n, _safe_zone, _mine_count, rng)
		_neighbor_count = MinePlacer.compute_neighbor_counts(_adj, _n, _is_mine)
		_init_solver_state()
		var solved := _run_solver()
		var unresolved := _unknown_left

		if solved:
			result.is_mine = _is_mine.duplicate()
			result.neighbor_count = _neighbor_count.duplicate()
			result.solvable = true
			result.attempts = attempt
			result.unresolved_cells = 0
			result.elapsed_msec = int(float(Time.get_ticks_usec() - start_usec) / 1000)
			return result

		if unresolved < result.unresolved_cells:
			result.is_mine = _is_mine.duplicate()
			result.neighbor_count = _neighbor_count.duplicate()
			result.unresolved_cells = unresolved
			result.attempts = attempt

		if Time.get_ticks_usec() >= deadline_usec:
			break

	result.solvable = false
	result.elapsed_msec = int(float(Time.get_ticks_usec() - start_usec) / 1000)
	return result


func _init_solver_state() -> void:
	_state = PackedByteArray()
	_state.resize(_n)

	_c_remaining = PackedInt32Array()
	_c_unknowns = []
	_c_dirty = PackedByteArray()
	_c_active = PackedByteArray()
	_dirty_queue = PackedInt32Array()
	_c_count = 0

	_cell_to_c = []
	_cell_to_c.resize(_n)
	for i in _n:
		_cell_to_c[i] = PackedInt32Array()

	_unknown_left = _n
	_mines_marked = 0


func _run_solver() -> bool:
	_reveal_face(_first_click)

	while _unknown_left > 0:
		if _propagate_dirty():
			continue
		if _subset_pass():
			continue
		if _global_count_pass():
			continue
		break   # plateau — solver can't progress without guessing

	return _unknown_left == 0


func _propagate_dirty() -> bool:
	var made_progress := false
	while _dirty_queue.size() > 0:
		var last := _dirty_queue.size() - 1
		var ci: int = _dirty_queue[last]
		_dirty_queue.resize(last)
		_c_dirty[ci] = 0
		if _c_active[ci] == 0:
			continue
		if _apply_tier1(ci):
			made_progress = true
	return made_progress


func _enqueue_dirty(ci: int) -> void:
	if _c_dirty[ci] == 1:
		return
	_c_dirty[ci] = 1
	_dirty_queue.append(ci)


func _apply_tier1(ci: int) -> bool:
	var unknowns: PackedInt32Array = _c_unknowns[ci]
	var k := unknowns.size()
	if k == 0:
		_c_active[ci] = 0
		return false

	var rem := _c_remaining[ci]
	if rem == 0:
		var snapshot := unknowns.duplicate()
		for cell: int in snapshot:
			if _state[cell] == _S_UNKNOWN:
				_reveal_face(cell)
		_c_active[ci] = 0
		return true

	if rem == k:
		var snapshot2 := unknowns.duplicate()
		for cell: int in snapshot2:
			if _state[cell] == _S_UNKNOWN:
				_mark_mine(cell)
		_c_active[ci] = 0
		return true

	return false


func _subset_pass() -> bool:
	for a in _c_count:
		if _c_active[a] == 0:
			continue
		var ua: PackedInt32Array = _c_unknowns[a]
		if ua.size() == 0:
			_c_active[a] = 0
			continue

		var seen := {}
		for cell: int in ua:
			var list: PackedInt32Array = _cell_to_c[cell]
			for b: int in list:
				if b == a or _c_active[b] == 0 or seen.has(b):
					continue
				seen[b] = true

				var ub: PackedInt32Array = _c_unknowns[b]
				if _try_subset(ua, _c_remaining[a], ub, _c_remaining[b]):
					return true
				if _try_subset(ub, _c_remaining[b], ua, _c_remaining[a]):
					return true

	return false


## If `small` ⊆ `big`, the residual cells in `big \ small` must contain
## exactly `(big_rem - small_rem)` mines. Applies a deduction when that
## residual count forces all residual cells to be safe or all to be mines.
func _try_subset(small: PackedInt32Array,
				 small_rem: int,
				 big: PackedInt32Array,
				 big_rem: int) -> bool:
	if small.size() == 0 or small.size() >= big.size():
		return false
	if not _is_subset(small, big):
		return false

	var residual_count := big.size() - small.size()
	var residual_rem := big_rem - small_rem
	if residual_rem < 0 or residual_rem > residual_count:
		return false   # contradiction — shouldn't happen on valid boards

	if residual_rem == 0:
		# Every big-only cell is safe.
		var snapshot := big.duplicate()
		var revealed_any := false
		for cell: int in snapshot:
			if _contains(small, cell):
				continue
			if _state[cell] == _S_UNKNOWN:
				_reveal_face(cell)
				revealed_any = true
		return revealed_any

	if residual_rem == residual_count:
		var snapshot2 := big.duplicate()
		var marked_any := false
		for cell: int in snapshot2:
			if _contains(small, cell):
				continue
			if _state[cell] == _S_UNKNOWN:
				_mark_mine(cell)
				marked_any = true
		return marked_any

	return false


static func _is_subset(small: PackedInt32Array, big: PackedInt32Array) -> bool:
	for x: int in small:
		if not _contains(big, x):
			return false
	return true


static func _contains(arr: PackedInt32Array, x: int) -> bool:
	for y: int in arr:
		if y == x:
			return true
	return false


func _global_count_pass() -> bool:
	var mines_left := _mine_count - _mines_marked
	if mines_left < 0:
		return false

	if mines_left == 0:
		# All remaining unknowns are safe.
		var revealed_any := false
		# Snapshot to avoid mutating while iterating.
		var pending := PackedInt32Array()
		for fi in _n:
			if _state[fi] == _S_UNKNOWN:
				pending.append(fi)
		for fi: int in pending:
			if _state[fi] == _S_UNKNOWN:
				_reveal_face(fi)
				revealed_any = true
		return revealed_any

	if mines_left == _unknown_left:
		var pending2 := PackedInt32Array()
		for fi in _n:
			if _state[fi] == _S_UNKNOWN:
				pending2.append(fi)
		for fi: int in pending2:
			if _state[fi] == _S_UNKNOWN:
				_mark_mine(fi)
		return true

	return false


## Reveal [param cell] and (if its number is 0) flood-fill its neighbours,
## mirroring [method GoldbergCellManager.flood_clear].
## Implemented iteratively — recursion could blow the GDScript call stack on
## large-subdivision spheres with long zero-count chains.
func _reveal_face(cell: int) -> void:
	if _state[cell] != _S_UNKNOWN:
		return

	var queue := PackedInt32Array()
	queue.append(cell)
	var head := 0
	while head < queue.size():
		var fi: int = queue[head]
		head += 1
		if _state[fi] != _S_UNKNOWN:
			continue
		_state[fi] = _S_REVEALED
		_unknown_left -= 1
		_notify_cell_resolved(fi, false)

		var number := _neighbor_count[fi]
		if number > 0:
			_add_constraint_for(fi, number)
		else:
			var neighbours: Array = _adj[fi]
			for ni: int in neighbours:
				if _state[ni] == _S_UNKNOWN:
					queue.append(ni)


func _mark_mine(cell: int) -> void:
	if _state[cell] != _S_UNKNOWN:
		return
	_state[cell] = _S_MINE
	_unknown_left -= 1
	_mines_marked += 1
	_notify_cell_resolved(cell, true)


## Remove [param cell] from every constraint that listed it as unknown.
## If [param is_mine] is true, decrement each such constraint's remaining count.
func _notify_cell_resolved(cell: int, is_mine: bool) -> void:
	var list: PackedInt32Array = _cell_to_c[cell]
	for ci: int in list:
		if _c_active[ci] == 0:
			continue
		_remove_cell_from_constraint(ci, cell)
		if is_mine:
			_c_remaining[ci] -= 1
		_enqueue_dirty(ci)
	# Clear the inverted-index entry — this cell is resolved and can never
	# appear in another constraint's unknowns.
	_cell_to_c[cell] = PackedInt32Array()


func _remove_cell_from_constraint(ci: int, cell: int) -> void:
	var unknowns: PackedInt32Array = _c_unknowns[ci]
	var n := unknowns.size()
	for i in n:
		if unknowns[i] == cell:
			# Swap with last, then shrink.
			if i != n - 1:
				unknowns[i] = unknowns[n - 1]
			unknowns.resize(n - 1)
			_c_unknowns[ci] = unknowns
			return


## Create a new constraint rooted at a freshly revealed numbered cell.
func _add_constraint_for(cell: int, number: int) -> void:
	var neighbours: Array = _adj[cell]
	var unknowns := PackedInt32Array()
	var known_mines := 0
	for ni: int in neighbours:
		var s := _state[ni]
		if s == _S_UNKNOWN:
			unknowns.append(ni)
		elif s == _S_MINE:
			known_mines += 1

	var remaining := number - known_mines
	if unknowns.size() == 0:
		return

	var ci := _c_count
	_c_count += 1
	_c_remaining.append(remaining)
	_c_unknowns.append(unknowns)
	_c_dirty.append(0)
	_c_active.append(1)

	for cu: int in unknowns:
		var entry: PackedInt32Array = _cell_to_c[cu]
		entry.append(ci)
		_cell_to_c[cu] = entry

	_enqueue_dirty(ci)
