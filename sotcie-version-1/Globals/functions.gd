extends Node

enum {UNOPPOSED = 0, CLASH_WIN = 1, CLASH_TIE = 2, CLASH_LOSE = 3}

# Handling Game Processes
@export var unitList: Dictionary[String, Unit]
@export var scene: int = 0
@export var diceList: Dictionary[String, int]
@export var saveList: Dictionary[String, int]
@export var usedList: Dictionary[String, int]
@export var fileTree := DataTree.new()
@export var actionID: int = 0

# Temporary Function Vars
@export var references: Dictionary[String, Variant] = {}
@export var stack: Array[String] = []

func callj(method: String, args: Array) -> Variant:
	for i in args.size():
		args[i] = isNestedArg(args[i])
	if(fileTree.dget("Functions", {}).keys().has(method + ".json")):
		return jFunc(method, args)
	elif(has_method(method)):
		return callv(method, args)
	else: return null

func isNestedArg(arg) -> Variant:
	if(arg is Dictionary && Dictionary(arg).size() == 1):
		var key = arg.keys()[0]
		var val = arg[key]
		if((key is String && val is Array)):
			return isNestedArg(callj(key, val))
	return arg

func jFunc(method: String, args: Array) -> Variant:
	var funcData := Dictionary(fileTree.dget("Functions/" + method, {})).duplicate_deep()
	var argPairs = {}
	var argNames = funcData["Args"]
	if(!argNames is Array): return null
	if(args.size() < argNames.size()): return null
	for i in args.size():
		argPairs[argNames[i]] = args[i]
	if(argPairs.size() == 1): argPairs["_"] = "_"
	return sequence(method, funcData["Sequence"], argPairs)

func propCall(property: String, method: String, ...args: Array) -> Variant:
	if(get(property) == null): return null
	return Callable.create(get(property), method).callv(args)

func propCallFrom(object: Object, property: String, method: String, ...args: Array) -> Variant:
	if(object.get(property) == null): return null
	return Callable.create(object.get(property), method).callv(args)

func objCall(object: Object, method: String, ...args: Array) -> Variant:
	if(!object.has_method(method)): return null
	return object.callv(method, args)

func refCall(ref: String, method: String, ...args: Array) -> Variant:
	ref = parseRef(ref)
	if(!references.has(ref)): return null
	return Callable.create(references[ref], method).callv(args)

func parseRef(varName: String) -> String:
	if(references.has(varName)): return varName
	if(varName.begins_with("*")): return varName.substr(1)
	var stackName = "/".join(stack.slice(0, max(0, stack.size() - varName.count("."))))
	varName = varName.replace(".", "")
	if(stackName.is_empty()): return varName
	return stackName + "/" + varName

func clearScope(stackName := ""):
	if(stackName.is_empty()): stackName = "/".join(stack)
	if(stackName.begins_with("*")): stackName = stackName.substr(1)
	for k in references.keys():
		if(k.contains(stackName)):
			references.erase(k)

func sequence(stackName: String, calls := [], args := {}):
	stack.push_back(stackName)
	for arg in args:
		setVar(arg, args[arg])
	var val
	for method in calls:
		if(method is String && method == "return"): break
		val = isNestedArg(method)
	clearScope()
	stack.pop_back()
	return val

func ifelse(query: bool, trueCase: Array, falseCase := []):
	var val
	if(query):
		for c in trueCase.duplicate_deep():
			val = isNestedArg(c)
	else:
		for c in falseCase.duplicate_deep():
			val = isNestedArg(c)
	return val

func loop(arr: Array, commands: Array):
	var val
	for a in arr:
		for c in commands.duplicate_deep():
			val = isNestedArg(c)
	return val

func whileLoop(query: bool, commands: Array):
	var val
	while(query):
		for c in commands.duplicate_deep():
			val = isNestedArg(c)
	return val

func rangeTo(val: int):
	return range(val)

