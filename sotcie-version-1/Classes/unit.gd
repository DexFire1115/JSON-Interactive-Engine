class_name Unit
extends Resource

@export var dataSet: Dictionary
@export var gmUnitList: Dictionary
@export var savedDice: PackedStringArray = []
@export var target: String

func _init(data: Dictionary = {}, units: Dictionary = {}) -> void:
	dataSet = data.duplicate_deep()
	gmUnitList = units

func fetchData(path: String) -> Array:
	return DataTree.fetchData(dataSet, path)
	
func _to_string() -> String:
	return "[color=" + fetchData("Color")[0] + "]" + fetchData("Name")[0] + "[/color]"
