## One run of a chapter. Builds the world from ChapterData, drives every
## manager in a fixed order each frame, runs the spawn director, XP/level-ups,
## win/lose and hands the result to GameState.
class_name Game
extends Node3D

enum State { RUNNING, BOSS_INTRO, LEVEL_UP, PAUSED, DYING, OVER }

const RING_RADIUS := 9.0
## Beat between the boss dying and the victory badge, so the kill lands first.
const BOSS_WIN_DELAY := 1.3
## Grace before the first wave walks in.
const FIRST_WAVE_DELAY := 1.6
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
## How many weapons the hero can carry at once.
const WEAPON_SLOTS := 4
## Seconds of grace after a revive, and how far the horde is blown back.
const REVIVE_GRACE := 2.0
const REVIVE_CLEAR := 6.0
## The boss entrance: how long everything else stands still.
const BOSS_INTRO_TIME := 3.0
const LAUGH_BEAT := 1.1

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
@onready var vehicles: VehicleManager = $Vehicles
@onready var hud: HUD = $UI/HUD
@onready var level_up_panel: LevelUpPanel = $UI/LevelUpPanel
@onready var pause_panel: PausePanel = $UI/PausePanel
@onready var result_panel: ResultPanel = $UI/ResultPanel
@onready var revive_panel: RevivePanel = $UI/RevivePanel
@onready var outcome: OutcomeOverlay = $UI/OutcomeOverlay

var chapter: ChapterData
var character: CharacterData
var stats: RunStats
var state := State.RUNNING
var run_time := 0.0
var level := 1
var xp := 0.0
var run_coins := 0
var wave_index := 0
var run_wood := 0
var run_ammo := 0
var upgrade_levels: Dictionary = {}  # UpgradeData -> level
var forest: Forest
var traps: Traps
var survivors: Survivors
## Relics carried into this run, and whether each has been spent.
var bag: Array[RelicData] = []
var bag_spent: Array[bool] = []

