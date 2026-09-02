## Mobile-style on/off switch: a rounded track with a knob that slides across.
## Drawn in code so it always matches the theme palette; toggles like a Button.
class_name ToggleSwitch
extends Button

const TRACK_ON := Color(0.40, 0.72, 0.28)
const TRACK_OFF := Color(0.55, 0.44, 0.32)
const KNOB := Color(1.0, 0.97, 0.9)
const OUTLINE := Color(0.24, 0.13, 0.06)
const OUTLINE_WIDTH := 4.0
const SLIDE_TIME := 0.15

## 0 = knob at the left (off), 1 = knob at the right (on).
var _knob_t := 0.0
var _tween: Tween


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(112, 58)
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	toggled.connect(_on_toggled)


func _ready() -> void:
	_knob_t = 1.0 if button_pressed else 0.0


## Sets the state without emitting `toggled` (used when opening the panel).
func set_on(on: bool) -> void:
	set_pressed_no_signal(on)
	_knob_t = 1.0 if on else 0.0
	queue_redraw()


func _on_toggled(on: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_set_knob, _knob_t, 1.0 if on else 0.0, SLIDE_TIME)


func _set_knob(t: float) -> void:
	_knob_t = t
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var radius := h * 0.5
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK_OFF.lerp(TRACK_ON, _knob_t)
	track.set_corner_radius_all(int(radius))
	track.set_border_width_all(int(OUTLINE_WIDTH))
	track.border_color = OUTLINE
	draw_style_box(track, Rect2(Vector2.ZERO, size))

	var knob_r := radius - OUTLINE_WIDTH - 3.0
	var x := lerpf(radius, size.x - radius, _knob_t)
	var center := Vector2(x, radius)
	draw_circle(center, knob_r + 2.0, OUTLINE)
	draw_circle(center, knob_r, KNOB)
