## A weapon the hero can carry. Weapons level up during a run; each entry in
## `level_ups` overrides stats for that level (index 0 = level 2) and carries the
## card text shown on the ad-style upgrade card.
class_name WeaponData
extends Resource

enum Kind { PROJECTILE, ORBIT, AURA }

@export var id: String = "blaster"
@export var display_name: String = "Blaster"
@export var description: String = "Shoots the nearest zombie."
@export var icon: Texture2D
@export var kind: Kind = Kind.PROJECTILE
@export var max_level: int = 6
## ORBIT: model spun around the hero (first MeshInstance3D is used).
@export var projectile_model: PackedScene
## AURA: disc colour. PROJECTILE: bullet colour.
@export var tint: Color = Color(1.0, 0.85, 0.35)

@export_group("Sounds")
## SoundBank name played per shot (PROJECTILE) or per pulse (AURA); "" = silent.
@export var fire_sound: String = "shot_blaster"
## SoundBank name played when this weapon damages an enemy without killing it.
@export var hit_sound: String = "hit_zombie"

@export_group("Base stats")
@export var damage: float = 10.0
@export var cooldown: float = 0.5
@export var projectile_count: int = 1
@export var spread_degrees: float = 12.0
@export var projectile_speed: float = 14.0
@export var pierce: int = 0
@export var range: float = 10.0
@export var knockback: float = 1.5
@export var projectile_scale: float = 1.0
## ORBIT: orbit radius; AURA: damage radius.
@export var area: float = 1.6

@export_group("Level ups")
## Array of {"text": String, <stat>: value, ...}. Stats listed here replace
## the base value from that level on.
@export var level_ups: Array[Dictionary] = []


## Effective stats at `level` (1-based) as a dictionary of stat name -> value.
func stats_at(level: int) -> Dictionary:
	var s := {
		"damage": damage,
		"cooldown": cooldown,
		"projectile_count": projectile_count,
		"spread_degrees": spread_degrees,
		"projectile_speed": projectile_speed,
		"pierce": pierce,
		"range": range,
		"knockback": knockback,
		"projectile_scale": projectile_scale,
		"area": area,
	}
	for i in range(mini(level - 1, level_ups.size())):
		for key: String in level_ups[i]:
			if key != "text":
				s[key] = level_ups[i][key]
	return s


## The card's number line: damage, how fast it swings and what one full
## volley lands. Burst is what players actually compare weapons on.
func stat_line(level: int, s: Dictionary) -> String:
	var cd := maxf(0.01, float(s["cooldown"]))
	var shots := maxi(1, int(s["projectile_count"]))
	var dmg := float(s["damage"])
	var parts := ["%d damage" % roundi(dmg), "%.1f/sec" % (1.0 / cd)]
	if shots > 1:
		parts.append("burst %d" % roundi(dmg * float(shots)))
	if int(s["pierce"]) > 0:
		parts.append("pierce %d" % int(s["pierce"]))
	return "  ·  ".join(parts)


func level_text(level: int) -> String:
	var i := level - 2
	if i >= 0 and i < level_ups.size():
		return String(level_ups[i].get("text", ""))
	return description