var _chapter_id := "chapter_01"
var _spawn_timer := 0.0
## Bodies still to send in the current wave, in spawn order.
var _wave_queue: Array[EnemyData] = []
var _wave_total := 0
## Counts down the breather between waves; <= 0 means a wave is running.
var _wave_break := 0.0
## Set when the boss dies, so its death spectacle plays before the badge.
var _win_delay := -1.0
var _rng := RandomNumberGenerator.new()
var _pending_level_ups := 0
var _intro_time := -1.0
var _last_laugh := -1
var _won := false
var _new_best := false
var _dev_move := Vector2.ZERO
var _hit_stop_until := 0
var _step_timer := 0.0
var _growl_timer := 1.0
## Seconds of blown cover left: killing from inside a bush gives you away.
var _exposed := 0.0
## Revives bought this run; each one doubles the next price.
var _revives := 0


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

	survivors = Survivors.new()
	survivors.name = "Survivors"
	world.add_child(survivors)
	survivors.build(chapter, _rng.randi())
	survivors.progress.connect(_on_rescue_progress)
	survivors.rescued.connect(_on_survivor_rescued)

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

	vehicles.configure(chapter, enemies, projectiles, player, _rng.randi())
	vehicles.mounted.connect(_on_vehicle_mounted)
	vehicles.dismounted.connect(_on_vehicle_dismounted)
	vehicles.fired.connect(_on_vehicle_fired)
	vehicles.state_changed.connect(hud.set_vehicle)

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
	Quality.apply_to_viewport(get_viewport())

	hud.pause_pressed.connect(_pause)
	hud.build_pressed.connect(_build_tower)
	hud.relic_used.connect(_use_relic)
	hud.setup_build_button(towers.data)
	hud.world_bars.enemies = enemies
	hud.world_bars.towers = towers
	hud.minimap.enemies = enemies
	hud.minimap.forest = forest
	hud.minimap.traps = traps
	hud.setup(chapter)
	hud.set_time(0.0)
	hud.set_xp(0.0, xp_needed(level), level)
	hud.set_coins(0)
	hud.set_wood(0)
	hud.set_ammo(0)
	# Taking the bag removes it from the inventory: these are in the field now.
	bag = RelicCatalog.resolve(GameState.take_bag())
	bag_spent.clear()
	for i in bag.size():
		bag_spent.append(false)
	hud.set_bag_items(bag, bag_spent)
	hud.set_build(weapon_system.slots, upgrade_levels)
	hud.show_move_hint()
	level_up_panel.chosen.connect(_on_upgrade_chosen)
	pause_panel.resume_pressed.connect(_resume)
	pause_panel.quit_pressed.connect(_give_up)
	revive_panel.revive_pressed.connect(_do_revive)
	revive_panel.declined.connect(_after_death)
	outcome.finished.connect(_on_outcome_finished)
	result_panel.retry_pressed.connect(_retry)
	result_panel.menu_pressed.connect(_to_menu)

	_wave_break = FIRST_WAVE_DELAY
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
		"bag":
			# Fill the bag so the relic buttons can be seen and tapped.
			bag = RelicCatalog.all().slice(0, 3)
			bag_spent.clear()
			for i in bag.size():
				bag_spent.append(false)
			hud.set_bag_items(bag, bag_spent)
		"mech":
			# Park a mech on the hero so the pilot state can be inspected.
			if not vehicles.vehicles.is_empty():
				var v: VehicleManager.Vehicle = vehicles.vehicles[0]
				player.position = Vector3(v.pos.x, 0.0, v.pos.y)
				camera_rig.snap_to(player.position)
		"rescue":
			if not survivors.survivors.is_empty():
				var sv: Survivors.Survivor = survivors.survivors[0]
				player.position = Vector3(sv.pos.x + 1.0, 0.0, sv.pos.y)
				camera_rig.snap_to(player.position)
		"chapter2":
			SceneRouter.go_to(SceneRouter.GAME, {"chapter_id": "chapter_02", "character": character})
		"beasts":
			# A pack of wolves and a pair of serpents, close enough to inspect.
			enemies.spawn_ring(load("res://resources/enemies/wolf.tres") as EnemyData, 6, 4.5, 1.0)
			enemies.spawn_ring(load("res://resources/enemies/serpent.tres") as EnemyData, 2, 7.0, 1.0)
		"hexer":
			# A ring of casters, close enough that their bolts are in flight.
			var hexer := load("res://resources/enemies/hexer.tres") as EnemyData
			enemies.spawn_ring(hexer, 7, 5.0, 1.0)
		"horde":
			var trash := chapter.demo_enemy(_rng)
			if trash != null:
				enemies.spawn_ring(trash, 40, RING_RADIUS, 1.0)
		"boss":
			# Jump straight to the last wave, which is the boss.
			_wave_queue.clear()
			enemies.clear_all()
			wave_index = maxi(0, chapter.wave_count() - 1)
			_wave_break = 0.0
			_start_wave()
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
					enemies.hit(e, 1e9, e.pos + Vector2(0.0, 0.5), 0.0, Damage.Type.TRUE)
		"tower":
			# Beside the hero, not under them, so the nest is actually visible.
			run_wood += 300
			run_ammo += 600
			hud.set_wood(run_wood)
			hud.set_ammo(run_ammo)
			towers.build_or_upgrade(Vector2(player.position.x + 2.0, player.position.z - 1.0))
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
	# Runs in every state: a freeze must lift even while the boss entrance or
	# the death overlay owns the frame.
	_tick_hit_stop()
	if state == State.BOSS_INTRO:
		_tick_boss_intro(delta)
		return
	# DYING, PAUSED, LEVEL_UP and OVER all freeze the tree; the overlays and
	# panels that run during them are on ALWAYS process mode and drive
	# themselves.
	if state != State.RUNNING:
		return
	run_time += delta
	# The joystick also carries the keyboard fallback when no finger is down.
	var stick := hud.joystick.direction
	player.move_input = stick if stick != Vector2.ZERO else _dev_move
	_tick_world(delta)
	_tick_director(delta)
	_tick_ambience(delta)
	hud.set_time(run_time)
	if enemies.boss != null:
		hud.set_boss(enemies.boss.hp, enemies.boss.max_hp)
	if _win_delay >= 0.0:
		_win_delay -= delta
		if _win_delay < 0.0:
			_win()


