## A buildable gun nest. Wood pays for it; ammo looted from elites feeds it;
## the hero standing nearby is what actually pulls the trigger.
class_name TowerData
extends Resource

@export var id: String = "nest"
@export var display_name: String = "Gun Nest"
@export var icon: Texture2D
## Wood spent to raise one.
@export var wood_cost: int = 10
## The base sits still; the gun on top turns to track its target.
@export var base_model: PackedScene
@export var gun_model: PackedScene
## Where the gun sits, in base-scale units.
@export var gun_height: float = 0.55
## The base is scaled up to read as a structure; the gun keeps its own scale so
## it does not turn into a cannon.
@export var scale: float = 1.0
@export var gun_scale: float = 1.0

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
## How far the noise of firing carries. Silent towers pull nothing.
@export var noise_range: float = 11.0
