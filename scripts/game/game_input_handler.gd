## Handles all input routing for the game: raycasting screen positions to face
## indices, long-press detection for flagging, and pointer callbacks from
## [OrbitCamera].
class_name GameInputHandler
extends Node

## Emitted when the player commits a reveal gesture (tap or left click).
signal face_revealed(face_index: int)
## Emitted when the player commits a flag gesture (long-press or right click).
signal face_flagged(face_index: int)

@export var camera: OrbitCamera
@export var game: SphericalMinesweeper
@export var menu_controller: GameMenuController

@export_group("Input")
## Hold duration (seconds) for flag gesture on touch.
@export var long_press_time: float = 0.4

var _press_start_time: float = 0.0
var _press_face: int = -1
var _awaiting_release: bool = false


func _ready() -> void:
	if camera:
		if camera.has_signal("pointer_released"):
			camera.pointer_released.connect(_on_pointer_released)
			camera.pointer_pressed.connect(_on_pointer_pressed)
			camera.drag_started.connect(_on_drag_started)


func _process(_delta: float) -> void:
	if _awaiting_release and _press_face >= 0:
		if Time.get_ticks_msec() / 1000.0 - _press_start_time >= long_press_time:
			face_flagged.emit(_press_face)
			_awaiting_release = false
			_press_face = -1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if camera and camera.is_drag_active():
				return
			var fi := _raycast(mb.position)
			if fi >= 0:
				face_flagged.emit(fi)
			get_viewport().set_input_as_handled()


## Discard any in-flight press / long-press gesture so the next user input
## starts fresh. Call when a modal UI opens mid-press.
func cancel_input() -> void:
	_awaiting_release = false
	_press_face = -1


func _raycast(screen_pos: Vector2) -> int:
	var space := game.get_world_3d().direct_space_state
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var to := from + dir * 100.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return -1

	var hit_pos: Vector3 = hit["position"]
	return _closest_face(hit_pos)


func _closest_face(world_pos: Vector3) -> int:
	var best := -1
	var best_dot := -2.0
	var dir := (world_pos - Vector3.ZERO).normalized()

	var face_count := game.get_face_count()
	var face_centers := game.get_face_centers()
	for fi in face_count:
		var d := dir.dot(face_centers[fi].normalized())
		if d > best_dot:
			best_dot = d
			best = fi
	return best


func _on_drag_started() -> void:
	if menu_controller.is_menu_visible():
		return
	_awaiting_release = false
	_press_face = -1


func _on_pointer_pressed(screen_pos: Vector2) -> void:
	if game.phase == SphericalMinesweeper.GamePhase.WON \
			or game.phase == SphericalMinesweeper.GamePhase.LOST:
		return
	if menu_controller.is_menu_visible():
		return
	if not _is_touch_device():
		return

	var fi := _raycast(screen_pos)
	if fi < 0:
		return

	_press_face = fi
	_press_start_time = Time.get_ticks_msec() / 1000.0
	_awaiting_release = true


func _on_pointer_released(was_drag: bool) -> void:
	if was_drag:
		_awaiting_release = false
		_press_face = -1
		return

	if game.phase == SphericalMinesweeper.GamePhase.WON \
			or game.phase == SphericalMinesweeper.GamePhase.LOST:
		return
	if menu_controller.is_menu_visible():
		return

	if _is_touch_device():
		if _awaiting_release and _press_face >= 0:
			var fi := _press_face
			_awaiting_release = false
			_press_face = -1
			face_revealed.emit(fi)
		else:
			_awaiting_release = false
			_press_face = -1
	else:
		var vp := get_viewport()
		if not vp:
			return
		var screen_pos := vp.get_mouse_position()
		var fi := _raycast(screen_pos)
		if fi >= 0:
			face_revealed.emit(fi)


static func _is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available()
