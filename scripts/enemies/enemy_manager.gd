## Runs the whole horde without nodes or physics bodies: one MultiMesh per
## enemy type (mesh baked by EnemyMeshBaker, animated by enemy_parts.gdshader),
## plain records for state, and a spatial hash for neighbour/hit queries.
class_name EnemyManager
extends Node3D

signal enemy_killed(enemy: Enemy)
signal boss_spawned(enemy: Enemy)
signal boss_killed(enemy: Enemy)
## An enemy started its wind-up: the tell, before any damage exists.
signal enemy_winding_up(enemy: Enemy)
## The strike landed (melee) or the bolt left the caster (ranged).
signal enemy_struck(enemy: Enemy, target: Vector2)
## A boss started an ability; `kind` is its "kind" string.
signal boss_ability(enemy: Enemy, kind: String, data: Dictionary)
## A boss landed a leap: everything in `radius` of `at` is hit.
signal boss_slammed(at: Vector2, radius: float, damage: float)


## Something noisy that pulls the horde off the hero — a firing tower. Only
## registered while it is actually making noise, which is the whole point: a
## silent nest is invisible to the horde.
class Lure:
	var pos: Vector2
	## How far the noise carries.
	var radius: float
	## The thing's actual footprint: enemies stop at its edge and ring it
	## instead of piling onto a single point.
	var body_radius := 1.0
	## Takes the damage of one strike.
	var damage_sink: Callable

const CELL := 1.5
const DEATH_DURATION := 1.6
## Enemies this far from the hero are moved back to the spawn ring so the
## pressure never thins out behind the player.
const RESPAWN_DISTANCE := 20.0
const SPAWN_RING_MIN := 10.5
const SPAWN_RING_MAX := 12.5
## Separation is capped at this many body radii per frame.
const MAX_SEPARATION := 1.5
## Strike lunge decay: how long the forward snap is visible.
const STRIKE_TIME := 0.18
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


class Enemy:
	var pool: Pool
	var slot: int
	var pos: Vector2
	var hp: float
	var max_hp: float
	var phase: float
	var yaw: float
	var dying := false
	var death_time := 0.0
	var attack_cd := 0.0
	## Seconds left in the wind-up; 0 = not winding up.
	var windup := 0.0
	## Strike animation: 1 at the moment of impact, decaying to 0. Drives the
	## forward lunge in `_write_transform`.
	var strike := 0.0
	## Wind-up pose: the body rears back and swells as it charges the hit.
	var charge := 0.0
	## Height above the ground, for a boss mid-leap.
	var height := 0.0
	## Temporary speed multiplier from a boss roar, and how long it lasts.
	var haste := 1.0
	var haste_left := 0.0
	var knock := Vector2.ZERO
	var sep := Vector2.ZERO
	var hit_time := -100.0
	## Set each frame when a lure is closer than the hero.
	var lure: Lure
	## weapon instance id -> next time it may hit this enemy (orbit/aura ticks)
	var hit_cooldowns := {}

	func data() -> EnemyData:
		return pool.data

	func radius() -> float:
		return pool.data.radius * pool.data.scale

	func position3d() -> Vector3:
		return Vector3(pos.x, 0.0, pos.y)


class Pool:
	var data: EnemyData
	var multimesh: MultiMesh
	var free: Array[int] = []
	var height := 1.0


var player: Player
var bounds := ArenaBounds.new()
## While the hero is concealed the horde walks to where it last saw them and
## mills around there instead of tracking.
var player_hidden := false
var last_seen := Vector2.ZERO
var lures: Array[Lure] = []
## Solid terrain the horde walks around; set from the chapter's hills.
var obstacles: Array[Obstacle] = []
## Set by Game; while it reports busy the boss is under the brain's control.
var boss_brain: BossBrain
## What the most recent `hit()` actually landed, after resistances.
var last_dealt := 0.0
var time := 0.0
var enemies: Array[Enemy] = []
var alive := 0
var kills := 0
var boss: Enemy

var _pools: Dictionary = {}  # EnemyData -> Pool
var _grid: Dictionary = {}   # cell key -> Array[Enemy]
var _rng := RandomNumberGenerator.new()
var _frame := 0


func configure(chapter: ChapterData, capacity: int) -> void:
	bounds = ArenaBounds.from_chapter(chapter)
	for data in chapter.all_enemies():
		_make_pool(data, 4 if data.is_boss else capacity)


