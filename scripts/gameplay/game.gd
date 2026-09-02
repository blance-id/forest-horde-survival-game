## One run of a chapter. Builds the world from ChapterData, drives every
## manager in a fixed order each frame, runs the spawn director, XP/level-ups,
## win/lose and hands the result to GameState.
class_name Game
extends Node3D

enum State { RUNNING, LEVEL_UP, PAUSED, OVER }

const RESULT_DELAY := 1.6
const RING_RADIUS := 9.0
const ENEMY_CAPACITY := 300
const HEAL_DROP_CHANCE := 0.012
const HEAL_AMOUNT := 0.3

@export var weapons: Array[WeaponData] = []
@export var upgrades: Array[UpgradeData] = []
@export var default_character: CharacterData

@onready var world: Node3D = $World
@onready var camera_rig: CameraRig = $CameraRig
@onready var player: Player = $Player
@onready var enemies: EnemyManager = $Enemies
@onready var projectiles: ProjectileManager = $Projectiles
@onready var weapon_system: WeaponSystem = $Weapons
@onready var pickups: PickupManager = $Pickups
@onready var hud: HUD = $UI/HUD
@onready var level_up_panel: LevelUpPanel = $UI/LevelUpPanel
@onready var pause_panel: PausePanel = $UI/PausePanel
@onready var result_panel: ResultPanel = $UI/ResultPanel

var chapter: ChapterData
var character: CharacterData
var stats: RunStats
var state := State.RUNNING
var run_time := 0.0
var level := 1
var xp := 0.0
var run_coins := 0
var upgrade_levels: Dictionary = {}  # UpgradeData -> level

var _chapter_id := "chapter_01"
var _spawn_timer := 0.0
var _events: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _pending_level_ups := 0
var _result_timer := -1.0
var _won := false
var _dev_move := Vector2.ZERO


func setup(data: Dictionary) -> void:
	_chapter_id = String(data.get("chapter_id", _chapter_id))
	chapter = load("res://resources/chapters/%s.tres" % _chapter_id)
	character = data.get("character", default_character)
	_start_run()


func _ready() -> void:
	# Running the scene directly (F6 / tools/shot.sh) has no router data; the
	# router calls setup() right after add_child, so check one frame later.
	(func() -> void:
		if chapter == null:
			setup({})).call_deferred()


func _start_run() -> void:
	Log.info("Game", "Run started: %s as %s" % [chapter.id, character.id])
	_rng.randomize()
	stats = RunStats.from_character(character)
	_apply_meta_upgrades()

	var arena := Arena.new()
	arena.name = "Arena"
	world.add_child(arena)
	arena.build(chapter, _rng.randi())

	player.arena_half = chapter.arena_half_size
	player.setup(character, stats)
	player.hp_changed.connect(hud.set_hp)
	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)

	enemies.player = player
	enemies.configure(chapter, ENEMY_CAPACITY)
	enemies.enemy_killed.connect(_on_enemy_killed)
	enemies.boss_spawned.connect(_on_boss_spawned)
	enemies.boss_killed.connect(_on_boss_killed)

	projectiles.enemies = enemies
	projectiles.enemy_hit.connect(_on_enemy_hit)

	weapon_system.player = player
	weapon_system.enemies = enemies
	weapon_system.projectiles = projectiles
	weapon_system.run_stats = stats
	weapon_system.enemy_hit.connect(_on_enemy_hit)
	weapon_system.fired.connect(_on_weapon_fired)
	weapon_system.add_or_upgrade(character.starting_weapon)

	pickups.player = player
	pickups.collected.connect(_on_pickup_collected)

	camera_rig.snap_to(player.position)
	camera_rig.make_current()

	hud.pause_pressed.connect(_pause)
	hud.set_time(chapter.duration)
	hud.set_xp(0.0, xp_needed(level), level)
	hud.set_kills(0)
	hud.set_coins(0)
	hud.show_move_hint()
	level_up_panel.chosen.connect(_on_upgrade_chosen)
	pause_panel.resume_pressed.connect(_resume)
	pause_panel.quit_pressed.connect(_give_up)
	result_panel.retry_pressed.connect(_retry)
	result_panel.menu_pressed.connect(_to_menu)

	_events = chapter.events.duplicate()
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	_spawn_timer = 0.5
	state = State.RUNNING


func _apply_meta_upgrades() -> void:
	# Permanent shop upgrades are additive on the same RunStats keys.
	for u in upgrades:
		var meta := GameState.get_meta_level(u.id)
		if meta > 0:
			stats.add(u.stat, u.value_per_level * meta)


