## Three damage types, so a build is a set of answers rather than one number.
##
## Physical is the default and the one most enemies shrug off a little of;
## magic goes through armour but not wards; true damage ignores everything and
## is therefore rare. Each type owns a colour, and every damage number on
## screen is painted with it — that colour *is* the tutorial: a player who
## sees pale numbers on a wisp and violet ones landing hard has learned the
## system without reading anything.
class_name Damage
extends RefCounted

enum Type { PHYSICAL, MAGIC, TRUE }

const COLORS: Array[Color] = [
	Color(1.0, 0.96, 0.82),  # physical — bone cream
	Color(0.76, 0.55, 1.0),  # magic — violet
	Color(1.0, 0.5, 0.2),    # true — molten
]
const NAMES: Array[String] = ["Physical", "Magic", "True"]


static func color(type: Type) -> Color:
	return COLORS[int(type)]


static func type_name(type: Type) -> String:
	return NAMES[int(type)]


## What actually lands after the target's resistances.
static func resolve(amount: float, type: Type, target: EnemyData) -> float:
	match type:
		Type.MAGIC:
			return amount * (1.0 - clampf(target.magic_resist, 0.0, 0.95))
		Type.TRUE:
			return amount
		_:
			return amount * (1.0 - clampf(target.physical_resist, 0.0, 0.95))
