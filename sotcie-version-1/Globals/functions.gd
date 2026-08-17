extends Node

enum {UNOPPOSED = 0, CLASH_WIN = 1, CLASH_TIE = 2, CLASH_LOSE = 3}

var references: Dictionary[String, Variant] = {}

# @export var tempArr := [0, 1, 2]


func callj(method: String, args: Array) -> Variant:
	for i in args.size():
		args[i] = isNestedArg(args[i])
	if(has_method(method)):
		return callv(method, args)
	else: return null

func isNestedArg(arg) -> Variant:
	if(arg is Dictionary && Dictionary(arg).size() == 1):
		var key = Dictionary(arg).keys()[0]
		return isNestedArg(callj(key, arg[key]))
	return arg

func propCall(property: String, method: String, ...args: Array) -> Variant:
	if(get(property) == null): return null
	return Callable.create(get(property), method).callv(args)

func sequence(args: Array):
	for method in args:
		isNestedArg(method)

func setVar(varName: String, value) -> Variant:
	var oldVal = getVar(varName)
	references[varName] = value
	return oldVal

func getVar(varName: String) -> Variant:
	return references.get(varName)

func roll(power: int, base := 0) -> int:
	if(power < 0): return base - randi_range(1, -power)
	if(power > 0): return randi_range(1, power) + base
	return base

func addUnit(code: String, data: Dictionary) -> Dictionary:
	var oldData = GameManager.unitList.get(code, {})
	GameManager.unitList.set(code, Unit.new(data, GameManager.unitList))
	return oldData

func sceneStart():
	GameManager.scene += 1
	GameManager.addPushConsole("[u][b][lb]Scene " + 
	str(GameManager.scene) + "][/b][/u]")
	rollSpeed()
	regenLight()

func regenLight():
	for u in GameManager.unitList:
		var unit = GameManager.unitList[u]
		var newLight = min(DataTree.fetchData(unit.dataSet,"Attributes/CurrentLight")[0] + 
		DataTree.fetchData(unit.dataSet,"Attributes/LightRegen")[0], 
		DataTree.fetchData(unit.dataSet,"Attributes/MaxLight")[0])
		DataTree.editData(unit.dataSet,"Attributes/CurrentLight", newLight)

func rollSpeed():
	GameManager.diceList.clear()
	GameManager.saveList.clear()
	GameManager.usedList.clear()
	for u in GameManager.unitList:
		var unit = GameManager.unitList[u]
		for i in int(DataTree.fetchData(unit.dataSet,"Attributes/SpeedDiceAmt")[0]):
			var val = max(1, roll(
				DataTree.fetchData(unit.dataSet,"Attributes/SpeedDiceSize")[0],
				DataTree.fetchData(unit.dataSet,"Attributes/SpeedDiceBase")[0]
			))
			GameManager.diceList.set(u + "D" + str(i), val)

func nextTurn():
	var isSavedDice := GameManager.diceList.is_empty()
	if(GameManager.saveList.is_empty()): return
	var dice := getNextSpeedDie(isSavedDice)
	var unitName := getUnitFromDice(dice)
	var unitData := GameManager.unitList[unitName].dataSet
	var actionList := DataTree.fetchData(unitData, "Actions")
	actionList.push_front("Void Dice" if(isSavedDice) else "Save Dice")
	

func getNextSpeedDie(searchSaved := true) -> String:
	var dict = GameManager.diceList if(searchSaved) else GameManager.saveList
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
	if(die.is_empty()): die = getNextSpeedDie(!GameManager.diceList.is_empty())
	if(die.is_empty()): return -1 # No Dice to Remove
	if(GameManager.diceList.has(die)): # Removed from DiceList
		GameManager.usedList.set(die, GameManager.diceList[die])
		GameManager.diceList.erase(die)
		return 1
	if(GameManager.saveList.has(die)): # Removed from SaveList
		GameManager.usedList.set(die, GameManager.saveList[die])
		GameManager.saveList.erase(die)
		return 2 
	return 0 # Die not Found

# Saves next die if unspecified
func saveSpeedDice(die := "") -> int:
	if(die.is_empty()): die = getNextSpeedDie(!GameManager.diceList.is_empty())
	if(die.is_empty()): return -1 # No Dice to Save
	if(GameManager.saveList.has(die)): return 1 # Die already saved
	if(!GameManager.diceList.has(die)): return 0 # Die not Found
	GameManager.saveList.set(die, GameManager.diceList[die])
	GameManager.diceList.erase(die)
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
	if(!GameManager.unitList.has(u1)): return
	if(!GameManager.unitList.has(u2)): return
	var u1dice := createDiceArr(u1, a1)
	var u2dice := createDiceArr(u2, a2)
	while(!(u1dice.is_empty() && u2dice.is_empty())):
		var result := executeClash(
			u1, 
			u2, 
			"" if(u1dice.is_empty()) else u1dice.front(),
			"" if(u2dice.is_empty()) else u2dice.front())
		if(result == -1):
			if(u2dice.is_empty()):
				GameManager.unitList[u1].savedDice.push_back(u1dice.pop_front())
			else:
				GameManager.unitList[u2].savedDice.push_back(u2dice.pop_front())
			continue
		@warning_ignore("integer_division")
		if((result / 2) % 2 == 0): u1dice.pop_front()
		if(result % 2 == 0): u2dice.pop_front()

