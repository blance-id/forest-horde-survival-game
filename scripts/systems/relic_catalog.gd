## The list of every relic in the game.
##
## The profile stores relics by id (a save file must never hold resource
## paths), so everything that reads the inventory needs one place to turn an id
## back into data. Boss drops pick from here too.
##
## The list is explicit rather than a directory scan: an Android export
## converts `.tres` to binary `.res`, so scanning for `.tres` finds nothing on
## device and the store comes up empty. Preloads are checked at build time and
## cannot go missing.
class_name RelicCatalog
extends RefCounted

const RELICS: Array[RelicData] = [
	preload("res://resources/relics/air_strike.tres"),
	preload("res://resources/relics/alpha_fang.tres"),
	preload("res://resources/relics/blood_rage.tres"),
	preload("res://resources/relics/field_kit.tres"),
	preload("res://resources/relics/lodestone.tres"),
	preload("res://resources/relics/supply_crate.tres"),
	preload("res://resources/relics/vampire_ward.tres"),
]

static var _by_id: Dictionary = {}


static func all() -> Array[RelicData]:
	return RELICS


static func get_relic(id: String) -> RelicData:
	if _by_id.is_empty():
		for r in RELICS:
			_by_id[r.id] = r
	return _by_id.get(id)


## What the store sells, cheapest first.
static func for_sale() -> Array[RelicData]:
	var out: Array[RelicData] = []
	for r in RELICS:
		if r.price > 0:
			out.append(r)
	out.sort_custom(func(a: RelicData, b: RelicData) -> bool: return a.price < b.price)
	return out


## Turn a list of ids into data, skipping anything that no longer exists — a
## save from an older build must not break the bag.
static func resolve(ids: Array) -> Array[RelicData]:
	var out: Array[RelicData] = []
	for id: String in ids:
		var r := get_relic(id)
		if r != null:
			out.append(r)
	return out
