extends Node2D

@onready var consoleFrame = $Divider/Console
@onready var sideConsoleFrame = $Divider/SideConsole
@onready var console = $Divider/Console/GUIArea
@onready var sideConsole = $Divider/SideConsole/GUIArea
@onready var divider = $Divider

func _ready() -> void:
	sideConsoleFrame.consoleLog = GameManager.sideLog

func _process(_delta: float) -> void:
	divider.position = Vector2(0,0)
	divider.size = get_window().size
	divider.split_offsets[0] -= 1
	#console.position = Vector2(0,0)
	#console.size.y = get_window().size.y
	#sideConsole.position = Vector2(0 + console.size.x,0)
	#sideConsole.size.y = get_window().size.y
