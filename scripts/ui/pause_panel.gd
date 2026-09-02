## Pause overlay. Runs while the tree is paused, and doubles as the build
## sheet: pausing is the only moment a player can actually read their numbers.
class_name PausePanel
extends Control

signal resume_pressed
signal quit_pressed

@onready var build_panel: BuildPanel = %BuildPanel
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
