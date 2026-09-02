## Floating one-finger joystick: the base appears where the finger lands and
## the knob follows the drag. `direction` is the movement vector (screen
## space, length 0..1). Keyboard arrows/WASD work as a desktop fallback.
class_name TouchJoystick
extends Control

signal pressed_changed(is_pressed: bool)

@export var radius := 110.0
@export var dead_zone := 0.08

var direction := Vector2.ZERO
var is_pressed := false

var _touch_index := -1
var _origin := Vector2.ZERO
var _base: TextureRect
var _knob: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_base = _make_ring("res://assets/ui/adventure/round_grey_dark.png", radius * 2.0, 0.45)
	_knob = _make_ring("res://assets/ui/adventure/round_grey.png", radius * 0.9, 0.85)
	_base.visible = false
	_knob.visible = false


func _make_ring(path: String, size: float, alpha: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(size, size)
	tr.modulate = Color(1, 1, 1, alpha)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1:
			_touch_index = t.index
			_origin = t.position
			_show(t.position)
			_update(t.position)
			accept_event()
		elif not t.pressed and t.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			_update(d.position)
			accept_event()


func _process(_delta: float) -> void:
	if _touch_index != -1:
		return
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	direction = kb


func _show(at: Vector2) -> void:
	is_pressed = true
	_base.visible = true
	_knob.visible = true
	_base.position = at - _base.size * 0.5
	pressed_changed.emit(true)


func _update(at: Vector2) -> void:
	var delta := at - _origin
	var len := delta.length()
	if len > radius:
		delta = delta / len * radius
		len = radius
	var v := delta / radius
	direction = Vector2.ZERO if v.length() < dead_zone else v
	_knob.position = _origin + delta - _knob.size * 0.5


func _release() -> void:
	_touch_index = -1
	is_pressed = false
	direction = Vector2.ZERO
	_base.visible = false
	_knob.visible = false
	pressed_changed.emit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if _touch_index != -1:
			_release()
