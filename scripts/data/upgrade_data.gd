## Passive in-run upgrade (max HP, damage, speed...). Each level adds
## `value_per_level` to the named stat in RunStats.
##
## Naming rule: `display_name` is what the stat does, never a joke. The card
## reads "Move Speed · Lv 2" over "+10% Move Speed (now +20%)" — a player must
## be able to tell what a pick did without guessing.
class_name UpgradeData
extends Resource

@export var id: String = "vitality"
@export var display_name: String = "Max Health"
## One level's effect, spelled out: "+20% Max HP".
@export var description: String = "+20% Max HP"
@export var icon: Texture2D
## One of RunStats' modifier keys: max_hp_mult, damage_mult, attack_speed_mult,
## move_speed_mult, pickup_radius_add, armor_add, regen_add, xp_mult, projectile_add.
@export var stat: String = "max_hp_mult"
@export var value_per_level: float = 0.2
@export var max_level: int = 5

@export_group("Number formatting")
## Multiplier stats print as percentages; flat stats print the raw value.
@export var percent: bool = true
## Suffix for flat stats, e.g. " HP/sec" or " m".
@export var unit: String = ""


## Running total after `level` levels, e.g. "+40%" or "+1.5 HP/sec".
func total_text(level: int) -> String:
	var total := value_per_level * float(level)
	if percent:
		return "%+d%%" % roundi(total * 100.0)
	var body := "%.1f" % total
	if body.ends_with(".0"):
		body = body.substr(0, body.length() - 2)
	return "%s%s%s" % ["+" if total >= 0.0 else "", body, unit]
