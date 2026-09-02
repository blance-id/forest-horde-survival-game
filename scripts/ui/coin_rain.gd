## Ad-style coin flight: a 2D coin pops out at the pickup's screen position,
## arcs into the HUD counter and calls back when it lands so the counter can
## bump. Pooled; when every coin is busy the callback fires immediately.
class_name CoinRain
extends Control

const POOL_SIZE := 24
const FLIGHT_TIME := 0.55
const COIN := preload("res://assets/ui/items/coin.png")
const SIZE := Vector2(40, 40)

var _pool: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for i in POOL_SIZE:
		var c := TextureRect.new()
		c.texture = COIN
		c.size = SIZE
		c.pivot_offset = SIZE * 0.5
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.mouse_filter = MOUSE_FILTER_IGNORE
		c.visible = false
		add_child(c)
		_pool.append(c)


func fly(from: Vector2, to: Vector2, on_arrive: Callable) -> void:
	var coin := _free()
	if coin == null:
		on_arrive.call()
		return
	coin.visible = true
	coin.position = from - SIZE * 0.5
	coin.scale = Vector2(0.4, 0.4)
	coin.modulate = Color.WHITE
	# Quadratic curve: kick up and sideways first, then dive at the counter.
	var lift := Vector2(randf_range(-90.0, 90.0), -140.0)
	var control := from.lerp(to, 0.35) + lift
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(coin, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_method(func(t: float) -> void:
		var p := from.lerp(control, t).lerp(control.lerp(to, t), t)
		coin.position = p - SIZE * 0.5
		coin.rotation = t * TAU * 0.5,
		0.0, 1.0, FLIGHT_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(func() -> void:
		coin.visible = false
		on_arrive.call())


func _free() -> TextureRect:
	for c in _pool:
		if not c.visible:
			return c
	return null
