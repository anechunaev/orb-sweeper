## Reports the device safe-area insets (notches, punch-holes, gesture bars) in
## viewport pixels so UI containers can pad themselves away from system chrome.
## On platforms without insets the values are all zero, leaving layouts
## untouched.
extends Node

signal insets_changed(insets: Vector4)

var insets: Vector4 = Vector4.ZERO


func _ready() -> void:
	get_tree().root.size_changed.connect(_recompute)
	_recompute()


func _recompute() -> void:
	var win_size := DisplayServer.window_get_size()
	if win_size.x <= 0 or win_size.y <= 0:
		return
	var safe := DisplayServer.get_display_safe_area()
	var vp_size := get_viewport().get_visible_rect().size
	var sx := vp_size.x / float(win_size.x)
	var sy := vp_size.y / float(win_size.y)
	var new_insets := Vector4(
		maxf(safe.position.x * sx, 0.0),
		maxf(safe.position.y * sy, 0.0),
		maxf((win_size.x - safe.end.x) * sx, 0.0),
		maxf((win_size.y - safe.end.y) * sy, 0.0)
	)
	if new_insets.is_equal_approx(insets):
		return
	insets = new_insets
	insets_changed.emit(insets)
