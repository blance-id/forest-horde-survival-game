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
const FOOTSTEP_INTERVAL := 0.32
const GROWL_RANGE := 7.0
## Enemies further than this wind up silently: 200 tells at once is noise.
const TELL_RANGE := 6.0
## How long a kill from inside a bush keeps the hero visible.
const COVER_BLOWN_TIME := 4.0
## Tower ammo dropped by every ×5-and-up enemy.
const AMMO_PER_ELITE := 2

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
@onready var fx: FxManager = $Fx
@onready var towers: TowerManager = $Towers
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
var run_wood := 0
var run_ammo := 0
var upgrade_levels: Dictionary = {}  # UpgradeData -> level
var forest: Forest
var traps: Traps

var _chapter_id := "chapter_01"
var _spawn_timer := 0.0
var _events: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _pending_level_ups := 0
var _result_timer := -1.0
var _won := false
var _new_best := false
var _dev_move := Vector2.ZERO
var _hit_stop_until := 0
var _step_timer := 0.0
var _growl_timer := 1.0
## Seconds of blown cover left: killing from inside a bush gives you away.
var _exposed := 0.0


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

	forest = Forest.new()
	forest.name = "Forest"
	world.add_child(forest)
	forest.build(chapter, _rng.randi())
	forest.chopped.connect(_on_tree_chopped)
	forest.felled.connect(_on_tree_felled)

	traps = Traps.new()
	traps.name = "Traps"
	world.add_child(traps)
	traps.build(chapter, _rng.randi())
	traps.triggered.connect(_on_trap_triggered)

	player.bounds = ArenaBounds.from_chapter(chapter)
	# Connect before setup: setup emits the starting HP, and the HUD has to see
	# it or the bar keeps its scene default until the first hit.
	player.hp_changed.connect(hud.set_hp)
	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)
	player.setup(character, stats)

	enemies.player = player
	enemies.configure(chapter, ENEMY_CAPACITY)
	enemies.enemy_killed.connect(_on_enemy_killed)
	enemies.boss_spawned.connect(_on_boss_spawned)
	enemies.boss_killed.connect(_on_boss_killed)
	enemies.enemy_winding_up.connect(_on_enemy_winding_up)
	enemies.enemy_struck.connect(_on_enemy_struck)

	towers.configure(chapter, enemies, projectiles)
	towers.built.connect(_on_tower_built)
	towers.fired.connect(_on_tower_fired)
	towers.destroyed.connect(_on_tower_destroyed)
	towers.ammo_spent.connect(_on_tower_ammo_spent)

	projectiles.enemies = enemies
	projectiles.player = player
	projectiles.enemy_hit.connect(_on_enemy_hit)
	projectiles.bolt_landed.connect(_on_bolt_landed)

	weapon_system.player = player
	weapon_system.enemies = enemies
	weapon_system.projectiles = projectiles
	weapon_system.run_stats = stats
	weapon_system.enemy_hit.connect(_on_enemy_hit)
	weapon_system.fired.connect(_on_weapon_fired)
	weapon_system.aura_pulsed.connect(_on_aura_pulsed)
	weapon_system.add_or_upgrade(character.starting_weapon)

	pickups.player = player
	pickups.collected.connect(_on_pickup_collected)

	camera_rig.snap_to(player.position)
	camera_rig.make_current()

	hud.pause_pressed.connect(_pause)
	hud.build_pressed.connect(_build_tower)
	hud.setup_build_button(towers.data)
	hud.world_bars.enemies = enemies
	hud.world_bars.towers = towers
	hud.minimap.enemies = enemies
	hud.minimap.forest = forest
	hud.minimap.traps = traps
	hud.setup(chapter)
	hud.set_time(chapter.duration)
	hud.set_xp(0.0, xp_needed(level), level)
	hud.set_coins(0)
	hud.set_wood(0)
	hud.set_ammo(0)
	hud.set_build(weapon_system.slots, upgrade_levels)
	hud.show_move_hint()
	hud.show_announcement("SURVIVE %d MINUTES!" % roundi(chapter.duration / 60.0), 1.6)
	level_up_panel.chosen.connect(_on_upgrade_chosen)
	pause_panel.resume_pressed.connect(_resume)
	pause_panel.quit_pressed.connect(_give_up)
	result_panel.retry_pressed.connect(_retry)
	result_panel.menu_pressed.connect(_to_menu)

	_events = chapter.events.duplicate()
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	_spawn_timer = 0.5
	state = State.RUNNING
	AudioManager.play_music(chapter.music, 1.5)


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
			for u in upgrades.slice(0, 3):
				upgrade_levels[u] = 2
			hud.set_build(weapon_system.slots, upgrade_levels)
		"fx":
			# Fires every burst preset around the hero (pair with --lead=2).
			var p := player.position
			fx.level_up(p)
			fx.boss_death(p + Vector3(3.0, 0.0, -2.0), Color(0.9, 0.3, 0.3))
			fx.hero_hurt(p)
			for i in 6:
				var a := TAU * float(i) / 6.0
				var q := p + Vector3(cos(a), 0.0, sin(a)) * 2.2
				fx.death(q, Color.WHITE)
				fx.hit(q + Vector3(0, 0.45, 0), Vector2(cos(a), sin(a)), Color(1.0, 0.85, 0.35))
			fx.muzzle(player.muzzle_position(), player.aim_dir if player.aim_dir != Vector2.ZERO else Vector2.RIGHT, Color(1.0, 0.85, 0.35))
			fx.pickup(p + Vector3(-1.0, 0.3, 1.0), Color(0.35, 0.9, 1.0))
		"splats":
			for i in range(-8, 9):
				fx.splat(player.position + Vector3(float(i) * 0.4, 0.0, float(i)), Color(0.2, 0.34, 0.1, 0.9), 1.0)
		"nuke":
			# Kills every enemy alive: exercises death effects, drops and kills UI.
			for e in enemies.enemies.duplicate():
				if not e.dying:
					enemies.hit(e, 1e9, e.pos + Vector2(0.0, 0.5), 0.0)
		"tower":
			# Beside the hero, not under them, so the nest is actually visible.
			run_wood += 40
			run_ammo += 400
			hud.set_wood(run_wood)
			hud.set_ammo(run_ammo)
			towers.build(Vector2(player.position.x + 2.5, player.position.z))
		"chop":
			# Park the hero next to a trunk so the chop loop can be watched.
			var trunk := forest.nearest_trunk(Vector2.ZERO, 1e9)
			if trunk != null:
				player.position = Vector3(trunk.pos.x + 1.2, 0.0, trunk.pos.y)
				camera_rig.snap_to(player.position)
		"hide":
			if not forest.bushes.is_empty():
				var b: Forest.Bush = forest.bushes[0]
				player.position = Vector3(b.pos.x, 0.0, b.pos.y)
				camera_rig.snap_to(player.position)
		"trap":
			if not traps.traps.is_empty():
				var t: Traps.Trap = traps.traps[0]
				player.position = Vector3(t.pos.x, 0.0, t.pos.y)
				camera_rig.snap_to(player.position)
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
	_tick_ambience(delta)
	hud.set_time(chapter.duration - run_time)
	if enemies.boss != null:
		hud.set_boss(enemies.boss.hp, enemies.boss.max_hp)
	if run_time >= chapter.duration:
		_win()


