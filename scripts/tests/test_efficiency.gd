## Headless check for [method MinePlacer.compute_min_clicks] — the 3BV value
## that forms the numerator of the efficiency score.
##
## For every generated board it cross-checks the BFS implementation against an
## independent union-find reference, and against a simulated reveal-only
## playthrough that must clear the whole board in exactly that many clicks.
## Quits the scene tree on completion so it can run from CLI:
## [codeblock]
## godot --headless --quit-after 1 --path . scenes/tests/test_efficiency.tscn
## [/codeblock]
extends Node

@export var runs_per_config: int = 25
@export var safe_radius: int = 1


func _ready() -> void:
	print("[efficiency test] runs/config = %d" % runs_per_config)

	var configs: Array = []
	for preset: Dictionary in DifficultyPresets.CLASSIC:
		configs.append({
			"label": "Classic %s" % preset["label"],
			"subdivision": int(preset["subdivision"]),
			"density": float(preset["density"]),
		})
	# Sparse board: almost everything is one cascade.
	configs.append({ "label": "Sparse s=5 d=0.02", "subdivision": 5, "density": 0.02 })
	# Dense board: almost every cell is an isolated number.
	configs.append({ "label": "Dense  s=5 d=0.45", "subdivision": 5, "density": 0.45 })

	var any_failed := false
	for cfg: Dictionary in configs:
		if not _run_config(cfg):
			any_failed = true

	if any_failed:
		push_error("[efficiency test] one or more configs failed")

	get_tree().quit(0 if not any_failed else 1)


func _run_config(cfg: Dictionary) -> bool:
	var subdivision: int = cfg["subdivision"]
	var density: float = cfg["density"]
	var label: String = cfg["label"]

	var poly := GoldbergPolyhedron.generate(subdivision, 1.0)
	var face_count := poly.face_count
	var mine_count := clampi(roundi(face_count * density), 1, face_count - 1)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var failures := 0
	var min_clicks_total := 0
	var greedy_total := 0

	for _run in runs_per_config:
		var first_click := rng.randi_range(0, face_count - 1)
		var safe_zone := MinePlacer.build_safe_zone(
			poly.adjacency, face_count, first_click, safe_radius)
		var is_mine := MinePlacer.place_mines(face_count, safe_zone, mine_count, rng)
		var counts := MinePlacer.compute_neighbor_counts(poly.adjacency, face_count, is_mine)

		var non_mine := face_count - mine_count
		var min_clicks := MinePlacer.compute_min_clicks(
			poly.adjacency, face_count, is_mine, counts)
		var reference := _reference_min_clicks(poly.adjacency, face_count, is_mine, counts)
		var optimal := _simulate(poly.adjacency, face_count, is_mine, counts, true)
		var greedy := _simulate(poly.adjacency, face_count, is_mine, counts, false)

		min_clicks_total += min_clicks
		greedy_total += greedy["clicks"]

		if min_clicks != reference:
			push_error("[%s] 3BV %d != union-find reference %d" % [label, min_clicks, reference])
			failures += 1
		if optimal["clicks"] != min_clicks:
			push_error("[%s] optimal playthrough took %d clicks, 3BV says %d" % [
				label, optimal["clicks"], min_clicks])
			failures += 1
		if optimal["cleared"] != non_mine:
			push_error("[%s] optimal playthrough cleared %d/%d non-mine cells" % [
				label, optimal["cleared"], non_mine])
			failures += 1
		if min_clicks < 1 or min_clicks > non_mine:
			push_error("[%s] 3BV %d out of range 1..%d" % [label, min_clicks, non_mine])
			failures += 1
		if greedy["clicks"] < min_clicks:
			push_error("[%s] greedy order beat 3BV: %d < %d" % [
				label, greedy["clicks"], min_clicks])
			failures += 1

	var mean_min := float(min_clicks_total) / float(runs_per_config)
	var mean_greedy := float(greedy_total) / float(runs_per_config)
	print("[%s] faces=%d mines=%d  mean 3BV=%.1f  mean greedy=%.1f  failures=%d" % [
		label, face_count, mine_count, mean_min, mean_greedy, failures])

	return failures == 0


## Independent 3BV reference: count cascade components with union-find, then
## add every numbered cell that no cascade touches.
static func _reference_min_clicks(adjacency: Array, face_count: int,
		is_mine: PackedByteArray, counts: PackedInt32Array) -> int:
	var parent: Array[int] = []
	parent.resize(face_count)
	for fi in face_count:
		parent[fi] = fi

	for fi in face_count:
		if is_mine[fi] == 1 or counts[fi] != 0:
			continue
		var neighbours: Array = adjacency[fi]
		for ni: int in neighbours:
			if is_mine[ni] == 0 and counts[ni] == 0:
				var ra := _find(parent, fi)
				var rb := _find(parent, ni)
				if ra != rb:
					parent[ra] = rb

	var roots := {}
	for fi in face_count:
		if is_mine[fi] == 0 and counts[fi] == 0:
			roots[_find(parent, fi)] = true

	var clicks: int = roots.size()
	for fi in face_count:
		if is_mine[fi] == 1 or counts[fi] == 0:
			continue
		var touches_cascade := false
		var neighbours: Array = adjacency[fi]
		for ni: int in neighbours:
			if is_mine[ni] == 0 and counts[ni] == 0:
				touches_cascade = true
				break
		if not touches_cascade:
			clicks += 1

	return clicks


static func _find(parent: Array[int], fi: int) -> int:
	var root := fi
	while parent[root] != root:
		root = parent[root]
	while parent[fi] != root:
		var next := parent[fi]
		parent[fi] = root
		fi = next
	return root


## Play the board with reveals only, using the same cascade rule as
## [method GoldbergCellManager.flood_clear]. With [param openings_first] the
## cascades are clicked before the leftover numbers (the optimal order);
## without it, cells are clicked in plain index order (an upper bound).
static func _simulate(adjacency: Array, face_count: int,
		is_mine: PackedByteArray, counts: PackedInt32Array,
		openings_first: bool) -> Dictionary:
	var revealed := PackedByteArray()
	revealed.resize(face_count)
	var clicks := 0
	var cleared := 0

	var passes: Array[bool] = [false]
	if openings_first:
		passes = [true, false]

	for cascades_only: bool in passes:
		for fi in face_count:
			if is_mine[fi] == 1 or revealed[fi] == 1:
				continue
			if cascades_only and counts[fi] != 0:
				continue

			clicks += 1
			var queue := PackedInt32Array()
			queue.append(fi)
			revealed[fi] = 1
			cleared += 1
			var head := 0
			while head < queue.size():
				var ci := queue[head]
				head += 1
				if counts[ci] != 0:
					continue
				var neighbours: Array = adjacency[ci]
				for ni: int in neighbours:
					if revealed[ni] == 0:
						revealed[ni] = 1
						cleared += 1
						queue.append(ni)

	return { "clicks": clicks, "cleared": cleared }
