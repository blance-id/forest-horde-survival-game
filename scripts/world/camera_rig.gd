## Smoothed angled follow camera: close and fairly wide so the world has real
## perspective (props lean away at the frame edges) instead of an isometric
## look. `pitch_degrees` / `distance` / `fov` are the knobs; KEEP_WIDTH keeps
## the visible ground width fixed across phone aspect ratios so taller screens
## simply see further ahead.
class_name CameraRig
extends Node3D

@export var pitch_degrees := 55.0
@export var distance := 10.45
@export var fov := 40.0
@export var smoothing := 8.0
## Shifts the look-at point along Z: positive moves it towards the camera, so
## the hero sits higher on screen.
@export var look_ahead := 0.0
## How far (world units) the frame leads the hero in the movement direction,
## so the player sees what they are running into.
@export var lead := 0.9
@export var lead_smoothing := 3.0

## Screen shake: `shake()` adds trauma, the offset scales with trauma² so
## small hits barely nudge while boss kills really rattle the frame.
const SHAKE_OFFSET := 0.35
const SHAKE_ROLL := 0.035
const SHAKE_SPEED := 22.0
const SHAKE_DECAY := 1.6

var camera: Camera3D
var _trauma := 0.0
var _shake_time := 0.0
var _lead := Vector3.ZERO
var _noise := FastNoiseLite.new()


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = fov
	camera.near = 1.0
	camera.far = 80.0
	add_child(camera)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_place()


func _place() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func snap_to(target: Vector3) -> void:
	position = target + Vector3(0.0, 0.0, look_ahead)


func follow(target: Vector3, delta: float, move_dir: Vector2 = Vector2.ZERO) -> void:
	var lead_goal := Vector3(move_dir.x, 0.0, move_dir.y).limit_length(1.0) * lead
	_lead = _lead.lerp(lead_goal, minf(1.0, lead_smoothing * delta))
	var goal := target + _lead + Vector3(0.0, 0.0, look_ahead)
	position = position.lerp(goal, minf(1.0, smoothing * delta))
	if _trauma > 0.0:
		_shake_time += delta * SHAKE_SPEED
		var k := _trauma * _trauma
		camera.h_offset = _noise.get_noise_2d(_shake_time, 0.0) * SHAKE_OFFSET * k
		camera.v_offset = _noise.get_noise_2d(0.0, _shake_time) * SHAKE_OFFSET * k
		camera.rotation.z = _noise.get_noise_2d(_shake_time, 37.0) * SHAKE_ROLL * k
		_trauma = maxf(0.0, _trauma - delta * SHAKE_DECAY)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.rotation.z = 0.0


func shake(strength: float) -> void:
	_trauma = clampf(_trauma + strength * 0.6, 0.0, 1.0)


func make_current() -> void:
	camera.current = true
