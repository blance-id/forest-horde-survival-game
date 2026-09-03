## The run at a glance: one segment per wave, each with a portrait of what it
## sends, filling as the wave is cleared. The last segment is the boss. There
## is no clock in it — the bar answers "how much of this chapter is left",
## which is now a count of waves rather than a countdown.
class_name RunTimeline
extends Control

const TRACK := Color(0.12, 0.08, 0.05, 0.8)
const FILL := Color(1.0, 0.72, 0.25)
const FILL_BOSS := Color(0.95, 0.3, 0.25)
const OUTLINE := Color(0.25, 0.14, 0.08)
const MARKER_SIZE := 30.0
const BOSS_SIZE := 44.0
const BOSS_HEX := preload("res://assets/ui/adventure/hexagon_grey_red.png")

var _markers: Array[Dictionary] = []  # {icon, boss}
## Waves fully cleared, plus how far through the current one.
var _progress := 0.0
var _boss := false


func setup(chapter: ChapterData) -> void:
	_markers.clear()
	for i in chapter.wave_count():
		_markers.append({"icon": chapter.wave_icon(i), "boss": chapter.is_boss_wave(i)})
	_progress = 0.0
	_boss = false
	queue_redraw()


## `index` waves are done and the current one is `ratio` cleared.
func set_wave(index: int, ratio: float) -> void:
	var p := 0.0 if _markers.is_empty() else clampf((float(index) + ratio) / float(_markers.size()), 0.0, 1.0)
	if not is_equal_approx(p, _progress):
		_progress = p
		queue_redraw()


## Whether the boss has spawned but the run is not over: the bar turns red.
func set_boss_alive(alive: bool) -> void:
	_boss = alive
	queue_redraw()


func _draw() -> void:
	if _markers.is_empty():
		return
	var h := 14.0
	var y := size.y - h - 4.0
	var w := size.x
	var track := Rect2(0.0, y, w, h)
	draw_rect(track.grow(2.0), OUTLINE)
	draw_rect(track, TRACK)
	var fill_w := w * _progress
	if fill_w > 0.0:
		draw_rect(Rect2(0.0, y, fill_w, h), FILL_BOSS if _boss else FILL)
	# One portrait per wave, sitting at the end of its own segment. Waves the
	# player has already cleared fade out.
	var count := _markers.size()
	for i in count:
		var marker := _markers[i]
		var boss := bool(marker["boss"])
		var x := w * float(i + 1) / float(count)
		x = clampf(x, 16.0, w - 16.0)
		var s := BOSS_SIZE if boss else MARKER_SIZE
		var passed := _progress * float(count) >= float(i + 1)
		var tint := Color(1, 1, 1, 0.45) if passed else Color.WHITE
		var top := y + h * 0.5 - s * 0.5
		if boss:
			draw_texture_rect(BOSS_HEX, Rect2(x - s * 0.5, top - s * 0.15, s, s * 1.3), false, tint)
		else:
			draw_circle(Vector2(x, y + h * 0.5), s * 0.5 + 2.0, OUTLINE)
			draw_circle(Vector2(x, y + h * 0.5), s * 0.5, Color(0.93, 0.85, 0.7, tint.a))
		var icon: Texture2D = marker["icon"]
		if icon != null:
			var inset := s * 0.12
			draw_texture_rect(icon, Rect2(x - s * 0.5 + inset, top + inset, s - inset * 2.0, s - inset * 2.0), false, tint)
	# The hero: a cream dot with an outline riding the fill edge.
	var hx := clampf(fill_w, 8.0, w - 8.0)
	draw_circle(Vector2(hx, y + h * 0.5), 11.0, OUTLINE)
	draw_circle(Vector2(hx, y + h * 0.5), 8.0, Color(1.0, 0.96, 0.85))
