## Pure helpers for building a mine layout on a Goldberg sphere.
##
## Used by both the regular game path ([SphericalMinesweeper]) and the
## no-guess solver ([NoGuessGenerator]), so the BFS safe-zone, Fisher-Yates
## shuffle, and neighbor-count passes have a single definition.
class_name MinePlacer


## Return a byte mask where [code]1[/code] marks every face within
## [param safe_radius] BFS hops of [param first_click] (inclusive).
static func build_safe_zone(adjacency: Array,
							face_count: int,
							first_click: int,
							safe_radius: int) -> PackedByteArray:
	var safe := PackedByteArray()
	safe.resize(face_count)
	safe[first_click] = 1

	var frontier := PackedInt32Array()
	frontier.append(first_click)

	for _hop in safe_radius:
		var next_frontier := PackedInt32Array()
		for fi: int in frontier:
			var neighbours: Array = adjacency[fi]
			for ni: int in neighbours:
				if safe[ni] == 0:
					safe[ni] = 1
					next_frontier.append(ni)
		frontier = next_frontier

	return safe


## Randomly place [param mine_count] mines on faces whose [param safe_zone]
## entry is 0. Returns a 1-byte-per-face mask (1 = mine). [param mine_count]
## is clamped to the candidate pool size.
static func place_mines(face_count: int,
						safe_zone: PackedByteArray,
						mine_count: int,
						rng: RandomNumberGenerator) -> PackedByteArray:
	var candidates := PackedInt32Array()
	for fi in face_count:
		if safe_zone[fi] == 0:
			candidates.append(fi)

	var target := mini(mine_count, candidates.size())

	# Partial Fisher-Yates: we only need the first `target` picks.
	var last := candidates.size() - 1
	for i in target:
		var j := rng.randi_range(i, last)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var is_mine := PackedByteArray()
	is_mine.resize(face_count)
	for i in target:
		is_mine[candidates[i]] = 1

	return is_mine


## Compute the mine-neighbour count for every face given an [param is_mine]
## mask and [param adjacency].
static func compute_neighbor_counts(adjacency: Array,
									face_count: int,
									is_mine: PackedByteArray) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(face_count)
	for fi in face_count:
		var count := 0
		var neighbours: Array = adjacency[fi]
		for ni: int in neighbours:
			count += is_mine[ni]
		counts[fi] = count
	return counts
