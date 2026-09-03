## A buildable gun nest. Wood pays for it; ammo looted from elites feeds it;
## the hero standing nearby is what actually pulls the trigger.
class_name TowerData
extends Resource

@export var id: String = "nest"
@export var display_name: String = "Gun Nest"
@export var icon: Texture2D
## Wood spent to raise one.
@export var wood_cost: int = 50
## The base sits still; the gun on top turns to track its target.
@export var base_model: PackedScene
@export var gun_model: PackedScene
## Where the gun sits, in base-scale units.
@export var gun_height: float = 0.55
## The base is scaled up to read as a structure; the gun keeps its own scale so
## it does not turn into a cannon.
@export var scale: float = 1.0
@export var gun_scale: float = 1.0

## Most nests that may stand at once.
@export var max_towers: int = 3
## Wood for each upgrade past the first level; one entry per extra level.
@export var upgrade_costs: PackedInt32Array = PackedInt32Array([50, 50])
## Per-level multipliers applied to damage, rate, range and hull.
@export var level_damage: PackedFloat32Array = PackedFloat32Array([1.0, 1.6, 2.4])
@export var level_rate: PackedFloat32Array = PackedFloat32Array([1.0, 1.3, 1.7])
@export var level_range: PackedFloat32Array = PackedFloat32Array([1.0, 1.15, 1.3])
@export var level_hull: PackedFloat32Array = PackedFloat32Array([1.0, 1.5, 2.1])

@export_group("Combat")
## The weapon it fires — reuses the hero's bullet pipeline, sounds and all.
@export var weapon: WeaponData
@export var damage: float = 14.0
@export var cooldown: float = 0.35
@export var range: float = 8.0
## The hero has to be this close for the tower to fire: it is their ammo.
@export var supply_range: float = 7.0
## Ammo burned per shot.
@export var ammo_per_shot: int = 1
@export var max_hp: float = 120.0
## Footprint the horde stops at, so they surround the nest instead of stacking
## on its centre.
@export var body_radius: float = 1.1
## Nothing walks through a nest — the hero is pushed out of this circle.
@export var solid_radius: float = 1.0
## How far the noise of firing carries. Silent towers pull nothing.
@export var noise_range: float = 11.0


func max_level() -> int:
	return upgrade_costs.size() + 1


## Wood to take a nest from `level` to the next one; 0 when it is maxed.
func upgrade_cost(level: int) -> int:
	var i := level - 1
	return upgrade_costs[i] if i >= 0 and i < upgrade_costs.size() else 0


func damage_at(level: int) -> float:
	return damage * _scale(level_damage, level)


func cooldown_at(level: int) -> float:
	return cooldown / maxf(0.1, _scale(level_rate, level))


func range_at(level: int) -> float:
	return range * _scale(level_range, level)


func hull_at(level: int) -> float:
	return max_hp * _scale(level_hull, level)


func _scale(curve: PackedFloat32Array, level: int) -> float:
	if curve.is_empty():
		return 1.0
	return curve[clampi(level - 1, 0, curve.size() - 1)]
