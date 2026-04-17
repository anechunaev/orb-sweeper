## Orbit camera that flies freely around a central point (the sphere).
##
## Uses quaternion rotation — no gimbal lock, no pole restrictions.
## Supports touch (drag to orbit, pinch to zoom) and mouse (LMB drag,
## wheel zoom).  Has smooth inertia for both rotation and zoom, and a
## minimum drag distance to prevent accidental clicks.
##
## Attach to a [Camera3D] node.  The camera always looks at [member target].
class_name OrbitCamera
extends Camera3D

## World-space point the camera orbits around.
@export var target: Vector3 = Vector3.ZERO

## Starting distance from target.
@export var distance: float = 5.0
## Closest the camera can zoom in.
@export var min_distance: float = 2.0
## Farthest the camera can zoom out.
@export var max_distance: float = 20.0

## Orbit sensitivity (radians per pixel of drag).
@export var orbit_sensitivity: float = 0.005
## Pinch-zoom sensitivity.
@export var pinch_sensitivity: float = 0.02
## Mouse-wheel zoom step.
@export var wheel_zoom_step: float = 0.5

## How quickly rotation inertia decays (0 = instant stop, 0.98 = very floaty).
@export_range(0.0, 0.99) var inertia_damping: float = 0.92
## Below this speed (rad/s) inertia stops completely.
@export var inertia_cutoff: float = 0.005
## Zoom inertia damping.
@export_range(0.0, 0.99) var zoom_damping: float = 0.85

## Minimum drag distance in pixels before the gesture counts as an orbit.
@export var min_drag_distance: float = 8.0

## Camera orientation as a quaternion — rotates the initial camera
## position (0, 0, distance) around the target.
var _orientation: Quaternion = Quaternion.IDENTITY

## Angular velocity for inertia (axis-angle stored as a vector whose
## length = angular speed in rad/s, direction = rotation axis).
var _angular_velocity: Vector3 = Vector3.ZERO

var _velocity_zoom: float = 0.0

# -- touch tracking --
var _touches: Dictionary = {}
var _prev_touches: Dictionary = {}
var _drag_origin: Vector2 = Vector2.ZERO
var _drag_confirmed: bool = false

# -- mouse tracking --
var _mouse_dragging: bool  = false
var _mouse_origin: Vector2 = Vector2.ZERO
var _mouse_confirmed: bool = false
var _mouse_prev: Vector2   = Vector2.ZERO

# -- pinch state --
var _pinch_start_dist: float = 0.0

var _is_dragging_enabled: bool = true

## Emitted once per gesture when a press crosses [member min_drag_distance]
## and is reclassified from a tap into an orbit drag.
signal drag_started
## Emitted when a primary pointer is pressed down (mouse LMB or first touch).
signal pointer_pressed(position: Vector2)
## Emitted on pointer release. [param was_drag] is true if the gesture was
## classified as a drag (i.e. [signal drag_started] fired for it).
signal pointer_released(was_drag: bool)

## Reconfigure zoom distance and its min/max bounds in one call.
func set_distance(dist: float, min_dist: float, max_dist: float) -> void:
	distance = dist
	min_distance = min_dist
	max_distance = max_dist

## Enable or disable drag/zoom input handling. Useful while a modal UI is open.
func toggle_input_handling(toggle: bool) -> void:
	_is_dragging_enabled = toggle

## Rebuild the internal orientation quaternion from the current
## [member global_position] → [member target] vector. Call after teleporting
## the camera by editing its transform directly.
func reset_position() -> void:
	var dir := (global_position - target).normalized()
	_orientation = _quat_from_direction(dir)
	_apply_transform()

## Returns true while the user is actively dragging the camera (mouse or
## touch). Consumers use this to suppress clicks that happen during an orbit.
func is_drag_active() -> bool:
	return _mouse_dragging or _drag_confirmed

func _ready() -> void:
	reset_position()