func addLog(text):
	GameManager.addPushConsole(str(text))

func setVar(varName: String, value, ref := "") -> Variant:
	varName = appendRef(varName, ref)
	var realName = parseRef(varName)
	return rawSetVar(realName, value)

func getVar(varName: String, default = null, ref := "") -> Variant:
	varName = appendRef(varName, ref)
	var realName = parseRef(varName)
	return rawGetVar(realName, default)

func appendRef(varName: String, ref := "") -> String:
	if(!ref.is_empty()):
		var prefix = getVar(ref, null)
		if(!prefix is String): return ""
		varName = prefix + "/" + varName
	return varName

func rawSetVar(varName: String, value) -> Variant:
	var oldVal = rawGetVar(varName)
	references[varName] = value
	return oldVal

func rawGetVar(varName: String, default = null) -> Variant:
	return references.get(varName, default)

func add(v1: int, v2: int) -> int:
	return v1 + v2

func addf(v1: float, v2: float) -> float:
	return v1 + v2

func sub(v1: int, v2: int) -> int:
	return v1 - v2

func subf(v1: float, v2: float) -> float:
	return v1 - v2

func mult(v1: int, v2: int) -> int:
	return v1 * v2

func multf(v1: float, v2: float) -> float:
	return v1 * v2

func div(v1: int, v2: int) -> int:
	@warning_ignore("integer_division")
	return v1 / v2

func divf(v1: float, v2: float) -> float:
	return v1 / v2

func mod(v1: int, v2: int) -> int:
	return v1 % v2

func pi() -> float:
	return PI

func randiXY(x: int, y: int) -> int:
	return randi_range(x, y)

func concat(...args: Array) -> String:
	return "".join(args)

func equals(v1, v2) -> bool:
	return(v1 == v2)

func greaterThan(v1, v2) -> bool:
	return(v1 > v2)
	
func lessThan(v1, v2) -> bool:
	return(v1 < v2)

func gte(v1, v2) -> bool:
	return(v1 >= v2)
	
func lte(v1, v2) -> bool:
	return(v1 <= v2)

func notBool(b: bool) -> bool:
	return !b

func min(v1: int, v2: int) -> int:
	return min(v1, v2)
	
func max(v1: int, v2: int) -> int:
	return max(v1, v2)

func joinArr(arr1: Array, arr2: Array) -> Array:
	var arrSum := arr1.duplicate()
	arrSum.append_array(arr2)
	return arrSum

func getUnitData(unit: String) -> DataTree:
	var unitVar: Unit = unitList.get(unit)
	if(unitVar == null): return null
	return unitVar.dataSet

func getUnitProp(unit: String, prop: String) -> Variant:
	var unitVar: Unit = unitList.get(unit)
	if(unitVar == null): return null
	return unitVar.get(prop)

func setUnitProp(unit: String, prop: String, val: Variant):
	var unitVar: Unit = unitList.get(unit)
	if(unitVar == null): return null
	unitVar.set(prop, val)

func getSingleTarget(target := "") -> String:
	if(target.is_empty()): target = getVar("Target", "")
	if(target == "@Self"): target = getVar("Self", "")
	return target

func dealDamage(amt: int, target := ""):
	target = getSingleTarget(target)
	if(target.is_empty()): return
	EventBus.emit_signal("dmgConsole", ["", target, amt, 0])

func dealStagger(amt: int, target := ""):
	target = getSingleTarget(target)
	if(target.is_empty()): return
	EventBus.emit_signal("dmgConsole", ["", target, 0, amt])