## Debug hooks used by tools/shot.sh (--dev=...) to reach specific states.
func dev_command(cmd: String) -> void:
	match cmd:
		"levelup":
			_gain_xp(xp_needed(level) - xp + 0.01)
		"pause":
			_pause()
		"win":
			_win()
		"die":
			player.take_damage(1e9)
		"hurt":
			player.take_damage(stats.max_hp() * 0.5)
		"horde":
			_run_event({"kind": "ring", "enemy": chapter.waves[0]["enemy"], "count": 40})
		"boss":
			for ev in chapter.events:
				if ev.get("kind") == "boss":
					_run_event(ev)
					break
		"weapons":
			for w in weapons:
				for i in 3:
					weapon_system.add_or_upgrade(w)
		"move":
			_dev_move = Vector2(0.6, -0.8)
		"stop":
			_dev_move = Vector2.ZERO
		"touch":
			# Fake a finger landing and dragging so the joystick path renders.
			var press := InputEventScreenTouch.new()
			press.index = 0
			press.pressed = true
			press.position = Vector2(360, 900)
			Input.parse_input_event(press)
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = Vector2(430, 850)
			drag.relative = drag.position - press.position
			Input.parse_input_event(drag)
		_:
			Log.warn("Game", "Unknown dev command: " + cmd)


# --- Frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if chapter == null:
		return
	if state == State.OVER:
		_tick_world(delta)
		if _result_timer >= 0.0:
			_result_timer -= delta
			if _result_timer < 0.0:
				_show_result()
		return
	if state != State.RUNNING:
		return
	run_time += delta
	# The joystick also carries the keyboard fallback when no finger is down.
	var stick := hud.joystick.direction
	player.move_input = stick if stick != Vector2.ZERO else _dev_move
	_tick_world(delta)
	_tick_director(delta)
	hud.set_time(chapter.duration - run_time)
	if enemies.boss != null:
		hud.set_boss(enemies.boss.hp, enemies.boss.max_hp)
	if run_time >= chapter.duration:
		_win()


func _tick_world(delta: float) -> void:
	player.tick(delta)
	weapon_system.tick(delta)
	enemies.tick(delta)
	projectiles.tick(delta)
	pickups.tick(delta)
	camera_rig.follow(player.position, delta, player.move_input)
	hud.place_hero_hp(camera_rig.camera, player.position)


func _tick_director(delta: float) -> void:
	_spawn_timer -= delta
	var cap := chapter.enemy_cap(run_time)
	while _spawn_timer <= 0.0:
		_spawn_timer += chapter.spawn_interval(run_time)
		if enemies.alive >= cap:
			continue
		var data := chapter.pick_enemy(run_time, _rng)
		if data != null:
			enemies.spawn(data, enemies.spawn_position(), chapter.hp_scale(run_time))
	while not _events.is_empty() and run_time >= float(_events[0]["time"]):
		_run_event(_events.pop_front())


func _run_event(ev: Dictionary) -> void:
	var data: EnemyData = ev["enemy"]
	var count := int(ev.get("count", 1))
	var hp_scale := chapter.hp_scale(run_time)
	match String(ev.get("kind", "ring")):
		"boss":
			for i in count:
				enemies.spawn(data, enemies.spawn_position(), hp_scale)
		_:
			enemies.spawn_ring(data, count, RING_RADIUS, hp_scale)
			hud.show_announcement("HORDE INCOMING!", 1.6)
			camera_rig.shake(0.35)


# --- Combat feedback ---------------------------------------------------------

func _on_enemy_hit(_enemy: EnemyManager.Enemy, _position: Vector3, killed: bool) -> void:
	if not killed:
		SoundBank.sfx("hit_zombie", -8.0, 0.15)


func _on_weapon_fired(_weapon: WeaponData, _from: Vector3, _dir: Vector2) -> void:
	SoundBank.sfx("knife", -14.0, 0.2)


func _on_enemy_killed(e: EnemyManager.Enemy) -> void:
	var d := e.data()
	SoundBank.sfx("zombie_die", -4.0, 0.2)
	hud.set_kills(enemies.kills)
	pickups.drop(PickupManager.Kind.XP, e.pos, float(d.xp))
	if _rng.randf() < d.coin_chance:
		pickups.drop(PickupManager.Kind.COIN, e.pos + Vector2(0.3, 0.0), 1.0 if not d.is_boss else 25.0)
	if _rng.randf() < HEAL_DROP_CHANCE:
		pickups.drop(PickupManager.Kind.HEAL, e.pos + Vector2(-0.3, 0.0), HEAL_AMOUNT)
	if d.is_boss:
		camera_rig.shake(0.8)
		Haptics.heavy()


func _on_boss_spawned(_e: EnemyManager.Enemy) -> void:
	hud.show_announcement("BOSS INCOMING!", 2.2)
	SoundBank.sfx("bell", -2.0, 0.0)
	camera_rig.shake(0.5)
	Haptics.heavy()


func _on_boss_killed(_e: EnemyManager.Enemy) -> void:
	hud.set_boss(0.0, 1.0)
	hud.show_announcement("BOSS DOWN!", 2.0)
	SoundBank.jingle("reward", -2.0)


func _on_player_damaged(_amount: float) -> void:
	SoundBank.sfx("hit_player", -6.0, 0.1)
	camera_rig.shake(0.25)
	Haptics.medium()


func _on_pickup_collected(kind: PickupManager.Kind, value: float, _position: Vector3) -> void:
	match kind:
		PickupManager.Kind.XP:
			SoundBank.sfx("pickup_xp", -16.0, 0.25)
			_gain_xp(value * stats.xp_mult())
		PickupManager.Kind.COIN:
			SoundBank.sfx("pickup_coin", -8.0, 0.1)
			run_coins += int(value)
			hud.set_coins(run_coins)
		PickupManager.Kind.HEAL:
			SoundBank.sfx("chest_open", -6.0, 0.05)
			player.heal(stats.max_hp() * value)