func createDiceArr(unit: String, action: String) -> Array[String]:
	if(!GameManager.unitList.has(unit)): return []
	if(action.is_empty()): return []
	var arr: Array[String]
	var saveCheck = action.replace("[lb]","[").split("SaveDice")
	var saveIndexes = null if(saveCheck.size() != 2) else JSON.parse_string(saveCheck[1])
	if(saveIndexes is Array):
		var unitSavedArr = GameManager.unitList[unit].savedDice
		for i in saveIndexes:
			if(!(i is float)): continue
			var index = int(i)
			if(index >= unitSavedArr.size()): continue
			arr.append(unitSavedArr[index])
			unitSavedArr[index] = ""
		cleanSaveDice(unit)
	else:
		var actionData := GameManager.fetchData("Actions/" + action + "/Dice")
		if(actionData[0] is Array):
			for i in Array(actionData[0]).size():
				arr.append(action + "/" + str(i))
	return arr

func executeClash(u1: String, u2: String, d1: String, d2: String) -> int:
	var d1Data := getDiceData(d1)
	var d2Data := getDiceData(d2)
	var d1Roll := rollDie(u1, d1Data) if(!d1Data.is_empty()) else 0
	var d2Roll := rollDie(u2, d2Data) if(!d2Data.is_empty()) else 0
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
	
	if(canStore(atkDice) && defRoll == 0): return -1 # Defense/Counter Recycle
	if(isOffense(atkDice)): # Offense win
		var res = getResistance(defUnit, dmgType(atkDice))
		var dmg := atkRoll
		if(dmgType(defDice) == "Block"): # Offense beats Block
			dmg -= defRoll
		EventBus.emit_signal("dmgConsole", ["", defUnit, str(max(0, dmg + res[0])), str(max(0, dmg + res[1]))])
	elif(dmgType(atkDice) == "Block"): # Block win
		EventBus.emit_signal("dmgConsole", ["", defUnit, "0", str(max(0, atkRoll - defRoll))])
	elif(!isOffense(defDice)): # Evade beats Evade/Block
		EventBus.emit_signal("dmgConsole", ["", atkUnit, "0", str(min(0, -atkRoll))])
	if(!(isOffense(atkDice) || isOffense(defDice))): return 0
	return recycleDie(d1Data, d1Result) * 2 + recycleDie(d2Data, d2Result)

func rollDie(_unit: String, die: Dictionary) -> int:
	return max(1, roll(DataTree.fetchData(die, "Dice")[0], DataTree.fetchData(die, "Base")[0]))

func getDiceData(die: String) -> Dictionary:
	var dieParse := die.split("/")
	if(dieParse.size() != 2): return {}
	var dieData = GameManager.fetchData("Actions/" + dieParse[0] + "/Dice/" + dieParse[1])
	if(DataTree.fetchFail(dieData)): return {}
	return dieData[0] if(dieData[0] is Dictionary) else {}

func recycleDie(die: Dictionary, result: int) -> int:
	var type = DataTree.fetchData(die, "Type")[0]
	if(!(type is String)): return 0
	if(!(type.contains("Evade") || type.contains("Counter"))): return 0
	if(result > 1): return 0
	return 1

func cleanSaveDice(unit: String) -> bool:
	if(!GameManager.unitList.has(unit)): return false
	var wasChanged := false
	var unitDice = GameManager.unitList[unit].savedDice
	while(unitDice.has("")):
		wasChanged = true
		unitDice.erase("")
	return wasChanged

func isOffense(die: Dictionary) -> bool:
	var type = getDieType(die)
	if(type.is_empty()): return false
	return !(type.contains("Block") || type.contains("Evade"))

func canStore(die: Dictionary) -> bool:
	var type = getDieType(die)
	if(type.is_empty()): return false
	return !isOffense(die) || type.contains("Counter")

func dmgType(die: Dictionary) -> String:
	var type = getDieType(die)
	if(type.is_empty()): return ""
	return (type.split("Offense")[0]).split("Counter")[0]

func getDieType(die: Dictionary) -> String:
	var type = DataTree.fetchData(die, "Type")[0]
	if(!(type is String)): return ""
	return type

func getResistance(unit: String, type: String) -> Array[int]:
	if(!GameManager.unitList.has(unit)): return [0, 0]
	var unitData := GameManager.unitList[unit].dataSet
	var dmgPath = "Attributes/" + type + "Damage"
	var stgPath = "Attributes/" + type + "Stagger"
	var dmgRes = simpleCollapse(DataTree.fetchData(unitData, dmgPath))
	var stgRes = simpleCollapse(DataTree.fetchData(unitData, stgPath))
	return [dmgRes, stgRes]

func simpleCollapse(fetchData) -> int:
	var data = fetchData[0]
	if(data is int || data is float): return data
	if(data is String): return 0
	var sum := 0
	if(data is Array || data is Dictionary):
		for v in data:
			if(data is int || data is float): sum += data[v]
	return sum

func runGameStat() -> void:
	GameManager.unitList.clear()
	var gameStat = GameManager.fetchData("gamestat")[0]
	GameManager.scene = DataTree.fetchData(gameStat, "Scene")[0]
	GameManager.consoleLog = DataTree.fetchData(gameStat, "Console")[0]
	var unitKeys = Dictionary(DataTree.fetchData(gameStat, "Units")[0]).keys()
	for k in unitKeys:
		var unitName = DataTree.fetchData(gameStat, "Units/" + k + "/Unit")[0]
		addUnit(k, GameManager.fetchData("Units/" + unitName)[0])
	GameManager.pushConsole()
