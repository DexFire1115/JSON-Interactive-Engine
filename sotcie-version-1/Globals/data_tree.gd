extends Node

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
	if(data is Array && level.is_valid_int()):
		if(Array(data).size() <= (int(level))):
			Array(data).resize(int(level) + 1)
		data[int(level)] = value
		return 0
	if(data is Dictionary):
		data[level] = value
		return 1
	return -1

func isValidScope(data, level) -> Variant:
	return data is Dictionary || (data is Array && level.is_valid_int())

func fetchFail(input: Array) -> bool:
	return input[1] == -2 || input[1] > 1

func fetchSafely(data: Dictionary, path: String) -> Array:
	var output := fetchData(data,path)
	if(fetchFail(output)): return [[], -2]
	else: return output

func typeAt(data: Dictionary, path: String) -> String:
	var element = fetchData(data, path)[0]
	if(element is Dictionary): return "Dictionary"
	if(element is Array): return "Array"
	if(element is String): return "String"
	if(element is int): return "Integer"
	if(element is float): return "Float"
	return ""
