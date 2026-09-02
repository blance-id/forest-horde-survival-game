## Settings overlay: music / sound / vibration toggles, the quality picker,
## credits and version. Toggles write the volume settings AudioManager already
## listens to; quality only takes effect on the next screen that builds a
## world, which the panel says out loud rather than pretending otherwise.
class_name SettingsPanel
extends Control

signal closed

const MUSIC_ON := 0.8
const SFX_ON := 1.0

@onready var _panel: PanelContainer = %Panel
@onready var _music: ToggleSwitch = %MusicSwitch
@onready var _sfx: ToggleSwitch = %SfxSwitch
@onready var _haptics: ToggleSwitch = %HapticsSwitch
@onready var _quality_buttons: Array[Button] = [%QualityLow, %QualityNormal, %QualityMax]
@onready var _version: Label = %Version
@onready var _close: Button = %CloseButton


func _ready() -> void:
	visible = false
	_version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_music.toggled.connect(func(on: bool) -> void:
		GameState.set_setting("music_volume", MUSIC_ON if on else 0.0)
		SoundBank.ui("switch"))
	_sfx.toggled.connect(func(on: bool) -> void:
		GameState.set_setting("sfx_volume", SFX_ON if on else 0.0)
		SoundBank.ui("switch"))
	_haptics.toggled.connect(func(on: bool) -> void:
		GameState.set_setting("haptics", on)
		SoundBank.ui("switch")
		if on:
			Haptics.medium())
	for i in _quality_buttons.size():
		_quality_buttons[i].pressed.connect(_on_quality_pressed.bind(i))
	_close.pressed.connect(close)


func open() -> void:
	_music.set_on(float(GameState.get_setting("music_volume", MUSIC_ON)) > 0.0)
	_sfx.set_on(float(GameState.get_setting("sfx_volume", SFX_ON)) > 0.0)
	_haptics.set_on(bool(GameState.get_setting("haptics", true)))
	_show_quality(Quality.level())
	visible = true
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.7, 0.7)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3)
	tw.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_LINEAR)


func _on_quality_pressed(index: int) -> void:
	Quality.set_level(index as Quality.Level)
	_show_quality(index as Quality.Level)
	SoundBank.ui("switch")


func _show_quality(level: Quality.Level) -> void:
	for i in _quality_buttons.size():
		_quality_buttons[i].button_pressed = i == int(level)


func close() -> void:
	if not visible:
		return
	SoundBank.ui("close")
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_panel, "scale", Vector2(0.8, 0.8), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func() -> void:
		visible = false
		closed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