func statusInflict(status: String, amt := 1, target := "", nextScene := false):
	target = getSingleTarget(target)
	if(target.is_empty()): return
	var targetData := getUnitData(target)
	if(targetData == null): return
	
	var statusPath := "Statuses/" + status
	var statConditionPath := statusPath + "/Conditions"
	if(fileTree.dget(statusPath) == null): return
	
	targetData.instantiate(statusPath, {})
	var statusData = DataTree.new(targetData.dget(statusPath, {}))
	statusData.dset("File", statusPath)
	var stackName := "Stack" if(!nextScene) else "NextStack"
	statusData.dset(stackName, statusData.dget(stackName, 0) + amt)
	
	statusData.instantiate("Conditions", [])
	var statusDataConditions := Array(statusData.safeGet("Conditions", TYPE_ARRAY))
	var targetConditions := DataTree.new(targetData.safeGet("Conditions", TYPE_DICTIONARY))
	for k in fileTree.safeGet(statConditionPath, TYPE_DICTIONARY).keys():
		if(!statusDataConditions.has(k)):
			statusDataConditions.append(k)
		targetConditions.instantiate(str(k), [])
		var targetConditionArr = targetConditions.safeGet(str(k), TYPE_ARRAY)
		if(!targetConditionArr.has(status)):
			targetConditionArr.append(status)
	
	readUnitTag("Applied", target)
	if(getStatus(status, 0, target) <= 0): removeStatus(status, target)

func removeStatus(status: String, target := ""):
	target = getSingleTarget(target)
	if(target.is_empty()): return
	var targetData := getUnitData(target)
	if(targetData == null): return
	var statusConditions: Array = targetData.safeGet("Statuses/" + status + "/Conditions", TYPE_ARRAY)
	var unitConditions := DataTree.new(targetData.safeGet("Conditions", TYPE_DICTIONARY))
	for c in statusConditions:
		var conditionArr: Array = unitConditions.safeGet(c, TYPE_ARRAY)
		conditionArr.erase(status)
		if(conditionArr.is_empty()):
			unitConditions.erase(c)
	targetData.erase("Statuses/" + status)

func getStatus(status: String, default := 0, target := "") -> int:
	target = getSingleTarget(target)
	if(target.is_empty()): return default
	var targetData := getUnitData(target)
	if(targetData == null): return default
	return targetData.dget("Statuses/" + status + "/Stack", default)

func changePower(amt: int, die := DataTree.new()):
	if(die.dataset.is_empty()): die = getVar("DieData")
	die.dset("Base", add(die.dget("Base", 0), amt))

func roll(power: int, base := 0) -> int:
	if(power < 0): return base - randi_range(1, -power)
	if(power > 0): return randi_range(1, power) + base
	return base

func addUnit(code: String, data: Dictionary) -> Dictionary:
	var oldData = unitList.get(code, {})
	Unit.new(unitList, code, data)
	return oldData

func sceneStart():
	for u in unitList:
		readUnitTag("SceneEnd", u)
	scene += 1
	GameManager.addPushConsole("[u][b][lb]Scene " + str(scene) + "][/b][/u]")
	for u in unitList:
		readUnitTag("SceneStart", u)
	rollSpeed()
	regenLight()
	clearSaveDice()
	for u in unitList:
		readUnitTag("SceneStartPost", u)

func clearSaveDice():
	for u in unitList:
		var unit = unitList[u]
		unit.savedDice.clear()

func regenLight():
	for u in unitList:
		var unitData := unitList[u].dataSet
		var newLight = min(unitData.dget("Attributes/CurrentLight", 0) + 
		unitData.dget("Attributes/LightRegen", 0), 
		unitData.dget("Attributes/MaxLight", 0))
		unitData.dset("Attributes/CurrentLight", newLight)

func rollSpeed():
	diceList.clear()
	saveList.clear()
	usedList.clear()
	for u in unitList:
		var unitData = unitList[u].dataSet
		for i in int(unitData.dget("Attributes/SpeedDiceAmt", 0)):
			var val = max(1, roll(
				unitData.dget("Attributes/SpeedDiceSize", 0),
				unitData.dget("Attributes/SpeedDiceBase", 0),
			))
			diceList.set(u + "D" + str(i), val)

