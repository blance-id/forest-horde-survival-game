## Smoothed 45° follow camera. `pitch_degrees` / `distance` are the two knobs
## for the look of the game; KEEP_WIDTH keeps the visible ground width fixed
## across phone aspect ratios so taller screens simply see further ahead.
class_name CameraRig
extends Node3D

@export var pitch_degrees := 45.0
@export var distance := 12.5
@export var fov := 30.0
@export var smoothing := 8.0
## Shifts the look-at point along Z: positive moves it towards the camera, so
## the hero sits higher on screen.
@export var look_ahead := 0.0

var camera: Camera3D
var _shake := 0.0
var _shake_time := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = fov
	camera.near = 1.0
	camera.far = 80.0
	add_child(camera)
	_place()


func _place() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func snap_to(target: Vector3) -> void:
	position = target + Vector3(0.0, 0.0, look_ahead)


func follow(target: Vector3, delta: float) -> void:
	var goal := target + Vector3(0.0, 0.0, look_ahead)
	position = position.lerp(goal, minf(1.0, smoothing * delta))
	if _shake > 0.0:
		_shake_time += delta * 40.0
		var k := _shake * 0.12
		camera.h_offset = sin(_shake_time * 1.3) * k
		camera.v_offset = cos(_shake_time) * k
		_shake = maxf(0.0, _shake - delta * 4.0)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func shake(strength: float) -> void:
	_shake = maxf(_shake, clampf(strength, 0.0, 1.0))


func make_current() -> void:
	camera.current = true
