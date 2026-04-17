## Headless smoke + benchmark for [NoGuessGenerator].
##
## Generates [member runs_per_preset] boards for each classic preset (and a
## representative custom config near the density cap), then prints solvable
## rate, mean / p95 / max generation time, and average attempts. Quits the
## scene tree on completion so it can run from CLI:
## [codeblock]
## godot --headless --quit-after 1 --path . scenes/tests/test_no_guess_generator.tscn
## [/codeblock]
extends Node

@export var runs_per_preset: int = 100
@export var budget_msec: int = 900
@export var safe_radius: int = 1


func _ready() -> void:
	print("[no-guess test] runs/preset = %d, budget = %d ms" % [runs_per_preset, budget_msec])

	var configs: Array = []
	for preset: Dictionary in DifficultyPresets.CLASSIC:
		configs.append({
			"label": "Classic %s" % preset["label"],
			"subdivision": int(preset["subdivision"]),
			"density": float(preset["density"]),
		})
	# Representative custom point just under the 30% gate — the worst case
	# the generator is allowed to attempt.
	configs.append({
		"label": "Custom s=5 d=0.29",
		"subdivision": 5,
		"density": 0.29,
	})

	var any_failed := false
	for cfg: Dictionary in configs:
		if not _run_config(cfg):
			any_failed = true

	if any_failed:
		push_error("[no-guess test] one or more configs reported solvable=false")

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

	var times := PackedInt32Array()
	var attempts_total := 0
	var solved_count := 0
	var max_unresolved := 0

	for run in runs_per_preset:
		var first_click := rng.randi_range(0, face_count - 1)
		var gen := NoGuessGenerator.new()
		var result := gen.generate(poly.adjacency, face_count, mine_count,
			first_click, safe_radius, budget_msec)
		times.append(result.elapsed_msec)
		attempts_total += result.attempts
		if result.solvable:
			solved_count += 1
		else:
			max_unresolved = maxi(max_unresolved, result.unresolved_cells)

	var mean_ms := _mean(times)
	var p95_ms := _percentile(times, 0.95)
	var max_ms := _max(times)
	var avg_attempts := float(attempts_total) / float(runs_per_preset)
	var solvable_rate := 100.0 * float(solved_count) / float(runs_per_preset)

	print("[%s] faces=%d mines=%d  solved %d/%d (%.1f%%)  mean=%dms p95=%dms max=%dms  avg-attempts=%.1f  worst-unresolved=%d" % [
		label, face_count, mine_count,
		solved_count, runs_per_preset, solvable_rate,
		mean_ms, p95_ms, max_ms,
		avg_attempts, max_unresolved,
	])

	return solved_count == runs_per_preset


static func _mean(samples: PackedInt32Array) -> int:
	if samples.size() == 0:
		return 0
	var s := 0
	for v in samples:
		s += v
	return s / samples.size()


static func _max(samples: PackedInt32Array) -> int:
	var m := 0
	for v in samples:
		if v > m:
			m = v
	return m


static func _percentile(samples: PackedInt32Array, q: float) -> int:
	if samples.size() == 0:
		return 0
	var sorted := samples.duplicate()
	sorted.sort()
	var idx := clampi(int(ceil(q * sorted.size())) - 1, 0, sorted.size() - 1)
	return sorted[idx]
