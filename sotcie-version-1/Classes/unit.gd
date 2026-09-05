class_name Unit
extends Resource

@export var dataSet: DataTree
@export var gmUnitList: Dictionary
@export var savedDice: PackedStringArray = []
@export var caster: String
@export var target: String
@export var action: int
@export var dieData: DataTree

func _init(list: Dictionary, key: String, data: Dictionary = {}) -> void:
	dataSet = DataTree.new(data.duplicate_deep())
	gmUnitList = list
	list[key] = self
	caster = key
	target = ""
	action = -1
	dieData = DataTree.new()
	
func _to_string() -> String:
	return ("[color=" + dataSet.safeGet("Color", TYPE_STRING) + "]" + 
		dataSet.safeGet("Name", TYPE_STRING) + "[/color]")
