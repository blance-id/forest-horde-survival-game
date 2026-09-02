## Short vibration pulses for game feel, gated by the `haptics` setting and
## rate-limited so a swarm of hits does not turn into a constant buzz.
## `Input.vibrate_handheld` is a no-op on desktop, so callers never check.
class_name Haptics
extends RefCounted

const LIGHT_MS := 18
const MEDIUM_MS := 40
const HEAVY_MS := 90
## Minimum gap between pulses, in milliseconds.
const MIN_GAP_MS := 90

static var _last_msec := -MIN_GAP_MS


static func light() -> void:
	_pulse(LIGHT_MS)


static func medium() -> void:
	_pulse(MEDIUM_MS)


static func heavy() -> void:
	_pulse(HEAVY_MS)


static func _pulse(ms: int) -> void:
	if not bool(GameState.get_setting("haptics", true)):
		return
	var now := Time.get_ticks_msec()
	if now - _last_msec < MIN_GAP_MS:
		return
	_last_msec = now
	Input.vibrate_handheld(ms)