func nextTurn():
	var isSavedDice := diceList.is_empty()
	if(saveList.is_empty()): return
	var dice := getNextSpeedDie(isSavedDice)
	var unitName := getUnitFromDice(dice)
	var unitData := unitList[unitName].dataSet
	var actionList := fileTree.fetchData(unitData, "Actions")
	actionList.push_front("Void Dice" if(isSavedDice) else "Save Dice")
	

func getNextSpeedDie(searchSaved := true) -> String:
	var dict = diceList if(searchSaved) else saveList
	var val = highestInDict(dict)
	return(val if(val != null) else "")

func highestInDict(dict: Dictionary) -> Variant:
	var highVal := 0
	var highKey
	for k in dict:
		var val = dict[k]
		if(val > highVal):
			highVal = val
			highKey = k
	return highKey

# Removes next die if unspecified
func removeSpeedDice(die := "") -> int:
	if(die.is_empty()): die = getNextSpeedDie(!diceList.is_empty())
	if(die.is_empty()): return -1 # No Dice to Remove
	if(diceList.has(die)): # Removed from DiceList
		usedList.set(die, diceList[die])
		diceList.erase(die)
		return 1
	if(saveList.has(die)): # Removed from SaveList
		usedList.set(die, saveList[die])
		saveList.erase(die)
		return 2 
	return 0 # Die not Found

# Saves next die if unspecified
func saveSpeedDice(die := "") -> int:
	if(die.is_empty()): die = getNextSpeedDie(!diceList.is_empty())
	if(die.is_empty()): return -1 # No Dice to Save
	if(saveList.has(die)): return 1 # Die already saved
	if(!diceList.has(die)): return 0 # Die not Found
	saveList.set(die, diceList[die])
	diceList.erase(die)
	return 2 # Saved

func sortSpeedDice(dice: Dictionary) -> Array:
	var diceCopy := dice.duplicate(true)
	var sorted = []
	while(diceCopy.size() > 0):
		var key = highestInDict(diceCopy)
		sorted.push_back(key)
		diceCopy.erase(key)
	return sorted

func getUnitFromDice(dice: String) -> String:
	return dice.rsplit("D", true, 1)[0]

func executeSkills(u1: String, u2: String, a1: String, a2: String) -> void:
	if(!unitList.has(u1)): return
	if(!unitList.has(u2)): return
	var u1id := createAction(u1, a1)
	var u2id := createAction(u2, a2)
	var u1dice := Array(getAction(u1id, "diceArr", []))
	var u2dice := Array(getAction(u2id, "diceArr", []))
	var clashData := {
		"u1oldHealth": getUnitData(u1).safeGet("Attributes/CurrentHealth", -1),
		"u1oldStagger": getUnitData(u1).safeGet("Attributes/CurrentStagger", -1),
		"u2oldHealth": getUnitData(u2).safeGet("Attributes/CurrentHealth", -1),
		"u2oldStagger": getUnitData(u2).safeGet("Attributes/CurrentStagger", -1),
		"a1Finished?": false,
		"a2Finished?": false
	}
	setUnitProp(u1, "target", u2)
	setUnitProp(u2, "target", u1)
	setUnitProp(u1, "action", u1id)
	setUnitProp(u2, "action", u2id)
	readActionTag("OnUse", u1)
	readActionTag("OnUse", u2)
	while(!(u1dice.is_empty() && u2dice.is_empty())):
		if(u1dice.is_empty()): afterSkill(u1, u2, clashData, true)
		if(u2dice.is_empty()): afterSkill(u1, u2, clashData, false)
		var result := executeClash(
			u1, u2, u1id, u2id,
			"" if(u1dice.is_empty()) else u1dice.front(),
			"" if(u2dice.is_empty()) else u2dice.front())
		if(result == -1):
			if(u2dice.is_empty()):
				unitList[u1].savedDice.push_back(u1dice.pop_front())
			else:
				unitList[u2].savedDice.push_back(u2dice.pop_front())
			continue
		@warning_ignore("integer_division")
		if((result / 2) % 2 == 0): u1dice.pop_front()
		if(result % 2 == 0): u2dice.pop_front()
	afterSkill(u1, u2, clashData, true)
	afterSkill(u1, u2, clashData, false)
	setUnitProp(u1, "target", "")
	setUnitProp(u2, "target", "")
	setUnitProp(u1, "action", -1)
	setUnitProp(u2, "action", -1)
	clearScope(getAction(u1id, "path", ""))
	clearScope(getAction(u2id, "path", ""))

