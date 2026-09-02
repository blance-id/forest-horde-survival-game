## End-of-run summary with retry / menu actions. Coins count up, and a
## "NEW RECORD!" stamp slams onto the card when the run beat the best time.
class_name ResultPanel
extends Control

signal retry_pressed
signal menu_pressed

const COUNT_TIME := 0.8

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _time_value: Label = %TimeValue
@onready var _kills_value: Label = %KillsValue
@onready var _level_value: Label = %LevelValue
@onready var _coins_value: Label = %CoinsValue
@onready var _retry: Button = %RetryButton
@onready var _menu: Button = %MenuButton
@onready var _stamp: Label = %RecordStamp


func _ready() -> void:
	visible = false
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	_menu.pressed.connect(func() -> void: menu_pressed.emit())


func show_result(won: bool, chapter_name: String, seconds: float, kills: int, level: int, coins: int, new_best: bool = false) -> void:
	_title.text = "VICTORY!" if won else "YOU DIED"
	_subtitle.text = ("%s cleared!" % chapter_name) if won else ("The horde took %s" % chapter_name)
	var s := int(seconds)
	_time_value.text = "%02d:%02d" % [s / 60, s % 60]
	_kills_value.text = str(kills)
	_level_value.text = str(level)
	_coins_value.text = "+0"
	_retry.disabled = false
	_menu.disabled = false
	_stamp.visible = false
	visible = true
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.6, 0.6)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35)
	tw.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR)
	tw.tween_method(func(v: float) -> void: _coins_value.text = "+%d" % roundi(v),
		0.0, float(coins), COUNT_TIME).set_delay(0.3).set_trans(Tween.TRANS_QUAD)
	if new_best:
		tw.chain().tween_callback(_slam_stamp)


func _slam_stamp() -> void:
	# Over the card's top-right corner, leaning like a rubber stamp.
	_stamp.visible = true
	_stamp.position = _panel.global_position + Vector2(_panel.size.x - _stamp.size.x + 30.0, -22.0)
	_stamp.scale = Vector2(3.0, 3.0)
	_stamp.modulate.a = 0.0
	SoundBank.jingle("reward", -4.0)
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_stamp, "scale", Vector2.ONE, 0.22)
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.12)