func _tick_world(delta: float) -> void:
	player.tick(delta)
	_tick_cover(delta)
	var hero := Vector2(player.position.x, player.position.z)
	forest.tick(delta, hero)
	traps.tick(delta, player, enemies)
	towers.tick(delta, hero, run_ammo)
	hud.set_can_build(towers.can_build(hero, run_wood))
	weapon_system.tick(delta)
	enemies.tick(delta)
	projectiles.tick(delta)
	pickups.tick(delta)
	fx.tick(delta)
	camera_rig.follow(player.position, delta, player.move_input)
	hud.place_hero_hp(camera_rig.camera, player.position)
	hud.tick(camera_rig.camera, delta)


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


## Hero footsteps and the horde's idle groans: the nearest zombies grumble
## every second or so, louder the closer they are.
func _tick_ambience(delta: float) -> void:
	if player.move_input != Vector2.ZERO and not player.is_dead:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = FOOTSTEP_INTERVAL
			SoundBank.sfx("footstep", -22.0, 0.15)
	else:
		_step_timer = 0.0
	_growl_timer -= delta
	if _growl_timer > 0.0 or enemies.alive == 0:
		return
	_growl_timer = _rng.randf_range(0.6, 1.4)
	var e: EnemyManager.Enemy = enemies.enemies[_rng.randi() % enemies.enemies.size()]
	if e.dying:
		return
	var dist := e.pos.distance_to(Vector2(player.position.x, player.position.z))
	if dist > GROWL_RANGE:
		return
	SoundBank.sfx("zombie_growl", lerpf(-8.0, -20.0, dist / GROWL_RANGE), 0.2)


