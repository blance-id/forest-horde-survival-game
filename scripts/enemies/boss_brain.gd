## Runs a boss's ability list.
##
## A boss that only walks at you is a big walker. This gives each one a real
## pattern: every ability keeps its own cooldown, so a boss with a leap, a
## summon and a roar cycles through all three instead of leaning on whichever
## came off cooldown first. Nothing here knows about the game — it drives the
## boss record and reports what happened through `EnemyManager`'s signals, so
## `Game` can answer with sound, shake and spawns.
class_name BossBrain
extends RefCounted

## Nothing starts in the first moments after the entrance.
const OPENING_GRACE := 2.0
## A leap is: crouch, fly, land. Timings come from the ability entry.
enum Phase { IDLE, WIND, FLIGHT }


var enemies: EnemyManager
var player: Player

var _boss: EnemyManager.Enemy
var _cooldowns: Array[float] = []
var _phase := Phase.IDLE
var _timer := 0.0
var _ability: Dictionary = {}
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _flight := 0.0


## Called when a boss spawns; resets every timer for the new fight.
func begin(boss: EnemyManager.Enemy) -> void:
	_boss = boss
	_phase = Phase.IDLE
	_timer = 0.0
	_cooldowns.clear()
	for a in boss.data().abilities:
		# Staggered, so the boss does not open with everything at once.
		_cooldowns.append(float(a.get("cooldown", 8.0)) * 0.5 + OPENING_GRACE + float(_cooldowns.size()) * 1.5)


func is_busy() -> bool:
	return _phase != Phase.IDLE


func tick(delta: float) -> void:
	if _boss == null or _boss.dying or enemies.boss != _boss:
		_boss = null
		return
	if _phase != Phase.IDLE:
		_tick_leap(delta)
		return
	var abilities := _boss.data().abilities
	for i in mini(_cooldowns.size(), abilities.size()):
		_cooldowns[i] -= delta
		if _cooldowns[i] > 0.0:
			continue
		_cooldowns[i] = float(abilities[i].get("cooldown", 8.0))
		_start(abilities[i])
		return


func _start(ability: Dictionary) -> void:
	var kind := String(ability.get("kind", ""))
	enemies.boss_ability.emit(_boss, kind, ability)
	match kind:
		"leap":
			_begin_leap(ability)
		"roar":
			# The horde around it speeds up: the boss is not just a body, it
			# makes everything else worse while it is alive.
			var radius := float(ability.get("radius", 12.0))
			var haste := float(ability.get("haste", 1.5))
			var seconds := float(ability.get("seconds", 5.0))
			for e in enemies.enemies:
				if not e.dying and e != _boss and e.pos.distance_to(_boss.pos) <= radius:
					e.haste = haste
					e.haste_left = seconds
		_:
			# "summon" and "volley" are spawns and projectiles, which belong to
			# the run rather than the horde; `Game` answers the signal.
			pass


func _begin_leap(ability: Dictionary) -> void:
	_ability = ability
	_phase = Phase.WIND
	_timer = float(ability.get("wind", 0.6))
	_flight = float(ability.get("flight", 0.7))
	_from = _boss.pos
	var reach := float(ability.get("range", 14.0))
	var hero := Vector2(player.position.x, player.position.z)
	var away := hero - _from
	# Lands on the hero if they are in reach, short of them if not.
	_to = hero if away.length() <= reach else _from + away.normalized() * reach
	_to = enemies.bounds.clamp_point(_to, 1.0)


func _tick_leap(delta: float) -> void:
	_timer -= delta
	if _phase == Phase.WIND:
		# Crouch: `charge` squashes the body, which is the same tell the
		# ordinary wind-up uses, so players already know what it means.
		_boss.charge = 1.0 - clampf(_timer / maxf(0.01, float(_ability.get("wind", 0.6))), 0.0, 1.0)
		enemies.refresh(_boss)
		if _timer <= 0.0:
			_phase = Phase.FLIGHT
			_timer = _flight
			_boss.charge = 0.0
		return
	var t := 1.0 - clampf(_timer / maxf(0.01, _flight), 0.0, 1.0)
	_boss.pos = _from.lerp(_to, t)
	# A plain parabola: peak at halfway, back on the ground on landing.
	_boss.height = sin(t * PI) * float(_ability.get("height", 4.0))
	var facing := _to - _from
	if facing.length_squared() > 0.0001:
		_boss.yaw = atan2(facing.x, facing.y)
	enemies.refresh(_boss)
	if _timer > 0.0:
		return
	_boss.height = 0.0
	_boss.strike = 1.0
	enemies.refresh(_boss)
	_phase = Phase.IDLE
	enemies.boss_slammed.emit(_to, float(_ability.get("radius", 5.0)), float(_ability.get("damage", 30.0)))
