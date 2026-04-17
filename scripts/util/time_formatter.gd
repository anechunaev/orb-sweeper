## Small utility for rendering gameplay durations as human-readable strings.
class_name TimeFormatter


## Formats a duration in microseconds as "X.X sec".
## Returns [code]"--- sec"[/code] when [param usec] is non-positive so the
## UI can show a placeholder for empty records.
static func format_time(usec: int) -> String:
	if usec > 0:
		return str(roundi(usec / 100_000.0) / 10.0) + " sec"
	return "--- sec"