func afterSkill(u1: String, u2: String, data: Dictionary, isU1: bool):
	if(isU1):
		if(data["a1Finished?"]): return
		var u2Health = getUnitData(u2).safeGet("Attributes/CurrentHealth", -1)
		if(u2Health == 0 && data["u2oldHealth"] > 0): readActionTag("OnKill", u1)
		var u2Stagger = getUnitData(u2).safeGet("Attributes/CurrentStagger", -1)
		if(u2Stagger == 0 && data["u2oldStagger"] > 0): readActionTag("OnStagger", u1)
		readActionTag("AfterUse", u1)
		data["a1Finished?"] = true
	else:
		if(data["a2Finished?"]): return
		var u1Health = getUnitData(u1).safeGet("Attributes/CurrentHealth", -1)
		if(u1Health == 0 && data["u1oldHealth"] > 0): readActionTag("OnKill", u2)
		var u1Stagger = getUnitData(u1).safeGet("Attributes/CurrentStagger", -1)
		if(u1Stagger == 0 && data["u1oldStagger"] > 0): readActionTag("OnStagger", u2)
		readActionTag("AfterUse", u2)
		data["a2Finished?"] = true

func createAction(unit: String, action: String) -> int:
	var diceArr = createDiceArr(unit, action)
	if(diceArr.is_empty()): return -1
	actionID += 1
	var actionTree = DataTree.new()
	setVar("*Action" + str(actionID), actionTree)
	actionTree.dset("path", "*Action" + str(actionID))
	actionTree.dset("id", actionID)
	actionTree.dset("unit", unit)
	actionTree.dset("diceArr", diceArr)
	actionTree.dset("data", Dictionary(fileTree.safeGet("Actions/" + action, TYPE_DICTIONARY)).duplicate_deep())
	return actionID

func getAction(id: int, path := "", default = null) -> Variant:
	var data = getVar("*Action" + str(id))
	if(!(data is DataTree)): return default
	if(path.is_empty()): return data
	return data.dget(path, default)

func createDiceArr(unit: String, action: String) -> Array[String]:
	if(!unitList.has(unit)): return []
	if(action.is_empty()): return []
	var arr: Array[String]
	var saveCheck = action.replace("[lb]","[").split("SaveDice")
	var saveIndexes = null if(saveCheck.size() != 2) else JSON.parse_string(saveCheck[1])
	if(saveIndexes is Array):
		var unitSavedArr = unitList[unit].savedDice
		for i in saveIndexes:
			if(!(i is float)): continue
			var index = int(i)
			if(index >= unitSavedArr.size()): continue
			arr.append(unitSavedArr[index])
			unitSavedArr[index] = ""
		cleanSaveDice(unit)
	else:
		var actionData = fileTree.safeGet("Actions/" + action + "/Dice", TYPE_ARRAY)
		for i in Array(actionData).size():
			arr.append(action + "/" + str(i))
	return arr

