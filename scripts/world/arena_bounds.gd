## The playable area's shape. A square arena reads as a box you are trapped
## in; a clearing or a clover reads as a place. Everything that has to stay
## inside the map — the hero, the horde, scatter, spawns — asks this, so a
## chapter changes its shape by changing one field.
class_name ArenaBounds
extends RefCounted

enum Shape {
	SQUARE,
	## A round clearing ringed by forest.
	CIRCLE,
	## Four lobes joined at the middle: chokepoints between open pockets.
	CLOVER,
}

var shape := Shape.SQUARE
var half := 22.0


static func from_chapter(chapter: ChapterData) -> ArenaBounds:
	var b := ArenaBounds.new()
	b.shape = chapter.arena_shape
	b.half = chapter.arena_half_size
	return b


## Distance from the centre to the edge along `angle`.
func radius_at(angle: float) -> float:
	match shape:
		Shape.CIRCLE:
			return half
		Shape.CLOVER:
			return half * (0.66 + 0.34 * absf(cos(2.0 * angle)))
		_:
			# Square: the edge is whichever axis runs out first.
			var c := absf(cos(angle))
			var s := absf(sin(angle))
			return half / maxf(0.0001, maxf(c, s))


func contains(p: Vector2, margin: float = 0.0) -> bool:
	var d := p.length()
	if d < 0.0001:
		return true
	return d <= radius_at(p.angle()) - margin


func clamp_point(p: Vector2, margin: float = 0.0) -> Vector2:
	var d := p.length()
	if d < 0.0001:
		return p
	var limit := maxf(0.5, radius_at(p.angle()) - margin)
	return p * (limit / d) if d > limit else p


func random_point(rng: RandomNumberGenerator, margin: float = 0.0) -> Vector2:
	var a := rng.randf() * TAU
	# sqrt keeps the scatter even instead of crowding the centre.
	var r := sqrt(rng.randf()) * maxf(0.5, radius_at(a) - margin)
	return Vector2(cos(a), sin(a)) * r
