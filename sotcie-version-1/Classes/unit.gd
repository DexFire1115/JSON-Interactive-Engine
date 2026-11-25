class_name Unit
extends Resource

@export var dataSet: DataTree
@export var gmUnitList: Dictionary
@export var savedDice: PackedStringArray = []
@export var caster: String
@export var target: String
@export var action: int
@export var dieData: DataTree
@export var speedDie: Array

func _init(list: Dictionary, key: String, data: Dictionary = {}) -> void:
	dataSet = DataTree.new(data.duplicate_deep())
	gmUnitList = list
	list[key] = self
	caster = key
	target = ""
	action = -1
	dieData = DataTree.new()
	speedDie = ["", false]

func toJSON() -> Dictionary:
	return {
		"dataSet": dataSet.dataset,
		"caster": caster,
		"target": target,
		"action": action,
		"dieData": dieData,
		"speedDie": speedDie
	}

func loadJSON(dict: Dictionary):
	dataSet = DataTree.new(dict.get("dataSet", {}))
	gmUnitList = Functions.unitList
	caster = dict.get("caster", "")
	target = dict.get("target", "")
	action = dict.get("action", -1)
	dieData = DataTree.new(dict.get("dieData", {}))
	speedDie = dict.get("speedDie", ["", false])

func _to_string() -> String:
	return ("[color=" + dataSet.safeGet("Color", TYPE_STRING) + "]" + 
		dataSet.safeGet("Name", TYPE_STRING) + "[/color]")
