## Small utility for rendering efficiency scores as human-readable strings.
class_name EfficiencyFormatter


## Formats an efficiency percentage as "84%".
## Returns [code]"---"[/code] when [param percent] is non-positive so the UI can
## show a placeholder for missing records and runs that never started.
static func format_efficiency(percent: float) -> String:
	if percent > 0.0:
		return str(roundi(percent)) + "%"
	return "---"
