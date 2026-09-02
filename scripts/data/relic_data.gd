## A one-shot item carried into a run: bought from the store or dropped by a
## boss. Using it spends it, and anything still in the bag when the hero dies
## is lost — that is the whole tension. Win, and the leftovers come home.
class_name RelicData
extends Resource

enum Kind {
	## Refill health.
	HEAL,
	## Kill everything on screen.
	NUKE,
	## Temporary damage multiplier.
	RAGE,
	## Pull every gem and coin on the map.
	MAGNET,
	## Free wood and ammo to open with.
	SUPPLY,
	## Temporary invulnerability.
	WARD,
}

@export var id: String = "field_kit"
@export var display_name: String = "Field Kit"
@export var description: String = "Heals you to full."
@export var icon: Texture2D
@export var kind: Kind = Kind.HEAL
## Meaning depends on the kind: fraction healed, damage multiplier, seconds…
@export var value: float = 1.0
## Seconds, for the kinds that last.
@export var duration: float = 0.0
## Coins in the store. 0 means it cannot be bought — a boss drop only.
@export var price: int = 0
