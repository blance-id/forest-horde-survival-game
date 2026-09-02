## Runs the whole horde without nodes or physics bodies: one MultiMesh per
## enemy type (mesh baked by EnemyMeshBaker, animated by enemy_parts.gdshader),
## plain records for state, and a spatial hash for neighbour/hit queries.
class_name EnemyManager
extends Node3D

signal enemy_killed(enemy: Enemy)
signal boss_spawned(enemy: Enemy)
signal boss_killed(enemy: Enemy)

const CELL := 1.5
const DEATH_DURATION := 1.6
## Enemies this far from the hero are moved back to the spawn ring so the
## pressure never thins out behind the player.
const RESPAWN_DISTANCE := 20.0
const SPAWN_RING_MIN := 10.5
const SPAWN_RING_MAX := 12.5
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
	var knock := Vector2.ZERO
	var sep := Vector2.ZERO
	var hit_time := -100.0
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
var arena_half := 20.0
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
	arena_half = chapter.arena_half_size
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
	mmi.custom_aabb = AABB(Vector3(-arena_half - 5, -2, -arena_half - 5), Vector3(arena_half * 2 + 10, 6, arena_half * 2 + 10))
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
		var p := center + Vector2(cos(a), sin(a)) * r
		p.x = clampf(p.x, -arena_half + 0.5, arena_half - 0.5)
		p.y = clampf(p.y, -arena_half + 0.5, arena_half - 0.5)
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
		var p := center + Vector2(cos(a), sin(a)) * radius
		p.x = clampf(p.x, -arena_half + 0.5, arena_half - 0.5)
		p.y = clampf(p.y, -arena_half + 0.5, arena_half - 0.5)
		spawn(data, p, hp_scale)


func clear_all() -> void:
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
	var player_alive := not player.is_dead
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
		_move(e, delta, player_pos, player_alive)
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


func _move(e: Enemy, delta: float, player_pos: Vector2, player_alive: bool) -> void:
	var d := e.pool.data
	var to_player := player_pos - e.pos
	var dist := to_player.length()
	var dir := to_player / dist if dist > 0.001 else Vector2.RIGHT
	var speed := d.speed
	var vel := dir * speed
	var contact := e.radius() + Player.RADIUS

	if dist > RESPAWN_DISTANCE:
		e.pos = spawn_position()
		e.knock = Vector2.ZERO
		_write_transform(e)
		return

	# Separation is refreshed on alternate frames; the cached push is reused.
	if (_frame + e.slot) & 1 == 0:
		e.sep = _separation(e)
	vel += e.sep * 5.0

	if dist < contact:
		vel -= dir * speed
		e.attack_cd -= delta
		if player_alive and e.attack_cd <= 0.0:
			if player.take_damage(d.damage):
				e.attack_cd = d.attack_cooldown
	else:
		e.attack_cd = minf(e.attack_cd, 0.15)

	e.pos += (vel + e.knock) * delta
	e.knock = e.knock.lerp(Vector2.ZERO, minf(1.0, 9.0 * delta))
	e.pos.x = clampf(e.pos.x, -arena_half, arena_half)
	e.pos.y = clampf(e.pos.y, -arena_half, arena_half)
	e.yaw = lerp_angle(e.yaw, atan2(dir.x, dir.y), minf(1.0, 8.0 * delta))
	_write_transform(e)


func _separation(e: Enemy) -> Vector2:
	var push := Vector2.ZERO
	var checked := 0
	var cx := floori(e.pos.x / CELL)
	var cz := floori(e.pos.y / CELL)
	# The 2x2 block of cells on this enemy's side of its cell covers every
	# neighbour within CELL / 2.
	var sx := 1 if e.pos.x - float(cx) * CELL > CELL * 0.5 else -1
	var sz := 1 if e.pos.y - float(cz) * CELL > CELL * 0.5 else -1
	var r := e.radius()
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
					if checked >= 6:
						return push
	return push


func _write_transform(e: Enemy) -> void:
	var s := e.pool.data.scale
	var basis := Basis(Vector3.UP, e.yaw).scaled(Vector3(s, s, s))
	e.pool.multimesh.set_instance_transform(e.slot, Transform3D(basis, Vector3(e.pos.x, 0.0, e.pos.y)))


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

## Applies damage. Returns true when the hit killed the enemy.
func hit(e: Enemy, amount: float, from: Vector2, knockback: float) -> bool:
	if e.dying:
		return false
	e.hp -= amount
	e.hit_time = time
	if knockback > 0.0:
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