func _tick_world(delta: float) -> void:
	player.tick(delta)
	_tick_cover(delta)
	weapon_system.enabled = not vehicles.is_piloting()
	# A nest is solid: shove the hero back out before anything reads their
	# position, or the two models merge into one another.
	var pushed := towers.push_out(Vector2(player.position.x, player.position.z), Player.RADIUS)
	player.position = Vector3(pushed.x, player.position.y, pushed.y)
	var hero := pushed
	forest.tick(delta, hero)
	_crush_forest()
	traps.tick(delta, player, enemies)
	towers.tick(delta, hero, run_ammo)
	vehicles.tick(delta, hero)
	survivors.tick(delta, hero)
	hud.set_build_action(towers.can_act(hero, run_wood), towers.action_cost(hero), towers.is_upgrade(hero))
	weapon_system.tick(delta)
	enemies.tick(delta)
	projectiles.tick(delta)
	pickups.tick(delta)
	fx.tick(delta)
	camera_rig.follow(player.position, delta, player.move_input)
	hud.place_hero_hp(camera_rig.camera, player.position)
	hud.tick(camera_rig.camera, delta)


## Sends the current wave, then waits for it to be wiped out before calling in
## the next. There is no clock: the run advances only when the player clears
## what is in front of them.
func _tick_director(delta: float) -> void:
	if _wave_break > 0.0:
		_wave_break -= delta
		if _wave_break <= 0.0:
			_start_wave()
		return
	if not _wave_queue.is_empty():
		_spawn_timer -= delta
		while _spawn_timer <= 0.0 and not _wave_queue.is_empty():
			_spawn_timer += chapter.wave_interval(wave_index)
			if enemies.alive >= chapter.wave_cap(wave_index):
				break
			enemies.spawn(_wave_queue.pop_back(), enemies.spawn_position(),
				chapter.wave_hp_scale(wave_index))
		_report_wave()
	elif enemies.alive == 0:
		_clear_wave()


func _start_wave() -> void:
	if wave_index >= chapter.wave_count():
		_win()
		return
	_wave_queue = chapter.wave_roster(wave_index)
	_wave_queue.shuffle()
	_wave_total = _wave_queue.size()
	_spawn_timer = 0.0
	# The boss leads its wave rather than arriving somewhere in the shuffle:
	# its entrance is the point of the wave, and the escorts are the garnish.
	# Every wave burns the map's cover: what the player has been hiding in is
	# trampled and the next lot comes up elsewhere.
	for pos in forest.regrow_bushes():
		fx.death(Vector3(pos.x, 0.4, pos.y), Color(0.45, 0.75, 0.35))
	var boss_wave := false
	for i in range(_wave_queue.size() - 1, -1, -1):
		if _wave_queue[i].is_boss:
			var boss_data := _wave_queue[i]
			_wave_queue.remove_at(i)
			enemies.spawn(boss_data, enemies.spawn_position(), chapter.wave_hp_scale(wave_index))
			boss_wave = true
	hud.show_announcement(chapter.wave_name(wave_index).to_upper(), 1.8)
	if not boss_wave:
		SoundBank.sfx("bell", -6.0, 0.0)
		camera_rig.shake(0.2)
	_report_wave()
	Log.info("Game", "Wave %d/%d: %d enemies" % [wave_index + 1, chapter.wave_count(), _wave_total])


## The wave is spawned and every body is down.
func _clear_wave() -> void:
	wave_index += 1
	_report_wave()
	if wave_index >= chapter.wave_count():
		_win()
		return
	_wave_break = chapter.wave_break
	SoundBank.jingle("reward", -8.0)
	hud.show_announcement("WAVE CLEARED!", 1.4)


func _report_wave() -> void:
	# How much of this wave is done: everything not yet sent, plus everything
	# still standing, is what is left.
	var left := _wave_queue.size() + enemies.alive
	var done := 1.0 if _wave_total == 0 else 1.0 - float(left) / float(_wave_total)
	hud.set_wave(wave_index, chapter.wave_count(), left, clampf(done, 0.0, 1.0))


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


