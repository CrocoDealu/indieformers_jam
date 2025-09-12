extends Node
class_name InvertEffectManager

@export var overlay_path: NodePath
var tween_time: float = 0.35

var _overlay: ColorRect
var _tween: Tween
var _enabled: bool = false

func _ready():
	if overlay_path != NodePath():
		_overlay = get_node_or_null(overlay_path)
	if not _overlay:
		push_warning("InvertEffectManager: overlay_path not set or node missing.")
		return
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_set_strength_immediate(0.0)

func set_enabled(enable: bool):
	if _enabled == enable:
		return
	_enabled = enable
	_animate_strength(1.0 if _enabled else 0.0)

func toggle():
	set_enabled(not _enabled)

func _set_strength_immediate(v: float):
	if _overlay and _overlay.material:
		_overlay.material.set("shader_parameter/strength", v)

func _animate_strength(target: float):
	if not _overlay or not _overlay.material:
		return
	_overlay.visible = true
	if _tween:
		_tween.kill()
	_tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(
		_overlay.material,
		"shader_parameter/strength",
		target,
		tween_time
	).from_current()
	if target == 0.0:
		_tween.tween_callback(Callable(self, "_maybe_hide"))

func _maybe_hide():
	if not _overlay: return
	var s = _overlay.material.get("shader_parameter/strength")
	if s <= 0.001:
		_overlay.visible = false