## Standing in a bush breaks the horde's line of sight — until you kill from
## inside it, which gives your position away for a few seconds.
func _tick_cover(delta: float) -> void:
	_exposed = maxf(0.0, _exposed - delta)
	var hidden := _exposed <= 0.0 and not player.is_dead \
		and forest.hides(Vector2(player.position.x, player.position.z))
	if hidden != enemies.player_hidden:
		enemies.player_hidden = hidden
		hud.set_hidden(hidden)


## One tap, no placement mode: the nest goes up where the hero is standing.
func _build_tower() -> void:
	var hero := Vector2(player.position.x, player.position.z)
	if not towers.can_build(hero, run_wood):
		SoundBank.ui("back")
		hud.show_announcement("NEED %d WOOD" % towers.data.wood_cost, 1.2)
		return
	run_wood -= towers.data.wood_cost
	hud.set_wood(run_wood)
	towers.build(hero)


func _on_tower_built(position: Vector2) -> void:
	SoundBank.sfx("wood_impact", -4.0, 0.0)
	SoundBank.ui("confirm")
	fx.level_up(Vector3(position.x, 0.2, position.y))
	camera_rig.shake(0.2)


func _on_tower_fired(position: Vector3, dir: Vector2) -> void:
	fx.muzzle(position, dir, towers.data.weapon.tint)


func _on_tower_destroyed(position: Vector3) -> void:
	SoundBank.sfx("explosion", -4.0, 0.05)
	fx.boss_death(position, Color(0.6, 0.85, 1.0))
	camera_rig.shake(0.4)
	hud.show_announcement("NEST DOWN!", 1.4)


func _on_tower_ammo_spent(amount: int) -> void:
	run_ammo = maxi(0, run_ammo - amount)
	hud.set_ammo(run_ammo)


func _on_tree_chopped(position: Vector3, ratio: float) -> void:
	SoundBank.sfx("chop", -10.0, 0.1)
	fx.hit(position, Vector2.ZERO, Color(0.75, 0.55, 0.3))
	hud.set_chop(ratio)


func _on_tree_felled(position: Vector2, wood: int) -> void:
	SoundBank.sfx("wood_impact", -6.0, 0.05)
	camera_rig.shake(0.15)
	hud.set_chop(-1.0)
	for i in wood:
		var a := TAU * float(i) / float(maxi(1, wood))
		pickups.drop(PickupManager.Kind.WOOD, position + Vector2(cos(a), sin(a)) * 0.6, 1.0)


func _on_trap_triggered(position: Vector3, hit_player: bool) -> void:
	SoundBank.sfx("metal_impact", -8.0 if hit_player else -14.0, 0.05)
	fx.hit(position + Vector3(0.0, 0.4, 0.0), Vector2.ZERO, Color(1.0, 0.4, 0.2))


# --- Combat feedback ---------------------------------------------------------

func _on_enemy_hit(e: EnemyManager.Enemy, position: Vector3, dir: Vector2, amount: float, killed: bool, weapon: WeaponData) -> void:
	hud.damage_numbers.spawn(e.position3d() + Vector3(0, 1.1 * e.data().scale, 0), amount,
		DamageNumbers.Style.KILL if killed else DamageNumbers.Style.HIT)
	if killed:
		return
	SoundBank.sfx(weapon.hit_sound, -8.0, 0.15)
	fx.hit(position, dir, weapon.tint)