## A boss flattens the trees it walks over. Anything that big standing inside
## a trunk reads as the level being broken, and knocking them down is also the
## clearest signal on screen that it does not care about the terrain.
func _crush_forest() -> void:
	var b := enemies.boss
	if b == null or b.dying:
		return
	if forest.crush(b.pos, b.radius() * 0.8) > 0:
		SoundBank.sfx("wood_impact", -4.0, 0.1)
		camera_rig.shake(0.12)


## Standing in a bush breaks the horde's line of sight — until you kill from
## inside it, which gives your position away for a few seconds.
func _tick_cover(delta: float) -> void:
	_exposed = maxf(0.0, _exposed - delta)
	var hidden := _exposed <= 0.0 and not player.is_dead \
		and forest.hides(Vector2(player.position.x, player.position.z))
	if hidden != enemies.player_hidden:
		enemies.player_hidden = hidden
		hud.set_hidden(hidden)


## One tap, no placement mode: the nest goes up where the hero is standing —
## or levels up the one they are standing next to.
func _build_tower() -> void:
	var hero := Vector2(player.position.x, player.position.z)
	var cost := towers.action_cost(hero)
	if not towers.can_act(hero, run_wood):
		SoundBank.ui("back")
		if run_wood < cost:
			hud.show_announcement("NEED %d WOOD" % cost, 1.2)
		elif towers.towers.size() >= towers.data.max_towers:
			hud.show_announcement("%d NESTS IS THE LIMIT" % towers.data.max_towers, 1.4)
		else:
			hud.show_announcement("TOO CLOSE TO A NEST", 1.4)
		return
	run_wood -= cost
	hud.set_wood(run_wood)
	towers.build_or_upgrade(hero)


func _on_tower_built(position: Vector2, level: int) -> void:
	SoundBank.sfx("wood_impact", -4.0, 0.0)
	SoundBank.ui("confirm")
	fx.level_up(Vector3(position.x, 0.2, position.y))
	camera_rig.shake(0.2)
	if level > 1:
		hud.show_announcement("NEST LV %d" % level, 1.2)


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


func _on_vehicle_mounted(position: Vector3) -> void:
	SoundBank.sfx("metal_impact", -2.0, 0.0)
	SoundBank.ui("confirm")
	fx.level_up(position)
	camera_rig.shake(0.35)
	hud.show_announcement("MECH ONLINE!", 1.4)


func _on_vehicle_dismounted(position: Vector3, wrecked: bool) -> void:
	hud.set_vehicle(0, 0.0, 0.0)
	camera_rig.shake(0.5 if wrecked else 0.2)
	if wrecked:
		SoundBank.sfx("explosion", -2.0, 0.0)
		fx.boss_death(position + Vector3(0.0, 0.6, 0.0), Color(1.0, 0.6, 0.2))
		hud.show_announcement("MECH DOWN!", 1.6)
	else:
		SoundBank.sfx("reload", -6.0, 0.0)
		hud.show_announcement("OUT OF SHELLS", 1.4)


func _on_vehicle_fired(from: Vector3, dir: Vector2) -> void:
	fx.muzzle(from, dir, vehicles.data.weapon.tint)
	camera_rig.shake(0.06)


func _on_rescue_progress(ratio: float, position: Vector3) -> void:
	hud.set_rescue(ratio, position, camera_rig.camera)


## A freed survivor hands over what they were carrying, usable straight away.
func _on_survivor_rescued(position: Vector3, relic: RelicData) -> void:
	SoundBank.jingle("reward", -3.0)
	fx.level_up(position)
	hud.show_announcement("RESCUED! %s" % relic.display_name.to_upper(), 1.8)
	bag.append(relic)
	bag_spent.append(false)
	hud.set_bag_items(bag, bag_spent)


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
		DamageNumbers.Style.KILL if killed else DamageNumbers.Style.HIT,
		Color(0, 0, 0, 0) if killed else Damage.color(weapon.damage_type))
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
	SoundBank.sfx("bell", -2.0, 0.0)
	SoundBank.sfx("boss_roar", 0.0, 0.1)
	AudioManager.play_music(chapter.boss_music, 0.8)
	camera_rig.shake(0.5)
	Haptics.heavy()
	# It walks in on its own: the horde, the hero and every bullet stop, and
	# the camera goes to look at it.
	state = State.BOSS_INTRO
	_intro_time = 0.0
	_last_laugh = 0
	hud.joystick.reset()
	player.move_input = Vector2.ZERO
	hud.show_announcement(e.data().display_name.to_upper(), BOSS_INTRO_TIME - 0.6)


