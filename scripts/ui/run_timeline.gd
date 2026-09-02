## The run at a glance: a bar that fills over the chapter with a portrait at
## every scripted event (hordes, the boss) so the player can see what is
## coming and how long is left.
class_name RunTimeline
extends Control

const TRACK := Color(0.12, 0.08, 0.05, 0.8)
const FILL := Color(1.0, 0.72, 0.25)
const FILL_BOSS := Color(0.95, 0.3, 0.25)
const OUTLINE := Color(0.25, 0.14, 0.08)
const MARKER_SIZE := 30.0
const BOSS_SIZE := 44.0
const BOSS_HEX := preload("res://assets/ui/adventure/hexagon_grey_red.png")

var _duration := 1.0
var _events: Array[Dictionary] = []  # {time, icon, boss}
var _progress := 0.0
var _boss := false


func setup(chapter: ChapterData) -> void:
	_duration = maxf(1.0, chapter.duration)
	_events.clear()
	for ev in chapter.events:
		var data: EnemyData = ev["enemy"]
		_events.append({"time": float(ev["time"]), "icon": data.icon, "boss": ev.get("kind") == "boss"})
	_progress = 0.0
	_boss = false
	queue_redraw()


func set_time(seconds: float) -> void:
	var p := clampf(seconds / _duration, 0.0, 1.0)
	if not is_equal_approx(p, _progress):
		_progress = p
		queue_redraw()


## Whether the boss has spawned but the run is not over: the bar turns red.
func set_boss_alive(alive: bool) -> void:
	_boss = alive
	queue_redraw()


func _draw() -> void:
	var h := 14.0
	var y := size.y - h - 4.0
	var w := size.x
	var track := Rect2(0.0, y, w, h)
	draw_rect(track.grow(2.0), OUTLINE)
	draw_rect(track, TRACK)
	var fill_w := w * _progress
	if fill_w > 0.0:
		draw_rect(Rect2(0.0, y, fill_w, h), FILL_BOSS if _boss else FILL)
	# Event portraits sit on the track; passed ones fade.
	for ev in _events:
		var x := w * clampf(float(ev["time"]) / _duration, 0.0, 1.0)
		var s := BOSS_SIZE if bool(ev["boss"]) else MARKER_SIZE
		var passed := float(ev["time"]) <= _progress * _duration
		var tint := Color(1, 1, 1, 0.45) if passed else Color.WHITE
		var top := y + h * 0.5 - s * 0.5
		if bool(ev["boss"]):
			draw_texture_rect(BOSS_HEX, Rect2(x - s * 0.5, top - s * 0.15, s, s * 1.3), false, tint)
		else:
			draw_circle(Vector2(x, y + h * 0.5), s * 0.5 + 2.0, OUTLINE)
			draw_circle(Vector2(x, y + h * 0.5), s * 0.5, Color(0.93, 0.85, 0.7, tint.a))
		var icon: Texture2D = ev["icon"]
		if icon != null:
			var inset := s * 0.12
			draw_texture_rect(icon, Rect2(x - s * 0.5 + inset, top + inset, s - inset * 2.0, s - inset * 2.0), false, tint)
	# The hero: a cream dot with an outline riding the fill edge.
	var hx := clampf(fill_w, 8.0, w - 8.0)
	draw_circle(Vector2(hx, y + h * 0.5), 11.0, OUTLINE)
	draw_circle(Vector2(hx, y + h * 0.5), 8.0, Color(1.0, 0.96, 0.85))