func _on_weapon_fired(weapon: WeaponData, from: Vector3, dir: Vector2) -> void:
	SoundBank.sfx(weapon.fire_sound, -12.0, 0.12)
	fx.muzzle(from, dir, weapon.tint)


func _on_aura_pulsed(weapon: WeaponData, position: Vector3, radius: float) -> void:
	SoundBank.sfx(weapon.fire_sound, -10.0, 0.05)
	fx.aura_pulse(position, radius, weapon.tint)


func _on_enemy_killed(e: EnemyManager.Enemy) -> void:
	var d := e.data()
	if enemies.player_hidden:
		_exposed = COVER_BLOWN_TIME
	SoundBank.sfx("zombie_die", -6.0, 0.2)
	if d.is_boss:
		SoundBank.sfx("explosion", -2.0, 0.05)
		SoundBank.sfx("zombie_death", 0.0, 0.0)
		fx.boss_death(e.position3d(), d.tint)
	else:
		SoundBank.sfx("zombie_death", -9.0, 0.25)
		fx.death(e.position3d(), d.tint)
	hud.set_kills(enemies.kills)
	pickups.drop(PickupManager.Kind.XP, e.pos, float(d.xp))
	if _rng.randf() < d.coin_chance:
		pickups.drop(PickupManager.Kind.COIN, e.pos + Vector2(0.3, 0.0), 1.0 if not d.is_boss else 25.0)
	if d.is_elite():
		pickups.drop(PickupManager.Kind.AMMO, e.pos + Vector2(0.0, -0.35), float(AMMO_PER_ELITE))
	if _rng.randf() < HEAL_DROP_CHANCE:
		pickups.drop(PickupManager.Kind.HEAL, e.pos + Vector2(-0.3, 0.0), HEAL_AMOUNT)
	if d.is_boss:
		camera_rig.shake(0.8)
		Haptics.heavy()
		_hit_stop(0.05, 0.16)


## The tell. Only enemies close enough to matter make a sound or throw sparks,
## otherwise a big horde would wind up as one wall of noise.
func _on_enemy_winding_up(e: EnemyManager.Enemy) -> void:
	var d := e.data()
	var dist := e.pos.distance_to(Vector2(player.position.x, player.position.z))
	if dist > TELL_RANGE:
		return
	if d.windup_sound != "":
		SoundBank.sfx(d.windup_sound, lerpf(-12.0, -22.0, dist / TELL_RANGE), 0.12)
	fx.hit(e.position3d() + Vector3(0.0, 0.9 * d.scale, 0.0), Vector2.ZERO, d.tint.lightened(0.4))


func _on_enemy_struck(e: EnemyManager.Enemy, target: Vector2) -> void:
	var d := e.data()
	if d.ranged:
		projectiles.spawn_enemy_bolt(e.position3d() + Vector3(0.0, 0.9 * d.scale, 0.0), target, d)
		SoundBank.sfx("force_field", -12.0, 0.1)
		return
	SoundBank.sfx("zombie_attack", -12.0, 0.12)
	fx.hit(Vector3(target.x, 0.7, target.y), (target - e.pos).normalized(), d.tint)


func _on_bolt_landed(position: Vector3, _damage: float, hit_player: bool) -> void:
	fx.death(position, Color(0.7, 0.4, 1.0))
	SoundBank.sfx("glass_break" if hit_player else "slime", -14.0, 0.08)


func _on_boss_spawned(e: EnemyManager.Enemy) -> void:
	hud.set_boss(e.hp, e.max_hp, e.data().display_name)
	hud.show_announcement("BOSS INCOMING!", 2.2)
	SoundBank.sfx("bell", -2.0, 0.0)
	SoundBank.sfx("boss_roar", 0.0, 0.1)
	AudioManager.play_music(chapter.boss_music, 0.8)
	camera_rig.shake(0.5)
	Haptics.heavy()


func _on_boss_killed(_e: EnemyManager.Enemy) -> void:
	hud.set_boss(0.0, 1.0)
	hud.show_announcement("BOSS DOWN!", 2.0)
	SoundBank.jingle("reward", -2.0)
	AudioManager.play_music(chapter.music, 2.5)


