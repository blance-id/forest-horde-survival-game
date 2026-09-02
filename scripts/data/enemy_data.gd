## One horde enemy type. The model is a Kenney "mini" rigid-part character
## (root > leg-left, leg-right, torso > arm-left, arm-right, head); its parts
## are baked into a single mesh and animated in shaders/enemy_parts.gdshader,
## so hundreds of them cost one draw call.
class_name EnemyData
extends Resource

@export var id: String = "walker"
@export var display_name: String = "Walker"
@export var model: PackedScene
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
@export var xp: int = 1
@export var coin_chance: float = 0.04
@export var is_boss: bool = false

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
