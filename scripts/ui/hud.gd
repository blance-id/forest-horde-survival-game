## In-run overlay: XP bar + level badge, HP bar, the resource counters
## (kills / coins / wood / ammo), the run timeline, the current build, kill
## combos, coin flights into the counter, a mini HP bar and chop bar that
## follow the hero, the minimap, the boss bar and big centre announcements.
class_name HUD
extends Control

signal pause_pressed
signal build_pressed
## The player tapped a bag slot: index into the bag handed to `set_bag_items`.
signal relic_used(index: int)

const HINT_DELAY := 0.6
const LOW_HP := 0.3
const LOW_HP_PULSE := 0.22
## Kills closer together than this chain into a combo; it shows from 5 up.
const COMBO_WINDOW := 1.3
const COMBO_MIN := 5
const COMBO_COLORS: Array[Color] = [Color(1.0, 0.96, 0.85), Color(1.0, 0.82, 0.3), Color(1.0, 0.45, 0.25), Color(1.0, 0.25, 0.35)]
## The HP bar reads as a gauge: full green, half yellow, empty red, with the
## two halves interpolated so the colour moves continuously with the ratio.
const HP_FULL := Color(0.35, 0.82, 0.28)
const HP_HALF := Color(0.98, 0.82, 0.15)
const HP_LOW := Color(0.9, 0.18, 0.16)

@onready var joystick: TouchJoystick = %Joystick
@onready var damage_numbers: DamageNumbers = %DamageNumbers
@onready var world_bars: WorldBars = %WorldBars
@onready var vignette: ColorRect = %Vignette
@onready var hero_hp: ProgressBar = %HeroHp
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var heart_icon: TextureRect = %HeartIcon
@onready var xp_bar: ProgressBar = %XpBar
@onready var level_badge: TextureRect = %LevelBadge
@onready var level_label: Label = %LevelLabel
@onready var kills_label: Label = %KillsLabel
@onready var timer_label: Label = %TimerLabel
@onready var wave_label: Label = %WaveLabel
@onready var remaining_label: Label = %RemainingLabel
@onready var coin_icon: TextureRect = %CoinIcon
@onready var coins_label: Label = %CoinsLabel
@onready var wood_icon: TextureRect = %WoodIcon
@onready var wood_label: Label = %WoodLabel
@onready var ammo_icon: TextureRect = %AmmoIcon
@onready var ammo_label: Label = %AmmoLabel
@onready var minimap: Minimap = %Minimap
@onready var chop_bar: ProgressBar = %ChopBar
@onready var rescue_bar: ProgressBar = %RescueBar
@onready var vehicle_row: HBoxContainer = %VehicleRow
@onready var hull_bar: ProgressBar = %HullBar
@onready var shells_label: Label = %ShellsLabel
@onready var build_button: Button = %BuildButton
@onready var build_icon: TextureRect = %BuildIcon
@onready var build_cost: Label = %BuildCost
@onready var bag_row: HBoxContainer = %BagRow
@onready var hidden_badge: Label = %HiddenBadge
@onready var pause_button: Button = %PauseButton
@onready var timeline: RunTimeline = %Timeline
@onready var build_bar: BuildBar = %BuildBar
@onready var coin_rain: CoinRain = %CoinRain
@onready var combo: Control = %Combo
@onready var combo_count: Label = %ComboCount
@onready var combo_text: Label = %ComboText
@onready var announce: Label = %Announce
@onready var boss_bar: ProgressBar = %BossBar
@onready var boss_name: Label = %BossName
@onready var hint: Label = %Hint
@onready var top: MarginContainer = $Top

var _announce_tween: Tween
var _hint_tween: Tween
var _last_timer := -1
var _vignette_flash := 0.0
var _low_hp := false
var _pulse := 0.0
var _level := 1
var _shown_coins := 0
var _combo := 0
var _combo_timer := 0.0
var _combo_tween: Tween
var _punches: Dictionary = {}  # Control -> Tween
var _hero_position := Vector3.ZERO
var _can_build := true
var _hp_fill: StyleBox
var _hero_hp_fill: StyleBox


func _ready() -> void:
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	build_button.pressed.connect(func() -> void: build_pressed.emit())
	SafeArea.pad_top(top)
	joystick.pressed_changed.connect(_on_joystick_pressed)
	# Own copies of the fill boxes so the gradient can repaint them per frame
	# without touching the shared theme.
	_hp_fill = _own_fill(hp_bar)

	_hero_hp_fill = _own_fill(hero_hp)


## The two HP bars use different fills — a white nine-patch for the big bar,
## a flat rect for the one under the hero — so the tint goes to whichever
## property that box actually paints with.
func _own_fill(bar: ProgressBar) -> StyleBox:
	var box := bar.get_theme_stylebox("fill")
	if box == null:
		return null
	var mine := box.duplicate() as StyleBox
	bar.add_theme_stylebox_override("fill", mine)
	return mine


