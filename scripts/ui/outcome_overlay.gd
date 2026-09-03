## The moment a run ends, before any menu.
##
## Both endings work the same way: the world stops dead — zombies frozen
## mid-lunge, particles hanging in the air — and the screen answers. Death
## floods red and closes in, like something is on top of you. A win floods
## gold and stamps a badge, the way a match result lands in Clash Royale.
##
## The tree is paused for all of this, so everything here runs on ALWAYS
## process mode and drives its own timing. Nothing on the `Game` side ticks.
class_name OutcomeOverlay
extends Control

## The screen has said its piece; the caller can open its panel now.
signal finished

const DEATH_FLOOD := Color(0.62, 0.03, 0.04)
const WIN_FLOOD := Color(1.0, 0.72, 0.15)
const DEATH_HOLD := 1.3
const WIN_HOLD := 1.9

@onready var _flood: ColorRect = %Flood
@onready var _closing: ColorRect = %Closing
@onready var _badge: TextureRect = %Badge
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle

var _tween: Tween
var _hold_tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE


func show_death() -> void:
	_begin(DEATH_FLOOD, "YOU DIED", "The forest took you")
	_badge.visible = false
	# A heavy red vignette closes in over the flood. It has to frame the
	# frozen horde standing over you, not hide it — being eaten is the image,
	# and the image is the zombies.
	_closing.visible = true
	var mat := _closing.material as ShaderMaterial
	mat.set_shader_parameter("strength", 0.0)
	_tween.parallel().tween_method(func(v: float) -> void:
		mat.set_shader_parameter("strength", v), 0.0, 0.95, 0.55)
	_tween.parallel().tween_property(_flood, "color:a", 0.3, 0.35)
	_slam(1.35)
	_hold(DEATH_HOLD)


func show_victory() -> void:
	_begin(WIN_FLOOD, "VICTORY!", "You outlasted the horde")
	_closing.visible = false
	_badge.visible = true
	_badge.modulate = Color(1.0, 0.88, 0.42)
	_badge.pivot_offset = _badge.size * 0.5
	_badge.scale = Vector2(2.6, 2.6)
	_badge.rotation = -0.5
	_tween.parallel().tween_property(_flood, "color:a", 0.32, 0.3)
	_tween.parallel().tween_property(_badge, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.parallel().tween_property(_badge, "rotation", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_slam(1.6)
	_hold(WIN_HOLD)


func hide_overlay() -> void:
	for t: Tween in [_tween, _hold_tween]:
		if t != null and t.is_valid():
			t.kill()
	visible = false


func _begin(flood: Color, title: String, subtitle: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_title.text = title
	_subtitle.text = subtitle
	_flood.color = Color(flood.r, flood.g, flood.b, 0.0)
	visible = true
	modulate.a = 1.0
	_tween = create_tween().set_parallel(true)


## The beat before handing off. This needs its own sequential tween: the
## animation tween is parallel, and `chain()` on a parallel tween still runs
## the interval and the callback together, so the callback fired instantly.
func _hold(seconds: float) -> void:
	if _hold_tween != null and _hold_tween.is_valid():
		_hold_tween.kill()
	_hold_tween = create_tween()
	_hold_tween.tween_interval(seconds)
	_hold_tween.tween_callback(func() -> void: finished.emit())


func _slam(from_scale: float) -> void:
	for label: Label in [_title, _subtitle]:
		label.pivot_offset = label.size * 0.5
		label.modulate.a = 0.0
	_title.scale = Vector2(from_scale, from_scale)
	_tween.parallel().tween_property(_title, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.2)
	_tween.parallel().tween_property(_title, "modulate:a", 1.0, 0.2).set_delay(0.2)
	_tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.3).set_delay(0.45)