func executeClash(u1: String, u2: String, a1id: int, a2id: int, d1: String, d2: String) -> int:
	var d1Data := DataTree.new(getDiceData(d1, a1id))
	var d2Data := DataTree.new(getDiceData(d2, a2id))
	setUnitProp(u1, "dieData", d1Data)
	setUnitProp(u2, "dieData", d2Data)
	readDieTag("Check", u1)
	readDieTag("Check", u2)
	var d1Roll := rollDie(u1, d1Data) if(!d1Data.dataset.is_empty()) else 0
	var d2Roll := rollDie(u2, d2Data) if(!d2Data.dataset.is_empty()) else 0
	EventBus.emit_signal("clashConsole", getDieType(d1Data), d1Roll, getDieType(d2Data), d2Roll)
	if(d1Roll - d2Roll == 0): return 0 # Tie or double unopposed
	var d1Result: int = 0 if(d1Roll * d2Roll == 0) else (sign(d2Roll - d1Roll) + 2)
	var d2Result: int = 0 if(d1Roll * d2Roll == 0) else (sign(d1Roll - d2Roll) + 2)
	
	var prioritySwitch := (d1Result <= d2Result) && d1Roll != 0
	var atkUnit := u1 if(prioritySwitch) else u2
	var defUnit := u2 if(prioritySwitch) else u1
	var atkRoll := d1Roll if(prioritySwitch) else d2Roll
	var defRoll := d2Roll if(prioritySwitch) else d1Roll
	var atkDice := d1Data if(prioritySwitch) else d2Data
	var defDice := d2Data if(prioritySwitch) else d1Data
	
	if((d1Result if(prioritySwitch) else d2Result) == CLASH_WIN):
		readDieTag("ClashWin", atkUnit)
		readDieTag("ClashLose", defUnit)
	
	if(canStore(atkDice) && defRoll == 0): return -1 # Defense/Counter Recycle
	if(isOffense(atkDice)): # Offense win
		var res = getResistance(defUnit, dmgType(atkDice))
		var dmg := atkRoll

		if(dmgType(defDice) == "Block"): # Offense beats Block
			dmg -= defRoll
		
		EventBus.emit_signal("dmgConsole", ["", defUnit, str(max(0, dmg + res[0])), str(max(0, dmg + res[1]))])
		readDieTag("Hit", atkUnit)
		if(atkRoll - atkDice.dget("Base", 0) == atkDice.dget("Dice", 0)):
			readDieTag("Crit", atkUnit)

	elif(dmgType(atkDice) == "Block"): # Block win
		EventBus.emit_signal("dmgConsole", ["", defUnit, "0", str(max(0, atkRoll - defRoll))])
	
	elif(!isOffense(defDice)): # Evade beats Evade/Block
		EventBus.emit_signal("dmgConsole", ["", atkUnit, "0", str(min(0, -atkRoll))])

	setUnitProp(u1, "dieData", DataTree.new())
	setUnitProp(u2, "dieData", DataTree.new())
	if(!(isOffense(atkDice) || isOffense(defDice))): return 0
	return recycleDie(d1Data, d1Result) * 2 + recycleDie(d2Data, d2Result)

func readUnitTag(tag: String, unit: String, metadata := {}):
	var unitData = getUnitData(unit)
	if(unitData == null): return
	if(metadata.is_empty()): metadata = composeConditionMetaData(unit)
	var conditionStatuses: Array = unitData.safeGet("Conditions/" + tag, TYPE_ARRAY)
	for status in conditionStatuses:
		var path = unitData.safeGet("Statuses/" + status + "/File", TYPE_STRING)
		var cond := DataTree.new(fileTree.safeGet(path + "/Conditions", TYPE_DICTIONARY))
		executeCondition(tag, cond, metadata)

func readActionTag(tag: String, unit: String, metadata := {}):
	if(metadata.is_empty()): metadata = composeConditionMetaData(unit)
	if(metadata.is_empty()): return
	var dataDict = getAction(metadata["Action"], "data")
	if(dataDict != null):
		executeCondition(tag, DataTree.new(dataDict), metadata)
	readUnitTag(tag, unit, metadata)

