## In-run overlay: XP/level, timer, kills, coins, pause, hero HP bar that
## follows the hero, boss bar and big centre announcements.
class_name HUD
extends Control

signal pause_pressed

const HINT_DELAY := 0.6
const LOW_HP := 0.3
const LOW_HP_PULSE := 0.22

@onready var joystick: TouchJoystick = %Joystick
@onready var damage_numbers: DamageNumbers = %DamageNumbers
@onready var vignette: ColorRect = %Vignette
@onready var hero_hp: ProgressBar = %HeroHp
@onready var xp_bar: ProgressBar = %XpBar
@onready var level_label: Label = %LevelLabel
@onready var kills_label: Label = %KillsLabel
@onready var timer_label: Label = %TimerLabel
@onready var coins_label: Label = %CoinsLabel
@onready var pause_button: Button = %PauseButton
@onready var announce: Label = %Announce
@onready var boss_bar: ProgressBar = %BossBar
@onready var hint: Label = %Hint
@onready var top: MarginContainer = $Top

var _announce_tween: Tween
var _hint_tween: Tween
var _last_timer := -1
var _vignette_flash := 0.0
var _low_hp := false
var _pulse := 0.0


func _ready() -> void:
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	SafeArea.pad_top(top)
	joystick.pressed_changed.connect(_on_joystick_pressed)


## Shows the "drag to move" hint until the first touch; only players who have
## never finished a run see it.
func show_move_hint() -> void:
	if int(GameState.profile["stats"]["runs"]) > 0:
		return
	hint.visible = true
	hint.modulate.a = 0.0
	hint.pivot_offset = hint.size * 0.5
	create_tween().tween_property(hint, "modulate:a", 1.0, 0.5).set_delay(HINT_DELAY)
	_hint_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(hint, "scale", Vector2(1.06, 1.06), 0.6)
	_hint_tween.tween_property(hint, "scale", Vector2.ONE, 0.6)


func _on_joystick_pressed(is_pressed: bool) -> void:
	if is_pressed and hint.visible:
		if _hint_tween != null and _hint_tween.is_valid():
			_hint_tween.kill()
		var out := create_tween()
		out.tween_property(hint, "modulate:a", 0.0, 0.25)
		out.tween_callback(func() -> void: hint.visible = false)


func set_hp(current: float, max_hp: float) -> void:
	hero_hp.value = current / maxf(1.0, max_hp)
	_low_hp = current > 0.0 and hero_hp.value <= LOW_HP


## Red screen-edge flash when the hero takes damage.
func flash_damage(strength: float = 0.7) -> void:
	_vignette_flash = maxf(_vignette_flash, strength)


## Per-frame HUD animation: floating numbers and the vignette.
func tick(camera: Camera3D, delta: float) -> void:
	damage_numbers.update(camera, delta)
	_vignette_flash = maxf(0.0, _vignette_flash - delta * 3.2)
	var strength := _vignette_flash
	if _low_hp:
		_pulse += delta * 3.4
		strength = maxf(strength, LOW_HP_PULSE * (0.6 + 0.4 * sin(_pulse)))
	(vignette.material as ShaderMaterial).set_shader_parameter("strength", strength)


## Keeps the HP bar under the hero's feet (camera space).
func place_hero_hp(camera: Camera3D, hero_position: Vector3) -> void:
	var screen := camera.unproject_position(hero_position + Vector3(0, 0.0, 0.3))
	hero_hp.position = screen - Vector2(hero_hp.size.x * 0.5, 0.0)


func set_xp(current: float, needed: float, level: int) -> void:
	xp_bar.value = clampf(current / maxf(1.0, needed), 0.0, 1.0)
	level_label.text = "LV %d" % level


func set_time(seconds_left: float) -> void:
	var s := maxi(0, int(ceilf(seconds_left)))
	if s == _last_timer:
		return
	_last_timer = s
	timer_label.text = "%02d:%02d" % [s / 60, s % 60]


func set_kills(kills: int) -> void:
	kills_label.text = str(kills)


func set_coins(coins: int) -> void:
	coins_label.text = str(coins)


func set_boss(current: float, max_hp: float) -> void:
	boss_bar.visible = current > 0.0
	boss_bar.value = current / maxf(1.0, max_hp)


func show_announcement(text: String, duration: float = 2.0) -> void:
	announce.text = text
	announce.visible = true
	announce.modulate.a = 0.0
	announce.scale = Vector2(0.6, 0.6)
	announce.pivot_offset = announce.size * 0.5
	if _announce_tween != null and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_announce_tween.tween_property(announce, "modulate:a", 1.0, 0.25)
	_announce_tween.tween_property(announce, "scale", Vector2.ONE, 0.35)
	_announce_tween.chain().tween_property(announce, "modulate:a", 0.0, 0.4).set_delay(duration)
	_announce_tween.chain().tween_callback(func() -> void: announce.visible = false)