# --- XP / level ups ----------------------------------------------------------

func xp_needed(for_level: int) -> float:
	return 10.0 + for_level * 5.0 + for_level * for_level * 0.6


func _gain_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		_pending_level_ups += 1
	hud.set_xp(xp, xp_needed(level), level)
	if _pending_level_ups > 0 and state == State.RUNNING:
		_open_level_up()


func _open_level_up() -> void:
	var options := _roll_options(3)
	if options.is_empty():
		_pending_level_ups = 0
		return
	state = State.LEVEL_UP
	_freeze()
	SoundBank.jingle("level_up", -4.0)
	Haptics.light()
	level_up_panel.offer(options)


func _roll_options(count: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var weights: Array[float] = []
	var held := weapon_system.slots.size()
	for w in weapons:
		var lv := weapon_system.level_of(w)
		if lv >= w.max_level:
			continue
		if lv == 0 and held >= 4:
			continue  # four weapon slots
		candidates.append({"weapon": w, "level": lv + 1})
		weights.append(1.4 if lv > 0 else 1.0)
	for u in upgrades:
		var lv := int(upgrade_levels.get(u, 0))
		if lv >= u.max_level:
			continue
		candidates.append({"upgrade": u, "level": lv + 1})
		weights.append(1.0)
	var picked: Array[Dictionary] = []
	while picked.size() < count and not candidates.is_empty():
		var total := 0.0
		for wgt in weights:
			total += wgt
		var r := _rng.randf() * total
		var idx := 0
		for i in weights.size():
			r -= weights[i]
			if r <= 0.0:
				idx = i
				break
		picked.append(candidates[idx])
		candidates.remove_at(idx)
		weights.remove_at(idx)
	return picked


func _on_upgrade_chosen(option: Dictionary) -> void:
	if option.has("weapon"):
		weapon_system.add_or_upgrade(option["weapon"])
	else:
		var u: UpgradeData = option["upgrade"]
		var previous_max := stats.max_hp()
		upgrade_levels[u] = int(upgrade_levels.get(u, 0)) + 1
		stats.add(u.stat, u.value_per_level)
		if u.stat == "max_hp_mult":
			player.refresh_max_hp(previous_max)
	SoundBank.ui("confirm")
	_pending_level_ups = maxi(0, _pending_level_ups - 1)
	if _pending_level_ups > 0:
		_open_level_up()
		return
	get_tree().paused = false
	state = State.RUNNING


# --- Pause / end -------------------------------------------------------------

func _pause() -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	_freeze()
	SoundBank.ui("click")
	pause_panel.open()


## Pauses the tree and drops the joystick touch: the HUD stops receiving
## input while paused, so the finger's release would otherwise never arrive
## and the hero would keep walking after the panel closes.
func _freeze() -> void:
	get_tree().paused = true
	hud.joystick.reset()
	player.move_input = Vector2.ZERO


func _resume() -> void:
	if state != State.PAUSED:
		return
	pause_panel.close()
	get_tree().paused = false
	state = State.RUNNING


func on_app_background() -> void:
	_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.RUNNING:
			_pause()
		elif state == State.PAUSED:
			_resume()


func _give_up() -> void:
	pause_panel.close()
	get_tree().paused = false
	_end(false)
	_show_result()


func _on_player_died() -> void:
	SoundBank.jingle("lose", -2.0)
	camera_rig.shake(0.6)
	Haptics.heavy()
	_end(false)
	_result_timer = RESULT_DELAY


func _win() -> void:
	SoundBank.jingle("win", -2.0)
	enemies.clear_all()
	projectiles.clear_all()
	hud.show_announcement("SURVIVED!", 2.0)
	_end(true)
	_result_timer = RESULT_DELAY


func _end(won: bool) -> void:
	if state == State.OVER:
		return
	state = State.OVER
	_won = won
	hud.joystick.reset()
	player.move_input = Vector2.ZERO
	var minutes := run_time / 60.0
	var reward := run_coins + int(chapter.coins_per_minute * minutes)
	if won:
		reward += chapter.coins_win
	run_coins = reward
	GameState.record_run(chapter.id, run_time, enemies.kills, won, reward)
	GameState.add_coins(reward)
	Log.info("Game", "Run over: won=%s time=%.1f kills=%d level=%d coins=%d" % [won, run_time, enemies.kills, level, reward])


func _show_result() -> void:
	_result_timer = -1.0
	if result_panel.visible:
		return
	result_panel.show_result(_won, chapter.display_name, run_time, enemies.kills, level, run_coins)


func _retry() -> void:
	SoundBank.ui("click")
	SceneRouter.go_to(SceneRouter.GAME, {"chapter_id": _chapter_id, "character": character})


func _to_menu() -> void:
	SoundBank.ui("back")
	SceneRouter.go_to(SceneRouter.MAIN_MENU)