func _on_player_damaged(amount: float) -> void:
	SoundBank.sfx("hit_player", -6.0, 0.1)
	SoundBank.sfx("zombie_attack", -9.0, 0.2)
	camera_rig.shake(0.25)
	fx.hero_hurt(player.position)
	hud.flash_damage()
	hud.damage_numbers.spawn(player.position + Vector3(0, 1.3, 0), amount, DamageNumbers.Style.HERO)
	Haptics.medium()


## Freezes the action for `duration` real seconds (boss kill punch). The
## timer ignores time scale so it always ends; a later call just extends it.
func _hit_stop(scale: float, duration: float) -> void:
	Engine.time_scale = scale
	_hit_stop_until = Time.get_ticks_msec() + int(duration * 1000.0)
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void:
		if Time.get_ticks_msec() >= _hit_stop_until:
			Engine.time_scale = 1.0)


func _on_pickup_collected(kind: PickupManager.Kind, value: float, position: Vector3) -> void:
	match kind:
		PickupManager.Kind.XP:
			SoundBank.sfx("pickup_xp", -16.0, 0.25)
			fx.pickup(position, Color(0.35, 0.9, 1.0))
			_gain_xp(value * stats.xp_mult())
		PickupManager.Kind.COIN:
			SoundBank.sfx("pickup_coin", -8.0, 0.1)
			fx.pickup(position, Color(1.0, 0.85, 0.3))
			run_coins += int(value)
			hud.add_coins(int(value), position, camera_rig.camera)
		PickupManager.Kind.HEAL:
			SoundBank.sfx("chest_open", -6.0, 0.05)
			fx.pickup(position, Color(1.0, 0.4, 0.5))
			player.heal(stats.max_hp() * value)
		PickupManager.Kind.WOOD:
			SoundBank.sfx("wood_impact", -16.0, 0.08)
			fx.pickup(position, Color(0.8, 0.6, 0.35))
			run_wood += int(value)
			hud.set_wood(run_wood)
		PickupManager.Kind.AMMO:
			SoundBank.sfx("reload", -10.0, 0.08)
			fx.pickup(position, Color(0.9, 0.85, 0.4))
			run_ammo += int(value)
			hud.set_ammo(run_ammo)


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
	fx.level_up(player.position)
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
	hud.set_build(weapon_system.slots, upgrade_levels)
	_pending_level_ups = maxi(0, _pending_level_ups - 1)
	if _pending_level_ups > 0:
		_open_level_up()
		return
	get_tree().paused = false
	AudioManager.duck_music(false)
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
	AudioManager.duck_music(true)


func _resume() -> void:
	if state != State.PAUSED:
		return
	pause_panel.close()
	get_tree().paused = false
	AudioManager.duck_music(false)
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
	AudioManager.stop_music(0.6)
	_end(false)
	_show_result()


func _on_player_died() -> void:
	AudioManager.stop_music(1.2)
	SoundBank.jingle("lose", -2.0)
	camera_rig.shake(0.6)
	Haptics.heavy()
	_hit_stop(0.25, 0.9)
	_end(false)
	_result_timer = RESULT_DELAY


func _win() -> void:
	AudioManager.stop_music(0.6)
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
	# record_run banks the coins as well.
	_new_best = GameState.record_run(chapter.id, run_time, enemies.kills, won, reward)
	Log.info("Game", "Run over: won=%s time=%.1f kills=%d level=%d coins=%d" % [won, run_time, enemies.kills, level, reward])


func _show_result() -> void:
	_result_timer = -1.0
	if result_panel.visible:
		return
	result_panel.show_result(_won, chapter.display_name, run_time, enemies.kills, level, run_coins, _new_best)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	AudioManager.duck_music(false)


func _retry() -> void:
	SoundBank.ui("click")
	SceneRouter.go_to(SceneRouter.GAME, {"chapter_id": _chapter_id, "character": character})


func _to_menu() -> void:
	SoundBank.ui("back")
	SceneRouter.go_to(SceneRouter.MAIN_MENU)