func _make_pool(data: EnemyData, capacity: int) -> void:
	var baked := EnemyMeshBaker.bake(data.model)
	var pool := Pool.new()
	pool.data = data
	pool.height = (baked[2] as AABB).end.y * data.scale
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = baked[0]
	mm.instance_count = capacity
	for i in capacity:
		mm.set_instance_transform(i, HIDDEN)
		pool.free.append(capacity - 1 - i)
	pool.multimesh = mm
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Horde_" + data.id
	mmi.multimesh = mm
	mmi.material_override = EnemyMeshBaker.make_material(data, baked[1])
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var extent := bounds.half + 5.0
	mmi.custom_aabb = AABB(Vector3(-extent, -2, -extent), Vector3(extent * 2.0, 6, extent * 2.0))
	add_child(mmi)
	_pools[data] = pool


# --- Spawning ----------------------------------------------------------------

func spawn(data: EnemyData, pos: Vector2, hp_scale: float = 1.0) -> Enemy:
	var pool: Pool = _pools.get(data)
	if pool == null:
		_make_pool(data, 64)
		pool = _pools[data]
	if pool.free.is_empty():
		return null
	var e := Enemy.new()
	e.pool = pool
	e.slot = pool.free.pop_back()
	e.pos = pos
	e.max_hp = data.max_hp * hp_scale
	e.hp = e.max_hp
	e.phase = _rng.randf()
	e.yaw = _rng.randf() * TAU
	enemies.append(e)
	alive += 1
	pool.multimesh.set_instance_custom_data(e.slot, Color(e.phase, 1.0, -100.0, -1.0))
	_write_transform(e)
	if data.is_boss:
		boss = e
		boss_spawned.emit(e)
	return e


## Position on a ring around the hero that is outside the portrait view and
## inside the arena.
func spawn_position(angle: float = -1.0) -> Vector2:
	var center := Vector2(player.position.x, player.position.z)
	var best := center
	var best_dist := -1.0
	for attempt in 6:
		var a := angle if angle >= 0.0 and attempt == 0 else _rng.randf() * TAU
		var r := _rng.randf_range(SPAWN_RING_MIN, SPAWN_RING_MAX)
		var p := bounds.clamp_point(center + Vector2(cos(a), sin(a)) * r, 0.5)
		var d := p.distance_to(center)
		if d >= SPAWN_RING_MIN:
			return p
		if d > best_dist:
			best_dist = d
			best = p
	return best


func spawn_ring(data: EnemyData, count: int, radius: float, hp_scale: float = 1.0) -> void:
	var center := Vector2(player.position.x, player.position.z)
	for i in count:
		var a := TAU * float(i) / float(count)
		spawn(data, bounds.clamp_point(center + Vector2(cos(a), sin(a)) * radius, 0.5), hp_scale)


func clear_all() -> void:
	lures.clear()
	for e in enemies:
		_release(e)
	enemies.clear()
	alive = 0
	boss = null


# --- Simulation --------------------------------------------------------------

func tick(delta: float) -> void:
	time += delta
	_frame += 1
	RenderingServer.global_shader_parameter_set("game_time", time)
	if player == null:
		return
	_rebuild_grid()
	var player_pos := Vector2(player.position.x, player.position.z)
	if not player_hidden:
		last_seen = player_pos
	var target := player_pos if not player_hidden else last_seen
	var player_alive := not player.is_dead and not player_hidden
	var i := 0
	while i < enemies.size():
		var e := enemies[i]
		if e.dying:
			if time - e.death_time >= DEATH_DURATION:
				_release(e)
				enemies[i] = enemies[enemies.size() - 1]
				enemies.pop_back()
				continue
			i += 1
			continue
		if e == boss and boss_brain != null and boss_brain.is_busy():
			i += 1
			continue
		_move(e, delta, target, player_alive)
		i += 1


func _rebuild_grid() -> void:
	_grid.clear()
	for e in enemies:
		if e.dying:
			continue
		var key := _cell_key(e.pos)
		var bucket: Variant = _grid.get(key)
		if bucket == null:
			_grid[key] = [e]
		else:
			bucket.append(e)