static func _tint(box: StyleBox, color: Color) -> void:
	if box is StyleBoxFlat:
		(box as StyleBoxFlat).bg_color = color
	elif box is StyleBoxTexture:
		(box as StyleBoxTexture).modulate_color = color


static func hp_color(ratio: float) -> Color:
	if ratio >= 0.5:
		return HP_HALF.lerp(HP_FULL, (ratio - 0.5) * 2.0)
	return HP_LOW.lerp(HP_HALF, ratio * 2.0)


func setup(chapter: ChapterData) -> void:
	timeline.setup(chapter)
	minimap.setup(chapter)


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
	var ratio := current / maxf(1.0, max_hp)
	if ratio < hero_hp.value:
		_punch(heart_icon, 1.35)
	hero_hp.value = ratio
	hp_bar.value = ratio
	hp_label.text = "%d / %d" % [ceili(current), roundi(max_hp)]
	var tint := hp_color(ratio)
	if _hp_fill != null:
		_tint(_hp_fill, tint)
	if _hero_hp_fill != null:
		_tint(_hero_hp_fill, tint)
	_low_hp = current > 0.0 and ratio <= LOW_HP


## Red screen-edge flash when the hero takes damage.
func flash_damage(strength: float = 0.7) -> void:
	_vignette_flash = maxf(_vignette_flash, strength)


## Per-frame HUD animation: floating numbers, the vignette and the combo timer.
func tick(camera: Camera3D, delta: float) -> void:
	damage_numbers.update(camera, delta)
	world_bars.tick(camera, _hero_position)
	minimap.tick(_hero_position)
	_vignette_flash = maxf(0.0, _vignette_flash - delta * 3.2)
	var strength := _vignette_flash
	if _low_hp:
		_pulse += delta * 3.4
		strength = maxf(strength, LOW_HP_PULSE * (0.6 + 0.4 * sin(_pulse)))
	(vignette.material as ShaderMaterial).set_shader_parameter("strength", strength)
	if _combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_end_combo()


## Keeps the HP bar under the hero's feet (camera space).
func place_hero_hp(camera: Camera3D, hero_position: Vector3) -> void:
	_hero_position = hero_position
	var screen := camera.unproject_position(hero_position + Vector3(0, 0.0, 0.3))
	hero_hp.position = screen - Vector2(hero_hp.size.x * 0.5, 0.0)
	chop_bar.position = screen - Vector2(chop_bar.size.x * 0.5, -16.0)


func set_xp(current: float, needed: float, level: int) -> void:
	xp_bar.value = clampf(current / maxf(1.0, needed), 0.0, 1.0)
	level_label.text = str(level)
	if level != _level:
		_level = level
		_punch(level_badge, 1.5)
		var tw := create_tween()
		xp_bar.modulate = Color(2.0, 2.0, 2.0)
		tw.tween_property(xp_bar, "modulate", Color.WHITE, 0.5)


## Elapsed run time. It no longer gates anything — waves do — but it is what
## the chapter record is measured in, so it stays on screen.
func set_time(seconds: float) -> void:
	var s := maxi(0, int(seconds))
	if s == _last_timer:
		return
	_last_timer = s
	timer_label.text = "%02d:%02d" % [s / 60, s % 60]


## `index` waves cleared out of `count`, with `remaining` bodies still to beat
## in the current one.
func set_wave(index: int, count: int, remaining: int, ratio: float) -> void:
	timeline.set_wave(index, ratio)
	var shown := mini(index + 1, count)
	var text := "WAVE %d / %d" % [shown, count]
	if text != wave_label.text:
		wave_label.text = text
		_punch(wave_label, 1.2)
	remaining_label.text = "%d LEFT" % remaining if remaining > 0 else "CLEAR!"


func set_kills(kills: int) -> void:
	kills_label.text = str(kills)
	_punch(kills_label, 1.25)
	# Combo: every kill inside the window extends it.
	_combo += 1
	_combo_timer = COMBO_WINDOW
	if _combo >= COMBO_MIN:
		_show_combo()


func _show_combo() -> void:
	combo.visible = true
	combo_count.text = str(_combo)
	var tier := clampi(_combo / 15, 0, COMBO_COLORS.size() - 1)
	combo_count.add_theme_color_override("font_color", COMBO_COLORS[tier])
	combo_text.text = ["COMBO", "COMBO", "MEGA COMBO", "RAMPAGE!"][tier]
	if _combo_tween != null and _combo_tween.is_valid():
		_combo_tween.kill()
	combo.modulate.a = 1.0
	combo.scale = Vector2(1.3, 1.3)
	_combo_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_combo_tween.tween_property(combo, "scale", Vector2.ONE, 0.25)


