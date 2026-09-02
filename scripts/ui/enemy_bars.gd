## A health bar over every enemy on screen, drawn as one canvas item rather
## than a node per enemy: the horde is 200+ records, so anything per-enemy
## would cost more than the horde itself. Bars are culled by distance and
## capped, and elites (×5 XP and up) get a gold frame so tiers read at a glance.
class_name EnemyBars
extends Control

const MAX_BARS := 110
## Enemies further than this from the hero are off screen in portrait.
const RANGE := 13.0
const WIDTH := 30.0
const HEIGHT := 5.0
const BACK := Color(0.05, 0.03, 0.02, 0.75)
const FILL := Color(0.87, 0.22, 0.2)
const FILL_ELITE := Color(1.0, 0.55, 0.12)
const FRAME_ELITE := Color(1.0, 0.85, 0.35, 0.9)

var enemies: EnemyManager

var _camera: Camera3D
var _hero := Vector2.ZERO


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func tick(camera: Camera3D, hero_position: Vector3) -> void:
	_camera = camera
	_hero = Vector2(hero_position.x, hero_position.z)
	queue_redraw()


func _draw() -> void:
	if enemies == null or _camera == null:
		return
	var drawn := 0
	for e in enemies.enemies:
		if drawn >= MAX_BARS:
			return
		# The boss has its own bar across the top of the screen.
		if e.dying or e.data().is_boss:
			continue
		if e.pos.distance_squared_to(_hero) > RANGE * RANGE:
			continue
		var head := Vector3(e.pos.x, e.pool.height + 0.25, e.pos.y)
		if _camera.is_position_behind(head):
			continue
		var centre := _camera.unproject_position(head)
		var elite := e.data().is_elite()
		var w := WIDTH * e.data().scale
		var rect := Rect2(centre.x - w * 0.5, centre.y - HEIGHT, w, HEIGHT)
		draw_rect(rect.grow(1.0), FRAME_ELITE if elite else BACK)
		draw_rect(rect, BACK)
		var ratio := clampf(e.hp / maxf(1.0, e.max_hp), 0.0, 1.0)
		if ratio > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)),
				FILL_ELITE if elite else FILL)
		drawn += 1