## `target` is the hero, or the last place the horde saw them while concealed.
func _move(e: Enemy, delta: float, target: Vector2, player_alive: bool) -> void:
	var d := e.pool.data
	e.lure = _pick_lure(e.pos)
	if e.lure != null:
		target = e.lure.pos
	var to_player := target - e.pos
	var dist := to_player.length()
	var dir := to_player / dist if dist > 0.001 else Vector2.RIGHT
	var vel := dir * d.speed * e.haste
	var target_radius := e.lure.body_radius if e.lure != null else Player.RADIUS
	var reach := e.radius() + target_radius + d.attack_reach

	if dist > RESPAWN_DISTANCE:
		e.pos = spawn_position()
		e.knock = Vector2.ZERO
		e.windup = 0.0
		_write_transform(e)
		return

	e.strike = maxf(0.0, e.strike - delta / STRIKE_TIME)
	e.attack_cd = maxf(0.0, e.attack_cd - delta)
	if e.haste_left > 0.0:
		e.haste_left -= delta
		if e.haste_left <= 0.0:
			e.haste = 1.0

	if e.windup > 0.0:
		# Rooted while charging: the wind-up is the player's cue to leave.
		e.windup -= delta
		e.charge = 1.0 - clampf(e.windup / maxf(0.001, d.attack_windup), 0.0, 1.0)
		vel = Vector2.ZERO
		if e.windup <= 0.0:
			_land_attack(e, dir, dist, reach, target, player_alive)
	else:
		e.charge = maxf(0.0, e.charge - delta * 5.0)
		# Separation is refreshed on alternate frames; the cached push is reused.
		# A boss walks through the horde rather than being jostled by it.
		if e != boss:
			if (_frame + e.slot) & 1 == 0:
				e.sep = _separation(e)
			vel += e.sep * 7.0
		var trigger := d.cast_range if d.ranged else reach
		if (player_alive or e.lure != null) and dist < trigger and e.attack_cd <= 0.0:
			e.windup = d.attack_windup
			# The cooldown covers the wind-up so the rhythm stays readable.
			e.attack_cd = d.attack_cooldown + d.attack_windup
			vel = Vector2.ZERO
			enemy_winding_up.emit(e)
		elif dist < reach:
			vel -= dir * d.speed  # touching already; stop shoving

	e.pos += (vel + e.knock) * delta
	e.knock = e.knock.lerp(Vector2.ZERO, minf(1.0, 9.0 * delta))
	e.pos = bounds.clamp_point(e.pos)
	e.yaw = lerp_angle(e.yaw, atan2(dir.x, dir.y), minf(1.0, 8.0 * delta))
	_write_transform(e)


## End of the wind-up. Melee only connects if the hero is still in reach —
## walking out of a telegraphed swing has to work, or the tell is decoration.
func _land_attack(e: Enemy, dir: Vector2, dist: float, reach: float, target: Vector2, player_alive: bool) -> void:
	var d := e.pool.data
	e.windup = 0.0
	e.charge = 0.0
	e.strike = 1.0
	if d.ranged:
		enemy_struck.emit(e, target)
		return
	if dist > reach + d.lunge:
		return
	if e.lure != null:
		e.lure.damage_sink.call(d.damage)
		enemy_struck.emit(e, e.pos + dir * reach)
	elif player_alive:
		player.take_damage(d.damage)
		enemy_struck.emit(e, e.pos + dir * reach)


## Closest lure whose noise reaches this enemy. There are only ever a handful,
## so a linear scan beats keeping them in the grid.
func _pick_lure(p: Vector2) -> Lure:
	var best: Lure = null
	var best_d := INF
	for l in lures:
		var d := p.distance_squared_to(l.pos)
		if d <= l.radius * l.radius and d < best_d:
			best_d = d
			best = l
	return best


## Neighbour push, from the spatial hash plus the things the hash cannot see.
##
## The grid only looks at a 2x2 block of cells, which assumes every body is
## small next to `CELL`. Two things are not: static rock, and a boss at radius
## 3+ that spans a dozen cells. Both are checked explicitly here — the boss
## shoves without being shoved (`_move` skips this entirely for it), and rocks
## push like a very large, very still enemy.
func _separation(e: Enemy) -> Vector2:
	var push := Vector2.ZERO
	var checked := 0
	var r := e.radius()
	for o in obstacles:
		push += _push_from(e, o.pos, r + o.radius)
	if boss != null and not boss.dying and e != boss:
		push += _push_from(e, boss.pos, r + boss.radius())
	var cx := floori(e.pos.x / CELL)
	var cz := floori(e.pos.y / CELL)
	# The 2x2 block of cells on this enemy's side of its cell covers every
	# neighbour within CELL / 2.
	var sx := 1 if e.pos.x - float(cx) * CELL > CELL * 0.5 else -1
	var sz := 1 if e.pos.y - float(cz) * CELL > CELL * 0.5 else -1
	for ox in [0, sx]:
		for oz in [0, sz]:
			var bucket: Variant = _grid.get((cx + ox) * 65536 + (cz + oz))
			if bucket == null:
				continue
			for o: Enemy in bucket:
				if o == e:
					continue
				var diff := e.pos - o.pos
				var min_d := r + o.radius()
				var d2 := diff.length_squared()
				if d2 < min_d * min_d:
					if d2 < 0.0001:
						diff = Vector2(e.phase - 0.5, o.phase - 0.5)
						d2 = diff.length_squared()
					var dl := sqrt(d2)
					push += diff / dl * (min_d - dl)
					checked += 1
					if checked >= 8:
						break
	# One body-length of correction per frame is plenty. Without the clamp a
	# body wedged between a rock and the boss is flung across the arena.
	return push.limit_length(r * MAX_SEPARATION)


