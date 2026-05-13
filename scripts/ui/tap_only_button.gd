## Button subclass that only fires `tapped` when the pointer is released
## without exceeding a small drag threshold from the press origin. Used for
## bottom-of-screen buttons that would otherwise be triggered by Android
## gesture-navigation swipes passing over them.
class_name TapOnlyButton
extends Button

## Emitted on release when the press did not drag past
## [member drag_cancel_threshold_px].
signal tapped()

@export var drag_cancel_threshold_px: float = 16.0

var _press_pos: Vector2 = Vector2.INF
var _drag_cancelled: bool = false


func _ready() -> void:
	button_down.connect(_on_button_down)
	gui_input.connect(_on_gui_input)
	pressed.connect(_on_pressed)


func _on_button_down() -> void:
	_press_pos = get_local_mouse_position()
	_drag_cancelled = false


func _on_gui_input(event: InputEvent) -> void:
	if _drag_cancelled or not button_pressed:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _press_pos.distance_to(event.position) > drag_cancel_threshold_px:
			_drag_cancelled = true


func _on_pressed() -> void:
	if not _drag_cancelled:
		tapped.emit()
	_drag_cancelled = false