func readDieTag(tag: String, unit: String, metadata := {}):
	if(metadata.is_empty()): metadata = composeConditionMetaData(unit)
	if(metadata.is_empty()): return
	var dieData = metadata["DieData"]
	if(dieData != null):
		executeCondition(tag, dieData, metadata)
	readActionTag(tag, unit, metadata)

func executeCondition(tag: String, source: DataTree, metadata := {}):
	var tagSequence = source.copy().safeGet(tag, TYPE_ARRAY)
	sequence(tag, tagSequence, metadata)

func composeConditionMetaData(unit: String) -> Dictionary:
	if(!unitList.has(unit)): return {}
	return {
		"Self": unit,
		"Target": getUnitProp(unit, "target"),
		"Action": getUnitProp(unit, "action"),
		"@Action": getAction(getUnitProp(unit, "action"), "path", "*INVALID"),
		"DieData": getUnitProp(unit, "dieData"),
	}

func rollDie(_unit: String, die: DataTree) -> int:
	var dieTree = die
	return max(1, roll(dieTree.dget("Dice", 0), dieTree.dget("Base", 0)))
	#return max(1, callj("RollAdv", [dieTree.dget("Dice", 0), dieTree.dget("Base", 0)]))

func getDiceData(die: String, id := -1) -> Dictionary:
	var dieParse := die.split("/")
	if(dieParse.size() != 2): return {}
	if(id > 0): return getAction(id, "data/Dice/" + dieParse[1], {})
	return fileTree.safeGet("Actions/" + dieParse[0] + "/Dice/" + dieParse[1], TYPE_DICTIONARY)

func recycleDie(die: DataTree, result: int) -> int:
	var type = getDieType(die)
	if(!(type.contains("Evade") || type.contains("Counter"))): return 0
	if(result > 1): return 0
	return 1

func cleanSaveDice(unit: String) -> bool:
	if(!unitList.has(unit)): return false
	var wasChanged := false
	var unitDice = unitList[unit].savedDice
	while(unitDice.has("")):
		wasChanged = true
		unitDice.erase("")
	return wasChanged

func isOffense(die: DataTree) -> bool:
	var type = getDieType(die)
	if(type.is_empty()): return false
	return !(type.contains("Block") || type.contains("Evade"))

func canStore(die: DataTree) -> bool:
	var type = getDieType(die)
	if(type.is_empty()): return false
	return !isOffense(die) || type.contains("Counter")

func dmgType(die: DataTree) -> String:
	var type = getDieType(die)
	if(type.is_empty()): return ""
	return (type.split("Offense")[0]).split("Counter")[0]

func getDieType(die: DataTree) -> String:
	return die.safeGet("Type", TYPE_STRING)

func getResistance(unit: String, type: String) -> Array[int]:
	if(!unitList.has(unit)): return [0, 0]
	var unitData := unitList[unit].dataSet
	var dmgPath = "Attributes/" + type + "Damage"
	var stgPath = "Attributes/" + type + "Stagger"
	var dmgRes = simpleCollapse(unitData.dget(dmgPath))
	var stgRes = simpleCollapse(unitData.dget(stgPath))
	return [dmgRes, stgRes]

func simpleCollapse(data) -> int:
	if(data is int || data is float): return data
	if(data is String): return 0
	var sum := 0
	if(data is Array || data is Dictionary):
		for v in data:
			if(data is int || data is float): sum += data[v]
	return sum

func runGameStat() -> void:
	fileTree = GameManager.filetree
	unitList.clear()
	var gameStat = fileTree.dget("gamestat", {})
	scene = fileTree.fetchData(gameStat, "Scene")[0]
	GameManager.consoleLog = fileTree.fetchData(gameStat, "Console")[0]
	var unitKeys = Dictionary(fileTree.fetchData(gameStat, "Units")[0]).keys()
	for k in unitKeys:
		var unitName = fileTree.fetchData(gameStat, "Units/" + k + "/Unit")[0]
		addUnit(k, fileTree.dget("Units/" + unitName, {}))
	GameManager.pushConsole()
