## Main menu: an ad-style front over a live demo of the game. The hero strolls
## through the forest blasting an endless trickle of zombies behind the title,
## so the first screen already looks exactly like play.
class_name MainMenu
extends Node3D

const DEMO_CAP := 26
const DEMO_SPAWN_INTERVAL := 0.35
## Director time the demo mix is sampled at (walkers, runners and wisps).
const DEMO_MIX_TIME := 100.0
## Level for each entry of `demo_weapons`; the far-reaching blaster stays low
## so zombies actually make it on screen, the orbit weapon is high so they
## never pile onto the hero.
const DEMO_WEAPON_LEVELS: PackedInt32Array = [2, 4]
const STROLL_SPEED := 0.45
const STROLL_TURN := 0.4

@export var chapter: ChapterData
@export var character: CharacterData
@export var demo_weapons: Array[WeaponData] = []

@onready var world: Node3D = $World
@onready var camera_rig: CameraRig = $CameraRig
@onready var player: Player = $Player
@onready var enemies: EnemyManager = $Enemies
@onready var projectiles: ProjectileManager = $Projectiles
@onready var weapon_system: WeaponSystem = $Weapons
@onready var coins_label: Label = %CoinsLabel
@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var chapter_label: Label = %ChapterLabel
@onready var chapter_name: Label = %ChapterName
@onready var chapter_best: Label = %ChapterBest
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var top_bar: MarginContainer = $UI/Root/TopBar

var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _time := 0.0
var _pulse: Tween


func _ready() -> void:
	_rng.randomize()
	SafeArea.pad_top(top_bar)
	_build_demo()
	_build_ui()
	AudioManager.play_music(SoundBank.music("menu"), 1.0)


func _build_demo() -> void:
	var arena := Arena.new()
	arena.name = "Arena"
	world.add_child(arena)
	arena.build(chapter, _rng.randi())

	var stats := RunStats.from_character(character)
	player.arena_half = chapter.arena_half_size
	player.invulnerable = true
	player.setup(character, stats)

	enemies.player = player
	enemies.arena_half = chapter.arena_half_size
	projectiles.enemies = enemies

	weapon_system.player = player
	weapon_system.enemies = enemies
	weapon_system.projectiles = projectiles
	weapon_system.run_stats = stats
	for w in demo_weapons.size():
		var level := DEMO_WEAPON_LEVELS[mini(w, DEMO_WEAPON_LEVELS.size() - 1)]
		for i in level:
			weapon_system.add_or_upgrade(demo_weapons[w])

	camera_rig.snap_to(player.position)
	camera_rig.make_current()


func _build_ui() -> void:
	GameState.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(GameState.get_coins())
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_panel.closed.connect(_start_pulse)

	var index := GameState.get_unlocked_chapters().find(chapter.id)
	chapter_label.text = "CHAPTER %d" % (maxi(index, 0) + 1)
	chapter_name.text = chapter.display_name
	var rec := GameState.get_chapter_record(chapter.id)
	var best := int(rec["best_time"])
	if best <= 0:
		chapter_best.text = "The forest is waiting..."
	else:
		chapter_best.text = "BEST  %02d:%02d   ·   %d KILLS" % [best / 60, best % 60, int(rec["best_kills"])]
	_start_pulse.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	# The hero walks a slow circle; the weapon system turns it to face targets.
	var a := _time * STROLL_TURN
	player.move_input = Vector2(-sin(a), cos(a)) * STROLL_SPEED
	player.tick(delta)
	weapon_system.tick(delta)
	enemies.tick(delta)
	projectiles.tick(delta)
	camera_rig.follow(player.position, delta)

	_spawn_timer -= delta
	while _spawn_timer <= 0.0:
		_spawn_timer += DEMO_SPAWN_INTERVAL
		if enemies.alive >= DEMO_CAP:
			continue
		var data := chapter.pick_enemy(DEMO_MIX_TIME, _rng)
		if data != null:
			enemies.spawn(data, enemies.spawn_position())


func _start_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	play_button.pivot_offset = play_button.size * 0.5
	play_button.scale = Vector2.ONE
	_pulse = create_tween().set_loops()
	_pulse.tween_property(play_button, "scale", Vector2(1.06, 1.06), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(play_button, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_play_pressed() -> void:
	if SceneRouter.is_busy():
		return
	SoundBank.ui("confirm")
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	play_button.disabled = true
	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(play_button, "scale", Vector2(1.15, 1.15), 0.12)
	SceneRouter.go_to(SceneRouter.GAME, {"chapter_id": GameState.selected_chapter_id})


func _on_settings_pressed() -> void:
	if settings_panel.visible:
		return
	SoundBank.ui("open")
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	play_button.scale = Vector2.ONE
	settings_panel.open()


func _on_coins_changed(amount: int) -> void:
	coins_label.text = str(amount)


## Debug hook for tools/shot.sh (--dev=settings).
func dev_command(cmd: String) -> void:
	match cmd:
		"settings":
			_on_settings_pressed()
		_:
			Log.warn("Menu", "Unknown dev command: " + cmd)
