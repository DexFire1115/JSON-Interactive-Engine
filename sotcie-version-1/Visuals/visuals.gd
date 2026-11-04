extends Node2D

@onready var consoleframe = $Console
@onready var console = $Console/GUIArea
@onready var sound = $Sound

func _ready() -> void:
	EventBus.connect("playSound", playSound)

func _process(_delta: float) -> void:
	console.position = Vector2(0,0)
	console.size = get_window().size

func playSound(audio):
	sound.stream = audio
	sound.play()