## The entrance. Only the boss moves: it turns on the hero, stalks a step
## closer and rocks with a laugh, punctuated by roars.
func _tick_boss_intro(delta: float) -> void:
	_intro_time += delta
	var e := enemies.boss
	if e != null and not e.dying:
		var to_hero := Vector2(player.position.x, player.position.z) - e.pos
		if to_hero.length() > 0.001:
			e.yaw = atan2(to_hero.x, to_hero.y)
			e.pos += to_hero.normalized() * e.data().speed * 0.55 * delta
		# `charge` is the wind-up pose: swelling it on a fast sine reads as a
		# belly laugh without needing a second animation.
		e.charge = 0.35 + 0.35 * sin(_intro_time * 9.0)
		enemies.refresh(e)
		if _laugh_due():
			SoundBank.sfx("boss_roar", -4.0, 0.0)
			camera_rig.shake(0.25)
	fx.tick(delta)
	hud.tick(camera_rig.camera, delta)
	var look := e.position3d() if e != null else player.position
	camera_rig.follow(look, delta)
	if _intro_time >= BOSS_INTRO_TIME:
		if e != null:
			e.charge = 0.0
			enemies.refresh(e)
		camera_rig.snap_to(player.position)
		hud.show_announcement("RUN!", 1.2)
		state = State.RUNNING


## True once per LAUGH_BEAT seconds of the entrance, and never on the first
## beat — the spawn roar already covers that one.
func _laugh_due() -> bool:
	var beat := floori(_intro_time / LAUGH_BEAT)
	if beat == _last_laugh or beat == 0:
		return false
	_last_laugh = beat
	return true


func _on_boss_killed(e: EnemyManager.Enemy) -> void:
	hud.set_boss(0.0, 1.0)
	SoundBank.jingle("reward", -2.0)
	AudioManager.play_music(chapter.music, 2.5)
	# The boss leaves something behind for the *next* run — it goes to the
	# inventory, not the bag, so the player chooses whether to risk it.
	var drop := e.data().boss_drop
	if drop != null:
		GameState.add_relic(drop.id)
		hud.show_announcement("%s!" % drop.display_name.to_upper(), 2.4)
	else:
		hud.show_announcement("BOSS DOWN!", 2.0)
	# The boss is the end of the chapter: whatever else is still standing, the
	# run is won. The delay lets the kill land before the badge covers it.
	if chapter.is_boss_wave(wave_index):
		wave_index = chapter.wave_count()
		_win_delay = BOSS_WIN_DELAY


func _on_player_damaged(amount: float) -> void:
	if vehicles.absorb(amount):
		SoundBank.sfx("metal_impact", -8.0, 0.1)
		camera_rig.shake(0.15)
		return
	SoundBank.sfx("hit_player", -6.0, 0.1)
	SoundBank.sfx("zombie_attack", -9.0, 0.2)
	camera_rig.shake(0.25)
	fx.hero_hurt(player.position)
	hud.flash_damage()
	hud.damage_numbers.spawn(player.position + Vector3(0, 1.3, 0), amount, DamageNumbers.Style.HERO)
	Haptics.medium()


## Freezes the action for `duration` real seconds (boss kill punch). A later
## call just extends the deadline.
func _hit_stop(scale: float, duration: float) -> void:
	Engine.time_scale = scale
	_hit_stop_until = Time.get_ticks_msec() + int(duration * 1000.0)


## Ends a hit-stop by the wall clock.
##
## A SceneTreeTimer is the obvious tool for this and the wrong one: it counts
## *scaled* time, so the timer meant to lift a 0.16 s freeze at time_scale 0.05
## does not fire for seconds. Every boss kill left the whole game crawling.
func _tick_hit_stop() -> void:
	if _hit_stop_until > 0 and Time.get_ticks_msec() >= _hit_stop_until:
		_end_hit_stop()


