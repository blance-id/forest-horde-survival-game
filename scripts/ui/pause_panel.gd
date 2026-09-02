## Pause overlay. Runs while the tree is paused.
class_name PausePanel
extends Control

signal resume_pressed
signal quit_pressed

@onready var _resume: Button = %ResumeButton
@onready var _quit: Button = %QuitButton


func _ready() -> void:
	visible = false
	_resume.pressed.connect(func() -> void: resume_pressed.emit())
	_quit.pressed.connect(func() -> void: quit_pressed.emit())


func open() -> void:
	visible = true


func close() -> void:
	visible = false
