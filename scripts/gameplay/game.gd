## Gameplay screen: one run of a chapter.
extends Node2D

var chapter_id: String = "chapter_01"


func setup(data: Dictionary) -> void:
	chapter_id = data.get("chapter_id", chapter_id)
	Log.info("Game", "Run started: %s" % chapter_id)


func on_app_background() -> void:
	get_tree().paused = true
