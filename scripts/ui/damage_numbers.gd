## Floating damage numbers. A fixed pool of Labels is recycled oldest-first;
## every frame the live ones are re-projected from their world position so
## they stick to the action while the camera moves. Colour carries meaning:
## hits are tinted by damage type, kills are gold, damage to the hero is red.
class_name DamageNumbers
extends Control

enum Style { HIT, KILL, HERO }

const POOL := 40
const LIFE := 0.65
const RISE := 0.9
const POP_TIME := 0.1

const COLORS := {
	Style.HIT: Color(1.0, 0.96, 0.8),
	Style.KILL: Color(1.0, 0.72, 0.25),
	Style.HERO: Color(1.0, 0.36, 0.3),
}
const SCALES := {
	Style.HIT: 0.85,
	Style.KILL: 1.15,
	Style.HERO: 1.1,
}


class Entry:
	var label: Label
	var world: Vector3
	var age := 0.0
	var base_scale := 1.0
	var drift := 0.0


var _labels: Array[Label] = []
var _active: Array[Entry] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	for i in POOL:
		var label := Label.new()
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.theme_type_variation = &"Number"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		_labels.append(label)


## A `tint` with any alpha overrides the style colour, which is how hits get
## painted by damage type.
func spawn(world: Vector3, amount: float, style: Style, tint: Color = Color(0, 0, 0, 0)) -> void:
	var label := _labels[_next]
	_next = (_next + 1) % POOL
	# Reclaim the entry if that label is still flying.
	for i in _active.size():
		if _active[i].label == label:
			_active.remove_at(i)
			break
	var e := Entry.new()
	e.label = label
	e.world = world
	e.base_scale = float(SCALES[style])
	e.drift = _rng.randf_range(-0.35, 0.35)
	label.text = str(maxi(1, roundi(amount)))
	label.modulate = tint if tint.a > 0.0 else COLORS[style]
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	label.visible = true
	_active.append(e)


func update(camera: Camera3D, delta: float) -> void:
	var i := 0
	while i < _active.size():
		var e := _active[i]
		e.age += delta
		var u := e.age / LIFE
		if u >= 1.0:
			e.label.visible = false
			_active[i] = _active[_active.size() - 1]
			_active.pop_back()
			continue
		var rise := RISE * (1.0 - (1.0 - u) * (1.0 - u))  # ease out
		var world := e.world + Vector3(e.drift * u, rise, 0.0)
		var screen := camera.unproject_position(world)
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - e.age / POP_TIME)
		var s := e.base_scale * pop
		e.label.scale = Vector2(s, s)
		e.label.position = screen - e.label.size * 0.5
		e.label.modulate.a = 1.0 - smoothstep(0.55, 1.0, u)
		i += 1


func clear() -> void:
	for e in _active:
		e.label.visible = false
	_active.clear()
