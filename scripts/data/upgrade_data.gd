## Passive in-run upgrade (max HP, damage, speed...). Each level adds
## `value_per_level` to the named stat in RunStats.
class_name UpgradeData
extends Resource

@export var id: String = "vitality"
@export var display_name: String = "Vitality"
@export var card_title: String = "GET STRONGER!"
@export var description: String = "+20% max HP"
@export var icon: Texture2D
## One of RunStats' modifier keys: max_hp_mult, damage_mult, attack_speed_mult,
## move_speed_mult, pickup_radius_add, armor_add, regen_add, xp_mult, projectile_add.
@export var stat: String = "max_hp_mult"
@export var value_per_level: float = 0.2
@export var max_level: int = 5
