## The list of every relic in the game, loaded once.
##
## The profile stores relics by id (a save file must not hold resource paths),
## so everything that reads the inventory needs one place to turn an id back
## into data. Boss drops pick from here too.
class_name RelicCatalog
extends RefCounted

const DIR := "res://resources/relics/"

static var _all: Array[RelicData] = []
static var _by_id: Dictionary = {}


static func all() -> Array[RelicData]:
	if _all.is_empty():
		_load()
	return _all


static func get_relic(id: String) -> RelicData:
	if _all.is_empty():
		_load()
	return _by_id.get(id)


## What the store sells, cheapest first.
static func for_sale() -> Array[RelicData]:
	var out: Array[RelicData] = []
	for r in all():
		if r.price > 0:
			out.append(r)
	out.sort_custom(func(a: RelicData, b: RelicData) -> bool: return a.price < b.price)
	return out


## Turn a list of ids into data, skipping anything that no longer exists —
## a save from an older build must not break the bag.
static func resolve(ids: Array) -> Array[RelicData]:
	var out: Array[RelicData] = []
	for id: String in ids:
		var r := get_relic(id)
		if r != null:
			out.append(r)
	return out


static func _load() -> void:
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".tres"):
			continue
		var relic: RelicData = load(DIR + file)
		if relic == null:
			continue
		_all.append(relic)
		_by_id[relic.id] = relic
	_all.sort_custom(func(a: RelicData, b: RelicData) -> bool: return a.id < b.id)
