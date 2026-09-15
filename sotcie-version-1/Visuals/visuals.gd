extends Node2D

@onready var consoleframe = $Console
@onready var console = $Console/GUIArea

func _process(_delta: float) -> void:
	console.position = Vector2(0,0)
	console.size = get_window().size
