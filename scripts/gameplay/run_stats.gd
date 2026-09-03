## Live hero stats for one run: base values from CharacterData (already
## multiplied by meta upgrades) plus additive modifiers from in-run passives.
class_name RunStats
extends RefCounted

## Speed lost at full carry capacity.
const WEIGHT_SLOW := 0.32

var base_max_hp := 100.0
var base_move_speed := 3.6
var base_pickup_radius := 1.6
var base_armor := 0.0
## What the hero can carry, and what they are carrying. The weapon system
## keeps `carried_weight` in step with the slots.
var carry_capacity := 10.0
var carried_weight := 0.0
## Flat damage soaked by SHIELD weapons that are currently up.
var shield_armor := 0.0

var mods := {
	"max_hp_mult": 0.0,
	"damage_mult": 0.0,
	"attack_speed_mult": 0.0,
	"move_speed_mult": 0.0,
	"pickup_radius_add": 0.0,
	"armor_add": 0.0,
	"regen_add": 0.0,
	"xp_mult": 0.0,
	"projectile_add": 0.0,
	"area_mult": 0.0,
}


static func from_character(data: CharacterData) -> RunStats:
	var s := RunStats.new()
	s.base_max_hp = data.max_hp
	s.base_move_speed = data.move_speed
	s.base_pickup_radius = data.pickup_radius
	s.base_armor = data.armor
	s.carry_capacity = data.carry_capacity
	return s


func add(stat: String, value: float) -> void:
	assert(mods.has(stat), "Unknown stat " + stat)
	mods[stat] = float(mods[stat]) + value


func max_hp() -> float:
	return base_max_hp * (1.0 + float(mods["max_hp_mult"]))


## Weight is the price of firepower: a hero at full carry capacity moves
## `WEIGHT_SLOW` slower than one carrying nothing.
func move_speed() -> float:
	var load := clampf(carried_weight / maxf(0.1, carry_capacity), 0.0, 1.0)
	return base_move_speed * (1.0 + float(mods["move_speed_mult"])) * (1.0 - WEIGHT_SLOW * load)


func pickup_radius() -> float:
	return base_pickup_radius + float(mods["pickup_radius_add"])


func armor() -> float:
	return base_armor + float(mods["armor_add"]) + shield_armor


func regen_per_second() -> float:
	return float(mods["regen_add"])


func damage_mult() -> float:
	return 1.0 + float(mods["damage_mult"])


func attack_speed_mult() -> float:
	return 1.0 + float(mods["attack_speed_mult"])


func xp_mult() -> float:
	return 1.0 + float(mods["xp_mult"])


func area_mult() -> float:
	return 1.0 + float(mods["area_mult"])


func projectile_add() -> int:
	return int(mods["projectile_add"])
