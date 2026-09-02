## One horde enemy type. The model is a Kenney "mini" rigid-part character
## (root > leg-left, leg-right, torso > arm-left, arm-right, head); its parts
## are baked into a single mesh and animated in shaders/enemy_parts.gdshader,
## so hundreds of them cost one draw call.
class_name EnemyData
extends Resource

@export var id: String = "walker"
@export var display_name: String = "Walker"
@export var model: PackedScene
## Portrait used on the run timeline (event / boss markers).
@export var icon: Texture2D
@export var tint: Color = Color.WHITE
@export var scale: float = 1.0

@export_group("Stats")
@export var max_hp: float = 12.0
@export var speed: float = 1.5
@export var damage: float = 8.0
@export var attack_cooldown: float = 0.9
## Body radius used for separation, hits and contact damage.
@export var radius: float = 0.3
@export var knockback_resist: float = 0.0
## 0..0.95 cut taken off physical / magic hits. True damage ignores both.
@export var physical_resist: float = 0.0
@export var magic_resist: float = 0.0
## XP tier: 1, 2, 5, 10, 20, 50 or 100. Everything from 5 up counts as elite
## and drops tower ammo.
@export var xp: int = 1
@export var coin_chance: float = 0.04
@export var is_boss: bool = false
## Bosses only: the one-shot relic they leave for the next run.
@export var boss_drop: RelicData

@export_group("Attack")
## Enemies never damage on touch. They stop, wind up for `attack_windup`
## seconds (the tell), strike, and only then deal damage — so every hit the
## player takes was avoidable. Casters use a long wind-up plus a slow bolt.
@export var attack_windup: float = 0.35
## Extra reach past the two bodies touching.
@export var attack_reach: float = 0.15
## How far the strike lunges the body forward, in units.
@export var lunge: float = 0.45
## SoundBank name for the wind-up tell; "" plays nothing.
@export var windup_sound: String = ""
## Ranged attackers spit a bolt at the hero instead of striking.
@export var ranged: bool = false
## Ranged only: how far away the caster starts its spell.
@export var cast_range: float = 6.5
@export var bolt_speed: float = 3.0
@export var bolt_color: Color = Color(0.65, 0.35, 1.0)

@export_group("Animation")
## Steps per second at speed 1; the shader scales this with the instance speed.
@export var stride_rate: float = 2.2
@export var leg_swing_degrees: float = 35.0
## Rest pose of the arms is a T-pose: `arm_forward` swings them to the front
## (90 = straight ahead, zombie shamble), `arm_down` drops them to the sides.
@export var arm_forward_degrees: float = 85.0
@export var arm_down_degrees: float = 5.0
@export var arm_swing_degrees: float = 12.0
@export var bob_height: float = 0.03
@export var lean_degrees: float = 8.0


## ×5 and up: worth real XP, drops tower ammo, deserves a name on the timeline.
func is_elite() -> bool:
	return xp >= 5