## Time scale must be 1 outside a live frame.
##
## This node is pausable, so the moment the tree freezes for a level-up, a
## pause or a death, `_tick_hit_stop()` stops running — and `Engine.time_scale`
## is global, so every ALWAYS-mode panel keeps rendering at whatever the freeze
## left behind. That is how dying mid-hit-stop and then reviving left the whole
## game permanently in slow motion. Freezing the world *is* the dramatic beat;
## slow motion on top of a stopped tree means nothing, so it ends here.
func _end_hit_stop() -> void:
	_hit_stop_until = 0
	Engine.time_scale = 1.0


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


# --- Relics ------------------------------------------------------------------

func _use_relic(index: int) -> void:
	if state != State.RUNNING or index < 0 or index >= bag.size() or bag_spent[index]:
		return
	bag_spent[index] = true
	hud.set_bag_items(bag, bag_spent)
	var relic := bag[index]
	SoundBank.jingle("reward", -6.0)
	hud.show_announcement(relic.display_name.to_upper(), 1.3)
	fx.level_up(player.position)
	match relic.kind:
		RelicData.Kind.HEAL:
			player.heal(stats.max_hp() * relic.value)
		RelicData.Kind.NUKE:
			camera_rig.shake(0.7)
			_hit_stop(0.1, 0.14)
			for e in enemies.enemies.duplicate():
				if not e.dying and e.pos.distance_to(Vector2(player.position.x, player.position.z)) < relic.value:
					enemies.hit(e, 1e9, e.pos, 0.0, Damage.Type.TRUE)
		RelicData.Kind.RAGE:
			stats.add("damage_mult", relic.value)
			_timed(relic.duration, func() -> void: stats.add("damage_mult", -relic.value))
		RelicData.Kind.MAGNET:
			pickups.attract_all(PickupManager.Kind.XP)
			pickups.attract_all(PickupManager.Kind.COIN)
			pickups.attract_all(PickupManager.Kind.WOOD)
			pickups.attract_all(PickupManager.Kind.AMMO)
		RelicData.Kind.SUPPLY:
			run_wood += int(relic.value)
			run_ammo += int(relic.value * 4.0)
			hud.set_wood(run_wood)
			hud.set_ammo(run_ammo)
		RelicData.Kind.WARD:
			player.invulnerable = true
			_timed(relic.duration, func() -> void: player.invulnerable = false)


## Runs `action` after `seconds` of game time. Relic effects that wear off use
## this rather than each keeping their own countdown in `_process`.
##
## A SceneTreeTimer outlives the scene, so a relic bought at 19:59 can fire its
## expiry after the player has already quit to the menu — by which point the
## nodes it touches are freed. The guard makes that a no-op instead of a
## call into a dead object.
func _timed(seconds: float, action: Callable) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		if is_inside_tree():
			action.call())


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
		if lv == 0 and held >= WEAPON_SLOTS:
			continue
		candidates.append({"weapon": w, "level": lv + 1})
		weights.append(1.4 if lv > 0 else 1.0)
	for u in upgrades:
		var lv := int(upgrade_levels.get(u, 0))
		if lv >= u.max_level:
			continue
		candidates.append({"upgrade": u, "level": lv + 1})
		weights.append(1.0)
	# With every slot full and something already maxed, offer to trade the
	# maxed weapon for one the player does not have — at the level it reached,
	# never back to 1. A finished build should be able to change shape.
	if held >= WEAPON_SLOTS:
		for old in weapon_system.maxed():
			for w in weapons:
				if weapon_system.level_of(w) > 0:
					continue
				candidates.append({"weapon": w, "swap_from": old, "level": weapon_system.level_of(old)})
				weights.append(0.5)
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
	if option.has("swap_from"):
		weapon_system.swap(option["swap_from"], option["weapon"])
	elif option.has("weapon"):
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
	pause_panel.build_panel.show_build(weapon_system.slots, upgrade_levels, stats)
	pause_panel.open()


## Pauses the tree and drops the joystick touch: the HUD stops receiving
## input while paused, so the finger's release would otherwise never arrive
## and the hero would keep walking after the panel closes.
func _freeze() -> void:
	_end_hit_stop()
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
	AudioManager.stop_music(0.6)
	_end(false)
	state = State.OVER
	_show_result()


