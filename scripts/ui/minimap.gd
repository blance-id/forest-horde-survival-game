## Top-down radar of the whole map. The arena is far bigger than the camera
## sees, so without this the player has no idea where the horde is massing,
## where the trees still stand, or how far the edge is.
##
## One `_draw()` over plain records: no nodes, no viewport, no second camera.
class_name Minimap
extends Control

## Enemy dots are sampled — a wall of 240 pixels tells you nothing more than
## a hundred does, and costs twice as much.
const MAX_ENEMY_DOTS := 90
const EDGE := Color(0.95, 0.82, 0.5, 0.85)
const GROUND := Color(0.09, 0.14, 0.08, 0.62)
const TREE := Color(0.25, 0.55, 0.22, 0.9)
const BUSH := Color(0.4, 0.75, 0.3, 0.85)
const TRAP := Color(0.95, 0.5, 0.15, 0.9)
const HILL := Color(0.42, 0.38, 0.34, 0.95)
const ENEMY := Color(0.92, 0.26, 0.22)
const ELITE := Color(1.0, 0.6, 0.15)
const BOSS := Color(1.0, 0.2, 0.5)
const HERO := Color(1.0, 1.0, 1.0)

var enemies: EnemyManager
var forest: Forest
var traps: Traps
var hills: Hills

var _bounds := ArenaBounds.new()
var _hero := Vector2.ZERO
var _outline: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func setup(chapter: ChapterData) -> void:
	_bounds = ArenaBounds.from_chapter(chapter)
	# The map edge is static, so trace it once instead of every frame.
	_outline = PackedVector2Array()
	for i in 65:
		var a := TAU * float(i) / 64.0
		_outline.append(Vector2(cos(a), sin(a)) * _bounds.radius_at(a))
	queue_redraw()


func tick(hero_position: Vector3) -> void:
	_hero = Vector2(hero_position.x, hero_position.z)
	queue_redraw()


## World XZ to map pixels. The map always shows the whole arena, so the hero
## dot moving towards an edge means the same thing every run.
func _to_map(p: Vector2) -> Vector2:
	return size * 0.5 + p * (size.x * 0.5 / maxf(1.0, _bounds.half))


func _draw() -> void:
	if _outline.is_empty():
		return
	var shape := PackedVector2Array()
	for p in _outline:
		shape.append(_to_map(p))
	draw_colored_polygon(shape, GROUND)
	draw_polyline(shape, EDGE, 2.0)
	if hills != null:
		for h in hills.hills:
			draw_circle(_to_map(h.pos), maxf(3.0, h.radius * size.x * 0.5 / _bounds.half), HILL)
	if forest != null:
		for b in forest.bushes:
			draw_circle(_to_map(b.pos), maxf(2.0, b.radius * size.x * 0.5 / _bounds.half), BUSH)
		for t in forest.trees:
			if t.standing:
				draw_rect(Rect2(_to_map(t.pos) - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), TREE)
	if traps != null:
		for t in traps.traps:
			draw_circle(_to_map(t.pos), 2.0, TRAP)
	if enemies != null:
		var step := maxi(1, enemies.enemies.size() / MAX_ENEMY_DOTS)
		var i := 0
		while i < enemies.enemies.size():
			var e := enemies.enemies[i]
			i += step
			if e.dying:
				continue
			var d := e.data()
			if d.is_boss:
				draw_circle(_to_map(e.pos), 5.0, BOSS)
			else:
				draw_circle(_to_map(e.pos), 2.5, ELITE if d.is_elite() else ENEMY)
	var hero := _to_map(_hero)
	draw_circle(hero, 5.0, Color(0.1, 0.08, 0.06))
	draw_circle(hero, 3.5, HERO)
