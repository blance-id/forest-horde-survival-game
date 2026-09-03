## A circle nothing walks through.
##
## Its own type rather than an inner class of either side: the hero, the horde
## and the terrain that produces them all need to name it, and none of them
## should have to depend on the others to do so.
class_name Obstacle
extends RefCounted

var pos: Vector2
var radius: float


static func make(at: Vector2, r: float) -> Obstacle:
	var o := Obstacle.new()
	o.pos = at
	o.radius = r
	return o


## Pushes a body of `radius` out of every obstacle it overlaps.
static func push_out_of(list: Array[Obstacle], p: Vector2, radius: float) -> Vector2:
	for o in list:
		var clear := o.radius + radius
		var away := p - o.pos
		var d := away.length()
		if d < clear:
			if d < 0.0001:
				away = Vector2.RIGHT
				d = 1.0
			p = o.pos + away / d * clear
	return p