## Death stops the world outright: the horde freezes mid-lunge, the particles
## hang where they are, and the screen answers. Nothing on this side ticks
## again until the player revives or gives up.
func _on_player_died() -> void:
	if state == State.DYING or state == State.OVER:
		return
	state = State.DYING
	AudioManager.stop_music(1.2)
	SoundBank.jingle("lose", -2.0)
	Haptics.heavy()
	_freeze()
	outcome.show_death()


## The overlay has finished its beat. Death offers the revive; a win goes
## straight to the result card.
func _on_outcome_finished() -> void:
	if state == State.DYING:
		if not revive_panel.open(_revives, GameState.get_coins()):
			_after_death()
		return
	_show_result()


func _do_revive() -> void:
	var price := RevivePanel.cost_for(_revives)
	if not GameState.spend_coins(price):
		_after_death()
		return
	_revives += 1
	outcome.hide_overlay()
	_end_hit_stop()
	get_tree().paused = false
	AudioManager.duck_music(false)
	player.revive(REVIVE_GRACE)
	# Clear the pile that killed you, or the revive is worth nothing — but a
	# boss is the fight, not the pile. Killing it here would hand the player
	# the chapter for the price of one revive, so it is shoved back instead.
	var hero := Vector2(player.position.x, player.position.z)
	for e in enemies.enemies.duplicate():
		if e.dying or e.pos.distance_to(hero) >= REVIVE_CLEAR:
			continue
		if e.data().is_boss:
			e.pos = hero + (e.pos - hero).normalized() * REVIVE_CLEAR
			enemies.refresh(e)
		else:
			enemies.hit(e, 1e9, e.pos, 0.0, Damage.Type.TRUE)
	fx.level_up(player.position)
	camera_rig.shake(0.5)
	SoundBank.jingle("reward", -4.0)
	hud.show_announcement("BACK UP!", 1.4)
	AudioManager.play_music(chapter.boss_music if enemies.boss != null else chapter.music, 1.0)
	state = State.RUNNING


func _after_death() -> void:
	_end(false)
	state = State.OVER
	_show_result()


## A win freezes the world too, so the last frame of the fight stays on screen
## under the badge instead of the horde carrying on behind a menu.
func _win() -> void:
	if state == State.OVER:
		return
	AudioManager.stop_music(0.6)
	SoundBank.jingle("win", -2.0)
	Haptics.medium()
	_end(true)
	_freeze()
	outcome.show_victory()


func _end(won: bool) -> void:
	if state == State.OVER:
		return
	state = State.OVER
	_won = won
	hud.joystick.reset()
	player.move_input = Vector2.ZERO
	# Paid per wave cleared, so a run that got most of the way through is worth
	# something even when it ends badly.
	var reward := run_coins + chapter.coins_per_wave * wave_index
	if won:
		reward += chapter.coins_win
	run_coins = reward
	if won and chapter.unlocks != "":
		GameState.unlock_chapter(chapter.unlocks)
	# Unused relics only survive a win: dying costs you what you were carrying.
	if won:
		var leftovers: Array = []
		for i in bag.size():
			if not bag_spent[i]:
				leftovers.append(bag[i].id)
		GameState.return_unused(leftovers)
	# record_run banks the coins as well.
	_new_best = GameState.record_run(chapter.id, run_time, enemies.kills, won, reward)
	Log.info("Game", "Run over: won=%s wave=%d/%d time=%.1f kills=%d level=%d coins=%d" % [
		won, wave_index, chapter.wave_count(), run_time, enemies.kills, level, reward])


func _show_result() -> void:
	if result_panel.visible:
		return
	result_panel.show_result(_won, chapter.display_name, run_time, enemies.kills, level, run_coins, _new_best)


func _exit_tree() -> void:
	_end_hit_stop()
	AudioManager.duck_music(false)


func _retry() -> void:
	SoundBank.ui("click")
	SceneRouter.go_to(SceneRouter.GAME, {"chapter_id": _chapter_id, "character": character})


func _to_menu() -> void:
	SoundBank.ui("back")
	SceneRouter.go_to(SceneRouter.MAIN_MENU)
