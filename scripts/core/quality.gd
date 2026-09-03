## One place that answers "how much visual work is this device allowed to do".
##
## Everything expensive reads its budget from here instead of guessing, so a
## player on a cheap phone can drop to LOW and a player on a flagship can turn
## MAX on and actually see the difference: sharper shadows, ground blade
## detail, more foliage, wider bloom and anti-aliasing.
class_name Quality
extends RefCounted

enum Level { LOW, NORMAL, MAX }

const SETTING := "quality"


static func level() -> Level:
	return clampi(int(GameState.get_setting(SETTING, Level.NORMAL)), 0, 2) as Level


static func set_level(value: Level) -> void:
	GameState.set_setting(SETTING, int(value))


static func label(value: Level) -> String:
	return ["LOW", "NORMAL", "MAX"][int(value)]


## Per-pixel grass blades in the ground shader.
static func ground_detail() -> bool:
	return level() != Level.LOW


static func shadows() -> bool:
	return level() != Level.LOW


## How far shadows are still drawn, in world units.
static func shadow_distance() -> float:
	return 45.0 if level() == Level.MAX else 30.0


static func shadow_size() -> int:
	return 4096 if level() == Level.MAX else 2048


## Grass tufts in the field that follows the hero. Grass is the surface the
## player looks at most, so it is the last thing to be cut and the first thing
## MAX spends on.
static func grass_tufts() -> int:
	return [3000, 12000, 24000][int(level())]


## Multiplier on decor / giant / bush counts.
static func decor_scale() -> float:
	return [0.45, 1.0, 1.45][int(level())]


## Which of the seven glow blur levels are mixed in. MAX adds a wide, soft
## halo on top of the tight one, which is most of the "expensive" look.
static func glow_levels() -> Array[int]:
	match level():
		Level.LOW:
			return [2]
		Level.MAX:
			return [1, 2, 4, 6]
		_:
			return [2, 4]


static func glow_strength() -> float:
	return [0.4, 0.55, 0.75][int(level())]


static func msaa() -> Viewport.MSAA:
	return Viewport.MSAA_4X if level() == Level.MAX else Viewport.MSAA_DISABLED


## Applied once when a screen with 3D comes up.
static func apply_to_viewport(viewport: Viewport) -> void:
	viewport.msaa_3d = msaa()
