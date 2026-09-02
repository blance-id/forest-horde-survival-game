## "Continue?" — the one moment a run can be bought back.
##
## The price doubles every time it is used inside the same run, so the first
## revive is a small tax and the fourth is a real decision. The timer running
## down is the pressure: it closes itself if the player does nothing, which
## keeps a death from turning into an open-ended menu.
class_name RevivePanel
extends Control

signal revive_pressed
signal declined

## 100, 200, 400, 800 …
const BASE_COST := 100
const COUNTDOWN := 6.0

@onready var _panel: PanelContainer = %Panel
@onready var _cost: Label = %CostLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _revive: Button = %ReviveButton
@onready var _give_up: Button = %GiveUpButton

var _time_left := 0.0
var _open := false


func _ready() -> void:
	visible = false
	_revive.pressed.connect(func() -> void: _close_with(true))
	_give_up.pressed.connect(func() -> void: _close_with(false))


## Cost of the `used`-th revive this run (0-based).
static func cost_for(used: int) -> int:
	return BASE_COST * int(pow(2.0, float(used)))


## Returns false when the player cannot afford it, so the caller can skip
## straight to the result screen instead of showing a dead button.
func open(used_this_run: int, coins: int) -> bool:
	var price := cost_for(used_this_run)
	if coins < price:
		return false
	_cost.text = "%d COINS" % price
	_time_left = COUNTDOWN
	_timer_label.text = "%d" % ceili(_time_left)
	_open = true
	visible = true
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.7, 0.7)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3)
	tw.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_LINEAR)
	SoundBank.ui("open")
	return true


## Driven by the run rather than `_process`, because the tree is paused here.
func tick(delta: float) -> void:
	if not _open:
		return
	_time_left -= delta
	_timer_label.text = "%d" % maxi(0, ceili(_time_left))
	if _time_left <= 0.0:
		_close_with(false)


func _close_with(revived: bool) -> void:
	if not _open:
		return
	_open = false
	SoundBank.ui("confirm" if revived else "back")
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_panel, "scale", Vector2(0.85, 0.85), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func() -> void:
		visible = false
		if revived:
			revive_pressed.emit()
		else:
			declined.emit())
