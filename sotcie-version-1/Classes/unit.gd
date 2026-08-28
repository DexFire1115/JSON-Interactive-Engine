class_name Unit
extends Resource

@export var dataSet: DataTree
@export var gmUnitList: Dictionary
@export var savedDice: PackedStringArray = []
@export var target: String

func _init(data: Dictionary = {}, units: Dictionary = {}) -> void:
	dataSet = DataTree.new(data.duplicate_deep())
	gmUnitList = units
	
func _to_string() -> String:
	return ("[color=" + dataSet.safeGet("Color", TYPE_STRING) + "]" + 
		dataSet.safeGet("Name", TYPE_STRING) + "[/color]")
