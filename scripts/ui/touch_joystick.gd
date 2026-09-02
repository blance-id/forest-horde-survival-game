## Floating one-finger joystick: the base appears where the finger lands, the
## knob follows the drag, and once the finger goes past the ring the base is
## dragged along behind it so reversing direction never needs a lift.
## `direction` is the movement vector (screen space, length 0..1) shaped by a
## response curve that reaches full speed well before the ring edge, so small
## thumb movements still feel snappy. Keyboard arrows/WASD are the desktop
## fallback.
class_name TouchJoystick
extends Control

signal pressed_changed(is_pressed: bool)

@export var radius := 96.0
## Fraction of the radius below which the stick reads as centred.
@export var dead_zone := 0.10
## Fraction of the radius at which the stick already gives full speed.
@export var full_speed_at := 0.7
## Speed fraction given right past the dead zone, so nudges still move.
@export var min_speed := 0.35
const FADE_IN := 0.06
const FADE_OUT := 0.16

var direction := Vector2.ZERO
var is_pressed := false

var _touch_index := -1
var _origin := Vector2.ZERO
var _base: TextureRect
var _knob: TextureRect
var _fade: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_base = _make_ring("res://assets/ui/adventure/round_grey_dark.png", radius * 2.0)
	_knob = _make_ring("res://assets/ui/adventure/round_grey.png", radius * 0.9)
	_base.self_modulate.a = 0.45
	_knob.self_modulate.a = 0.85
	modulate.a = 0.0


func _make_ring(path: String, size: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(size, size)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1:
			_touch_index = t.index
			_origin = t.position
			_show()
			_update(t.position)
			accept_event()
		elif not t.pressed and t.index == _touch_index:
			reset()
			accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			_update(d.position)
			accept_event()


func _process(_delta: float) -> void:
	if _touch_index != -1:
		return
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Drops the current touch, e.g. when the tree pauses and the release event
## would otherwise never reach us.
func reset() -> void:
	var was_pressed := is_pressed
	_touch_index = -1
	is_pressed = false
	direction = Vector2.ZERO
	_fade_to(0.0, FADE_OUT)
	if was_pressed:
		pressed_changed.emit(false)


## Maps a finger position to `direction` and moves the base when the finger
## leaves the ring. Split out so the math is testable without input events.
func apply_finger(at: Vector2) -> void:
	var delta := at - _origin
	var len := delta.length()
	if len > radius:
		_origin = at - delta / len * radius
		delta = at - _origin
		len = radius
	var t := len / radius
	if t < dead_zone or len == 0.0:
		direction = Vector2.ZERO
	else:
		var speed := clampf(remap(t, dead_zone, full_speed_at, min_speed, 1.0), min_speed, 1.0)
		direction = delta / len * speed


func _show() -> void:
	is_pressed = true
	_fade_to(1.0, FADE_IN)
	pressed_changed.emit(true)


func _update(at: Vector2) -> void:
	apply_finger(at)
	_base.position = _origin - _base.size * 0.5
	_knob.position = _origin + (at - _origin).limit_length(radius) - _knob.size * 0.5


func _fade_to(alpha: float, time: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, time)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if _touch_index != -1:
			reset()
