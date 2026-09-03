## A driveable walker mech: what it looks like, what it shoots, and how long
## it lasts. Finite ammo and finite hull are the whole point — a mech is a
## resource you spend, not an upgrade you keep.
class_name VehicleData
extends Resource

@export var id: String = "walker_mech"
@export var display_name: String = "Walker Mech"
@export var icon: Texture2D
@export var model: PackedScene
@export var scale: float = 1.35
## The hero shrinks into the cockpit rather than standing on the roof.
@export var hero_scale: float = 0.55
@export var muzzle_height: float = 0.8
## Mechs are parked at least this far from the hero's start.
@export var spawn_clearance: float = 12.0

@export_group("Combat")
@export var weapon: WeaponData
@export var damage: float = 30.0
@export var cooldown: float = 0.18
@export var range: float = 11.0
## Shots before it is dry; each shot is a pair from the twin cannons.
@export var ammo: int = 160
@export var max_hull: float = 400.0
