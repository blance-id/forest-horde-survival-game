## End-of-run summary with retry / menu actions.
class_name ResultPanel
extends Control

signal retry_pressed
signal menu_pressed

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _time_value: Label = %TimeValue
@onready var _kills_value: Label = %KillsValue
@onready var _level_value: Label = %LevelValue
@onready var _coins_value: Label = %CoinsValue
@onready var _retry: Button = %RetryButton
@onready var _menu: Button = %MenuButton


func _ready() -> void:
	visible = false
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	_menu.pressed.connect(func() -> void: menu_pressed.emit())


func show_result(won: bool, chapter_name: String, seconds: float, kills: int, level: int, coins: int) -> void:
	_title.text = "VICTORY!" if won else "YOU DIED"
	_subtitle.text = ("%s cleared!" % chapter_name) if won else ("The horde took %s" % chapter_name)
	var s := int(seconds)
	_time_value.text = "%02d:%02d" % [s / 60, s % 60]
	_kills_value.text = str(kills)
	_level_value.text = str(level)
	_coins_value.text = "+%d" % coins
	_retry.disabled = false
	_menu.disabled = false
	visible = true
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.6, 0.6)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35)
	tw.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR)