## Outward push that would clear `e` from a circle at `at` of combined size
## `clear`, or zero when it is already outside.
func _push_from(e: Enemy, at: Vector2, clear: float) -> Vector2:
	var away := e.pos - at
	var d2 := away.length_squared()
	if d2 >= clear * clear:
		return Vector2.ZERO
	if d2 < 0.0001:
		return Vector2(cos(e.phase * TAU), sin(e.phase * TAU)) * clear
	return away / sqrt(d2) * (clear - sqrt(d2))


## Pushes a record's current pose to the GPU. Used by the boss entrance, which
## animates one enemy while the rest of the horde is frozen.
func refresh(e: Enemy) -> void:
	_write_transform(e)


func _write_transform(e: Enemy) -> void:
	var d := e.pool.data
	var s := d.scale
	var offset := Vector2.ZERO
	if e.charge > 0.0 or e.strike > 0.0:
		# Rear back over the wind-up, then snap forward on the strike.
		var forward := Vector2(sin(e.yaw), cos(e.yaw))
		offset = forward * d.lunge * (e.strike - e.charge * 0.4)
		s *= 1.0 + e.charge * 0.12 + e.strike * 0.08
	var basis := Basis(Vector3.UP, e.yaw).scaled(Vector3(s, s, s))
	e.pool.multimesh.set_instance_transform(e.slot, Transform3D(basis,
		Vector3(e.pos.x + offset.x, e.height, e.pos.y + offset.y)))


func _write_custom(e: Enemy) -> void:
	e.pool.multimesh.set_instance_custom_data(e.slot, Color(e.phase, 0.0 if e.dying else 1.0, e.hit_time, e.death_time if e.dying else -1.0))


func _release(e: Enemy) -> void:
	e.pool.multimesh.set_instance_transform(e.slot, HIDDEN)
	e.pool.free.append(e.slot)
	if e == boss:
		boss = null


# --- Queries -----------------------------------------------------------------

func _cell_key(p: Vector2) -> int:
	return floori(p.x / CELL) * 65536 + floori(p.y / CELL)


## Alive enemies whose body overlaps a circle. Appends to `out`.
func query_circle(center: Vector2, radius: float, out: Array) -> void:
	var x0 := floori((center.x - radius - 1.0) / CELL)
	var x1 := floori((center.x + radius + 1.0) / CELL)
	var z0 := floori((center.y - radius - 1.0) / CELL)
	var z1 := floori((center.y + radius + 1.0) / CELL)
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var bucket: Variant = _grid.get(cx * 65536 + cz)
			if bucket == null:
				continue
			for e: Enemy in bucket:
				if e.dying:
					continue
				var rr := radius + e.radius()
				if e.pos.distance_squared_to(center) <= rr * rr:
					out.append(e)


## Closest alive enemy within `max_dist`, or null.
func nearest(center: Vector2, max_dist: float) -> Enemy:
	var best: Enemy = null
	var best_d2 := max_dist * max_dist
	# Cheap path: scan the whole list; a few hundred distance checks per shot
	# is nothing compared to the grid walk for a large radius.
	for e in enemies:
		if e.dying:
			continue
		var d2 := e.pos.distance_squared_to(center)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


# --- Damage ------------------------------------------------------------------

## Applies damage after the target's resistances. Returns true when the hit
## killed the enemy; `dealt` reports what actually landed so the damage number
## matches the health bar.
func hit(e: Enemy, amount: float, from: Vector2, knockback: float, type: Damage.Type = Damage.Type.PHYSICAL) -> bool:
	if e.dying:
		return false
	var dealt := Damage.resolve(amount, type, e.pool.data)
	last_dealt = dealt
	e.hp -= dealt
	e.hit_time = time
	if knockback > 0.0 and e != boss:
		var dir := (e.pos - from)
		if dir.length_squared() > 0.0001:
			e.knock += dir.normalized() * knockback * (1.0 - e.pool.data.knockback_resist)
	if e.hp <= 0.0:
		_kill(e)
		return true
	_write_custom(e)
	return false


func _kill(e: Enemy) -> void:
	e.dying = true
	e.death_time = time
	alive -= 1
	kills += 1
	_write_custom(e)
	if e == boss:
		boss_killed.emit(e)
	enemy_killed.emit(e)