func _process(delta: float) -> void:
	if !_is_dragging_enabled:
		return

	if not _mouse_dragging and _touches.size() == 0:
		var speed := _angular_velocity.length()
		if speed > inertia_cutoff:
			var axis := _angular_velocity.normalized()
			var angle := speed * delta
			var rot := Quaternion(axis, angle)
			_orientation = (rot * _orientation).normalized()
			_angular_velocity *= inertia_damping
		else:
			_angular_velocity = Vector3.ZERO

	if absf(_velocity_zoom) > 0.001:
		distance = clampf(distance + _velocity_zoom, min_distance, max_distance)
		_velocity_zoom *= zoom_damping
		if absf(_velocity_zoom) < 0.001:
			_velocity_zoom = 0.0

	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		if te.pressed:
			_touches[te.index] = te.position
			_prev_touches[te.index] = te.position
			if _touches.size() == 1:
				_drag_origin    = te.position
				_drag_confirmed = false
				pointer_pressed.emit(te.position)
			elif _touches.size() == 2:
				_pinch_start_dist = _current_pinch_distance()
		else:
			var was_drag := _drag_confirmed
			_touches.erase(te.index)
			_prev_touches.erase(te.index)
			if _touches.size() == 0:
				pointer_released.emit(was_drag)
				_drag_confirmed = false
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var de: InputEventScreenDrag = event
		_prev_touches[de.index] = _touches.get(de.index, de.position)
		_touches[de.index] = de.position

		if _touches.size() == 1:
			_handle_single_drag(de.position, de.relative)
		elif _touches.size() == 2:
			_handle_pinch()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_mouse_dragging  = true
					_mouse_origin    = mb.position
					_mouse_prev      = mb.position
					_mouse_confirmed = false
					_angular_velocity = Vector3.ZERO
				else:
					_mouse_dragging = false
					pointer_released.emit(_mouse_confirmed)
					_mouse_confirmed = false
				get_viewport().set_input_as_handled()
				return
			MOUSE_BUTTON_WHEEL_UP:
				_velocity_zoom -= wheel_zoom_step
				get_viewport().set_input_as_handled()
				return
			MOUSE_BUTTON_WHEEL_DOWN:
				_velocity_zoom += wheel_zoom_step
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion and _mouse_dragging:
		var mm: InputEventMouseMotion = event
		if not _mouse_confirmed:
			if mm.position.distance_to(_mouse_origin) < min_drag_distance:
				_mouse_prev = mm.position
				return
			_mouse_confirmed = true
			drag_started.emit()

		var rel := mm.position - _mouse_prev
		_mouse_prev = mm.position
		_orbit_by_pixels(rel)
		get_viewport().set_input_as_handled()
		return


func _handle_single_drag(pos: Vector2, relative: Vector2) -> void:
	if not _drag_confirmed:
		if pos.distance_to(_drag_origin) < min_drag_distance:
			return
		_drag_confirmed = true
		drag_started.emit()
		_angular_velocity = Vector3.ZERO

	_orbit_by_pixels(relative)


func _handle_pinch() -> void:
	var cur_dist := _current_pinch_distance()
	if _pinch_start_dist > 0.0:
		var diff := (_pinch_start_dist - cur_dist) * pinch_sensitivity
		_velocity_zoom += diff
	_pinch_start_dist = cur_dist


func _current_pinch_distance() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _orbit_by_pixels(rel: Vector2) -> void:
	# Rotate around camera-local axes only — no world-space axis dependency
	# means no pole restrictions or drift at the poles.
	var angle_h := -rel.x * orbit_sensitivity
	var angle_v := -rel.y * orbit_sensitivity

	var cam_right := (_orientation * Vector3.RIGHT).normalized()
	var cam_up := (_orientation * Vector3.UP).normalized()

	var rot_h := Quaternion(cam_up, angle_h)
	var rot_v := Quaternion(cam_right, angle_v)

	_orientation = (rot_v * rot_h * _orientation).normalized()

	var axis := cam_up * angle_h + cam_right * angle_v
	var dt := get_process_delta_time()
	if dt > 0.0:
		_angular_velocity = _angular_velocity.lerp(axis / dt, 0.4)


func _apply_transform() -> void:
	# The "rest" camera direction is (0, 0, 1) — looking at target from +Z.
	# Orientation quaternion rotates this to the current position.
	var cam_offset: Vector3 = _orientation * Vector3(0, 0, distance)
	var cam_up: Vector3 = _orientation * Vector3.UP

	global_position = target + cam_offset
	look_at(target, cam_up)


## Build a quaternion that rotates (0, 0, 1) to point along [param dir].
static func _quat_from_direction(dir: Vector3) -> Quaternion:
	var from := Vector3(0, 0, 1)
	var d := dir.normalized()

	var cross := from.cross(d)
	var cross_len := cross.length()

	if cross_len < 0.0001:
		# Nearly parallel — either same direction or opposite
		if from.dot(d) > 0.0:
			return Quaternion.IDENTITY
		else:
			return Quaternion(Vector3.UP, PI)

	var axis := cross / cross_len
	var angle := acos(clampf(from.dot(d), -1.0, 1.0))
	return Quaternion(axis, angle)
