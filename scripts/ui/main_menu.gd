## Main menu screen.
extends Control

@onready var play_button: Button = %PlayButton
@onready var coins_label: Label = %CoinsLabel


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	GameState.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(GameState.get_coins())


func _on_play_pressed() -> void:
	SceneRouter.go_to(SceneRouter.GAME, {"chapter_id": GameState.selected_chapter_id})


func _on_coins_changed(amount: int) -> void:
	coins_label.text = str(amount)
