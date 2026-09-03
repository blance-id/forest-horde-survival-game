## Playable hero definition. Visuals are Kenney "mini" rigs (skinned, shared
## animation names); swapping the model is enough to swap the hero's look.
class_name CharacterData
extends Resource

@export var id: String = "ranger"
@export var display_name: String = "The Ranger"
@export var model: PackedScene
@export var weapon_model: PackedScene
## Bone the weapon model is attached to and its local offset in that bone.
@export var weapon_bone: String = "arm-right"
@export var weapon_offset: Vector3 = Vector3(0.0, -0.22, 0.05)
@export var weapon_rotation_degrees: Vector3 = Vector3(90, 0, 0)
@export var weapon_scale: float = 1.0
## Where bullets leave, relative to the hero (forward is -Z).
@export var muzzle_offset: Vector3 = Vector3(0.12, 0.45, -0.45)

@export_group("Stats")
@export var max_hp: float = 100.0
@export var move_speed: float = 3.6
@export var pickup_radius: float = 1.6
@export var armor: float = 0.0
## Total weapon weight this class can carry at once. One heavy weapon fills
## it; two or three light ones also fit.
@export var carry_capacity: float = 10.0
@export var starting_weapon: WeaponData
## The five weapons this class can be offered. Empty falls back to the set on
## the Game scene.
@export var weapons: Array[WeaponData] = []

@export_group("Animation")
@export var anim_idle: String = "holding-both"
@export var anim_move: String = "sprint"
@export var anim_die: String = "die"