func _end_combo() -> void:
	_combo = 0
	if not combo.visible:
		return
	if _combo_tween != null and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_tween.tween_property(combo, "modulate:a", 0.0, 0.3)
	_combo_tween.tween_callback(func() -> void: combo.visible = false)


## Coins fly from where they were picked up into the counter, which only
## counts them once they land.
func add_coins(amount: int, world_position: Vector3, camera: Camera3D) -> void:
	var from := camera.unproject_position(world_position)
	var to := coin_icon.global_position + coin_icon.size * 0.5
	coin_rain.fly(from, to, func() -> void:
		_shown_coins += amount
		coins_label.text = str(_shown_coins)
		_punch(coin_icon, 1.4)
		_punch(coins_label, 1.2))


func set_coins(coins: int) -> void:
	_shown_coins = coins
	coins_label.text = str(coins)


## Draws the relics carried into this run as tappable buttons. Spent slots
## stay in place, greyed out, so the row does not jump around mid-fight.
func set_bag_items(relics: Array[RelicData], spent: Array[bool]) -> void:
	for c in bag_row.get_children():
		c.queue_free()
	for i in relics.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(88, 88)
		button.theme_type_variation = &"RoundButton"
		button.icon = relics[i].icon
		# RoundButton tints its icon chocolate for Kenney's white icon sheets;
		# a relic icon is a full-colour render and must stay untinted.
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_disabled_color"]:
			button.add_theme_color_override(state, Color.WHITE)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.disabled = spent[i]
		button.modulate.a = 0.4 if spent[i] else 1.0
		button.tooltip_text = "%s — %s" % [relics[i].display_name, relics[i].description]
		button.pressed.connect(func() -> void: relic_used.emit(i))
		bag_row.add_child(button)


func setup_build_button(tower: TowerData) -> void:
	build_icon.texture = tower.icon
	build_cost.text = "BUILD %d" % tower.wood_cost


## The build button doubles as the upgrade button: it shows what the next tap
## would cost and greys out when that tap is not possible, so the button
## itself teaches the rule.
func set_build_action(can_act: bool, cost: int, upgrading: bool) -> void:
	if can_act != _can_build:
		_can_build = can_act
		build_button.disabled = not can_act
		build_button.modulate.a = 1.0 if can_act else 0.55
	var text := "%s %d" % ["UP" if upgrading else "BUILD", cost]
	if text != build_cost.text:
		build_cost.text = text


func set_wood(wood: int) -> void:
	wood_label.text = str(wood)
	_punch(wood_icon, 1.35)


func set_ammo(ammo: int) -> void:
	ammo_label.text = str(ammo)
	_punch(ammo_icon, 1.35)


## Chopping progress, shown under the hero. A negative ratio hides the bar.
func set_chop(ratio: float) -> void:
	chop_bar.visible = ratio >= 0.0
	if ratio >= 0.0:
		chop_bar.value = 1.0 - ratio


## Rescue progress, floated over the survivor being freed. A negative ratio
## hides it — the hero walked away and the timer reset.
func set_rescue(ratio: float, world_position: Vector3, camera: Camera3D) -> void:
	rescue_bar.visible = ratio >= 0.0
	if ratio < 0.0:
		return
	rescue_bar.value = ratio
	var screen := camera.unproject_position(world_position)
	rescue_bar.position = screen - Vector2(rescue_bar.size.x * 0.5, 0.0)


## Mech hull and shells. Zero max hull means the hero is back on foot.
func set_vehicle(ammo: int, hull: float, max_hull: float) -> void:
	vehicle_row.visible = max_hull > 0.0
	if max_hull <= 0.0:
		return
	hull_bar.value = clampf(hull / max_hull, 0.0, 1.0)
	shells_label.text = str(ammo)


## In a bush: the horde loses track of the hero until they attack from cover.
func set_hidden(hidden: bool) -> void:
	if hidden == hidden_badge.visible:
		return
	hidden_badge.visible = hidden
	if hidden:
		hidden_badge.modulate.a = 0.0
		create_tween().tween_property(hidden_badge, "modulate:a", 0.9, 0.2)


func set_boss(current: float, max_hp: float, boss_title: String = "") -> void:
	boss_bar.visible = current > 0.0
	boss_bar.value = current / maxf(1.0, max_hp)
	if boss_title != "":
		boss_name.text = boss_title.to_upper()
	timeline.set_boss_alive(boss_bar.visible)


func set_build(weapons: Array[WeaponSystem.Slot], passives: Dictionary) -> void:
	build_bar.set_weapons(weapons)
	build_bar.set_passives(passives)


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


## Scale punch that settles back; a punch during a punch restarts it.
func _punch(node: Control, amount: float) -> void:
	var old: Tween = _punches.get(node)
	if old != null and old.is_valid():
		old.kill()
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(amount, amount)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "scale", Vector2.ONE, 0.3)
	_punches[node] = tw
