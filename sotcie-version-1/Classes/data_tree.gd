class_name DataTree
extends Resource

@export var dataset: Dictionary

func _init(data := {}) -> void:
	dataset = data

func toJSONStr() -> String:
	return JSON.stringify(dataset, "    ", false)

func isEmpty() -> bool:
	return dataset == null || dataset.is_empty()

func has(path: String) -> bool:
	return fetchData(dataset, path)[1] == 0

func dget(path: String, default = null) -> Variant:
	var rawFetch := fetchData(dataset, path)
	if(fetchFail(rawFetch)): return default
	return rawFetch[0]

func safeGet(path: String, type: int = TYPE_NIL) -> Variant:
	var default = null
	match type:
		TYPE_INT: default = 0
		TYPE_FLOAT: default = 0.0
		TYPE_BOOL: default = false
		TYPE_STRING: default = ""
		TYPE_ARRAY: default = []
		TYPE_DICTIONARY: default = {}
		-1: default = 0 # "NUM" Flex case
		-2: default = 0 # "Primitive" Flex case
	var result = dget(path, default)
	if(type < 0 && (typeof(result) == TYPE_FLOAT || typeof(result) == TYPE_INT)):
		return result
	if(type == -2 && (typeof(result) == TYPE_BOOL || typeof(result) == TYPE_STRING)):
		return result
	if(typeof(result) == type):
		return result
	return default

# -2 : Invalid Search (Does Not Exist)
# -1 : Shallow Search (Found Dict/Arr)
#  0 : Perfect Search (Found Value)
# +# : Premature End (Found Value with remaining path)
func fetchData(data, path: String) -> Array:
	var pathStack := path.split("/")
	if(!pathStack[pathStack.size() - 1].is_empty()):
		pathStack.append("")
	var element = data
	var state := 0
	var count := 0
	for level in pathStack:
		count += 1
		if(level.is_empty()):
			state = -1 if (element is Dictionary || element is Array) else 0
			break
		if(!(element is Dictionary || element is Array)): 
			state = pathStack.size() - count
			break
		if(!element.has(level)):
			if(element.has(level + ".json")):
				element = element[level + ".json"]
				continue
			if(element is Array && level.is_valid_int()):
				if(Array(element).size() > (int(level))):
					element = element[int(level)]
					continue
			state = -2
			break
		element = element[level]
	return [element, state]

func dset(path: String, value) -> Variant:
	return editData(dataset, path, value)

func instantiate(path: String, value, typeSafe := true) -> Variant:
	var oldData = dget(path)
	if(typeSafe && typeof(oldData) != typeof(value)):
		dset(path, value)
	elif(oldData == null):
		dset(path, value)
	return oldData

func editData(data, path: String, value) -> Variant:
	var pathStack := path.split("/")
	var element = data
	var oldElem = null
	for i in pathStack.size():
		var level := pathStack[i]
		if(level.is_empty()):
			break
		if(i + 1 == pathStack.size()):
			var oldDataFetch = fetchData(element, level)
			if(!fetchFail(oldDataFetch)): oldElem = oldDataFetch[0]
			createLevel(element, level, value)
			break
		var nextLevel := pathStack[i + 1]
		var elemFetch = fetchData(element, level)
		if(fetchFail(elemFetch) ||  !isValidScope(element, level)):
			if(!fetchFail(elemFetch)): oldElem = elemFetch[0]
			@warning_ignore("incompatible_ternary")
			var nextBracket = [] if(nextLevel.is_valid_int()) else {}
			createLevel(element, level, nextBracket)
			element = fetchData(element, level)[0]
			continue
		element = elemFetch[0]
	return oldElem

# -1 : Failed Case
#  0 : Array Insert
#  1 : Dictionary Insert
func createLevel(data, level: String, value = null) -> int:
	if(isValidArrayIndex(data, level)):
		if(Array(data).size() <= (int(level))):
			Array(data).resize(int(level) + 1)
		data[int(level)] = value
		return 0
	if(data is Dictionary):
		data[level] = value
		return 1
	return -1

func isValidScope(data, level) -> bool:
	return data is Dictionary || isValidArrayIndex(data, level)

func isValidArrayIndex(data, level) -> bool:
	return (data is Array && level.is_valid_int())

func isPrimitive(data) -> bool:
	return data is int || data is float || data is bool || data is String

func isComplex(data) -> bool:
	return data is Dictionary || data is Array

func fetchFail(input: Array) -> bool:
	return input[1] == -2 || input[1] > 1

func callArgSet(method: String, prefix := [], main := [], suffix := []) -> Array:
	return Functions.callj(method, Functions.joinArr(Functions.joinArr(prefix, main), suffix))

func getComplexArgs(path: String, method: String, prefixDefaults := []) -> Variant:
	var data = dget(path)
	if(data == null): return null
	if(!isComplex(data)): return callArgSet(method, prefixDefaults, [data])
	if(data is Dictionary): data = data.values()
	return Functions.callj(method, Functions.joinArr(prefixDefaults, data))

func getComplexSet(path: String, method: String, prefixDefaults := [], suffixDefaults := []) -> Variant:
	var data = dget(path)
	if(data == null): return null
	if(!isComplex(data)): return callArgSet(method, prefixDefaults, [data], suffixDefaults)
	if(data is Dictionary):
		var evalDict := {}
		for key in data:
			evalDict[key] = callArgSet(method, prefixDefaults, [data[key]], suffixDefaults)
		return evalDict
	if(data is Array):
		var evalArr := []
		for a in data:
			evalArr.push_back(callArgSet(method, prefixDefaults, [a], suffixDefaults))
		return evalArr
	return null

func getComplexSeqn(path: String, method: String, prefixDefaults := [], suffixDefaults := []) -> Variant:
	var data = dget(path)
	if(data == null): return null
	var tallyType = getComplexType(path)
	if(tallyType == TYPE_NIL): return null
	var tally = type_convert(null, tallyType)
	if(!isComplex(data)): tally = callArgSet(method, prefixDefaults, [tally, data], suffixDefaults)
	if(data is Dictionary):
		for key in data:
			tally = callArgSet(method, prefixDefaults, [tally, data[key]], suffixDefaults)
	if(data is Array):
		for a in data:
			tally = callArgSet(method, prefixDefaults, [tally, a], suffixDefaults)
	return tally

func getComplexType(path: String) -> int:
	var data = dget(path)
	if(data == null): return TYPE_NIL
	if(!isComplex(data)): return typeof(data)
	var currentType = int(TYPE_NIL)
	var oldType = currentType
	for v in data:
		currentType = typeof(v)
		if(currentType != oldType):
			if(oldType == TYPE_NIL): oldType = currentType
			else: return TYPE_NIL
	return currentType
