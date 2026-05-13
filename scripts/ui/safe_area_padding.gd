## Drop-in child node that shifts its parent Control's edges inward by the
## device safe-area insets reported by [SafeAreaManager]. Anchor-aware: the
## parent's outer rect translates/contracts so its size and visual placement
## are preserved on devices without insets.
class_name SafeAreaPadding
extends Node

@export var pad_left: bool = true
@export var pad_top: bool = true
@export var pad_right: bool = true
@export var pad_bottom: bool = true

var _target: Control
var _base_offsets: Vector4 = Vector4.ZERO


func _ready() -> void:
	_target = get_parent() as Control
	if _target == null:
		push_error("SafeAreaPadding parent must be a Control")
		return
	_base_offsets = Vector4(
		_target.offset_left,
		_target.offset_top,
		_target.offset_right,
		_target.offset_bottom
	)
	SafeAreaManager.insets_changed.connect(_apply)
	_apply(SafeAreaManager.insets)


func _apply(insets: Vector4) -> void:
	if _target == null:
		return
	var l := insets.x if pad_left else 0.0
	var t := insets.y if pad_top else 0.0
	var r := insets.z if pad_right else 0.0
	var b := insets.w if pad_bottom else 0.0
	# Translate edges anchored to the opposite side so the container's height
	# or width is preserved when only one side has an inset.
	var dl := l - (r if _target.anchor_left == 1.0 else 0.0)
	var dt := t - (b if _target.anchor_top == 1.0 else 0.0)
	var dr := -r + (l if _target.anchor_right == 0.0 else 0.0)
	var db := -b + (t if _target.anchor_bottom == 0.0 else 0.0)
	_target.offset_left = _base_offsets.x + dl
	_target.offset_top = _base_offsets.y + dt
	_target.offset_right = _base_offsets.z + dr
	_target.offset_bottom = _base_offsets.w + db
