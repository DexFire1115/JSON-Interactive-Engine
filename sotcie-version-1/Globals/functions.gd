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
		args[i] = await isNestedArg(args[i])
	#print("  ", method, " : ", args.map(func(element): return str(element).split("\n")[0]))
	if(fileTree.dget("Functions", {}).keys().has(method + ".json")):
		return await jFunc(method, args)
	elif(has_method(method)):
		return await callv(method, args)
	else: return null

func isNestedArg(arg) -> Variant:
	#print("    is nested : ", str(arg).split("\n")[0])
	if(arg is Dictionary && Dictionary(arg).size() == 1):
		var key = arg.keys()[0]
		var val = arg[key]
		if((key is String && val is Array)):
			return await isNestedArg(await callj(key, val))
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
	return await sequence(method, funcData["Sequence"], argPairs)

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

func dieCall(method: String, ...args: Array) -> Variant:
	var die = getVar("DieData")
	if(die == null): return null
	return die.callv(method, args)

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
	#print(stackName, " > ", calls.map(func(element): return element.keys()[0]))
	stack.push_back(stackName)
	for arg in args:
		setVar(arg, args[arg])
	var val
	#print(references)
	for method in calls:
		if(method is String && method == "return"): break
		val = await isNestedArg(method)
		if(val is String && val == "return"): break
	clearScope()
	stack.pop_back()
	return val

func ifelse(query: bool, trueCase: Array, falseCase := []):
	var val
	if(query):
		for c in trueCase.duplicate_deep():
			val = await isNestedArg(c)
	else:
		for c in falseCase.duplicate_deep():
			val = await isNestedArg(c)
	return val

func loop(arr: Array, commands: Array):
	var val
	for a in arr:
		for c in commands.duplicate_deep():
			val = await isNestedArg(c)
	return val

func whileLoop(query: bool, commands: Array):
	var val
	while(query):
		for c in commands.duplicate_deep():
			val = await isNestedArg(c)
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

func andBool(b1: bool, b2: bool) -> bool:
	return b1 && b2

func orBool(b1: bool, b2: bool) -> bool:
	return b1 || b2

func min(v1: int, v2: int) -> int:
	return min(v1, v2)

func minSet(...args: Array) -> Variant:
	if(args.is_empty()): return null
	var minV = args[0]
	var index = 1
	while(index < args.size()):
		minV = min(args[index - 1], args[index])
		index += 1
	return minV
	
func max(v1: int, v2: int) -> int:
	return max(v1, v2)

func maxSet(...args: Array) -> Variant:
	if(args.is_empty()): return null
	var maxV = args[0]
	var index = 1
	while(index < args.size()):
		maxV = max(args[index - 1], args[index])
		index += 1
	return maxV

func joinArr(arr1: Array, arr2: Array) -> Array:
	var arrSum := arr1.duplicate()
	arrSum.append_array(arr2)
	return arrSum

func getUnit(unit := "") -> String:
	return getSingleTarget(unit)

func getUnitData(unit := "") -> DataTree:
	unit = getSingleTarget(unit)
	var unitVar: Unit = unitList.get(unit)
	if(unitVar == null): return null
	return unitVar.dataSet

func getUnitProp(unit := "", prop := "") -> Variant:
	unit = getSingleTarget(unit)
	var unitVar: Unit = unitList.get(unit)
	if(unitVar == null): return null
	return unitVar.get(prop)

func setUnitProp(unit: String, prop: String, val: Variant):
	var unitVar: Unit = unitList.get(unit)
	if(unitVar == null): return null
	unitVar.set(prop, val)

func getSingleTarget(target := "") -> String:
	if(target.is_empty()): target = getVar("Target", "")
	if(target == "@Target"): target = getVar("Target", "")
	if(target == "@Self"): target = getVar("Self", "")
	return target

func getSelf(target := "@Self") -> String:
	if(target.is_empty()): target = getSingleTarget()
	return target

func consoleCommand(command: String, ...args: Array):
	args.push_front(command)
	EventBus.callv("emit_signal", args)

func dealDamage(amt: int, target := "", source := "") -> Array:
	target = getSingleTarget(target)
	if(target.is_empty()): return [-1, -1, -1, -1, ""]
	return await dealCombinedDamage([amt, 0, source], "", target)

func dealStagger(amt: int, target := "", source := "") -> Array:
	target = getSingleTarget(target)
	if(target.is_empty()): return [-1, -1, -1, -1, ""]
	return await dealCombinedDamage([0, amt, source], "", target)

func dealMixed(hdmg: int, sdmg: int, target := "", source := "") -> Array:
	target = getSingleTarget(target)
	if(target.is_empty()): return [-1, -1, -1, -1, ""]
	return await dealCombinedDamage([hdmg, sdmg, source], "", target)

func dealCombinedDamage(dmgArr: Array, caster := "", target := "") -> Array:
	var dataArr := [-1, -1, -1, -1, ""]
	caster = getSelf(caster)
	target = getSingleTarget(target)
	if(target.is_empty()): return dataArr
	if(!unitList.has(target)): return dataArr
	var unitdata := getUnitData(target)
	if(unitList.has(caster)): await readDieTag("ConfirmDamage", caster, {"dmgArr": dmgArr})
	await readDieTag("ValidateDamage", target, {"dmgArr": dmgArr})
	if(dmgArr.size() > 3): # Heal/Dmg Clamp
		dmgArr[0] = clampDamage(dmgArr[0], dmgArr[3])
		dmgArr[1] = clampDamage(dmgArr[1], dmgArr[4] if(dmgArr.size() > 4)else dmgArr[3])
	dataArr[0] = unitdata.safeGet("Attributes/CurrentHealth", -1)
	dataArr[1] = unitdata.safeGet("Attributes/CurrentStagger", -1)
	dataArr[2] = min(max(0, dataArr[0] - dmgArr[0]), unitdata.safeGet("Attributes/MaxHealth", -1))
	dataArr[3] = min(max(0, dataArr[1] - dmgArr[1]), unitdata.safeGet("Attributes/MaxStagger", -1))
	dataArr[4] = dmgArr[2]
	unitdata.dset("Attributes/CurrentHealth", dataArr[2])
	unitdata.dset("Attributes/CurrentStagger", dataArr[3])
	consoleCommand("dmgPrint", target, dataArr)
	if(dataArr[0] > 0 && dataArr[2] == 0): statusInflict("Killed", 1, target)
	if(dataArr[1] > 0 && dataArr[3] == 0): statusInflict("Staggered", 1, target)
	if(unitList.has(caster)): await readDieTag("DamageResponse", caster, {"dmgArr": dmgArr})
	return dataArr

func clampDamage(dmg, flag: bool):
	if(flag): return min(0, dmg)
	else: return max(0, dmg)

func changeLight(amt := 0, target := "@Self") -> Array:
	var dataArr := [-1, -1, -1]
	target = getSingleTarget(target)
	if(target.is_empty()): return dataArr
	var unitdata := getUnitData(target)
	if(unitdata.isEmpty()): return dataArr
	dataArr[0] = unitdata.dget("Attributes/CurrentLight", "")
	dataArr[1] = unitdata.dget("Attributes/MaxLight", "")
	dataArr[2] = min(max(0, dataArr[0] + amt), dataArr[1])
	unitdata.dset("Attributes/CurrentLight", dataArr[2])
	consoleCommand("lightPrint", target, dataArr)
	return dataArr

func statusInflict(status: String, amt := 1, target := "", nextScene := false):
	setStatus(status, getStatus(status, 0, target, nextScene) + amt, target, nextScene)
	
func setStatus(status: String, amt := 1, target := "", nextScene := false, apply := true):
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
	statusData.dset(stackName, amt)
	
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
	
	await readUnitTag("StatusClamp", target, {}, [{"clampStatus": [statusData]}])
	if(apply):
		await readUnitTag("Applied", target)
		await readUnitTag("Applied-" + status, target)
	if(statusData.dget("Stack", 0) <= 0 && statusData.dget("NextStack", 0) <= 0): 
		removeStatus(status, target)

func removeStatus(status: String, target := ""):
	target = getSingleTarget(target)
	if(target.is_empty()): return
	var targetData := getUnitData(target)
	if(targetData == null): return
	await readUnitTag("Removed", target)
	await readUnitTag("Removed-" + status, target)
	var statusConditions: Array = targetData.safeGet("Statuses/" + status + "/Conditions", TYPE_ARRAY)
	var unitConditions := DataTree.new(targetData.safeGet("Conditions", TYPE_DICTIONARY))
	for c in statusConditions:
		var conditionArr: Array = unitConditions.safeGet(c, TYPE_ARRAY)
		conditionArr.erase(status)
		if(conditionArr.is_empty()):
			unitConditions.erase(c)
	targetData.erase("Statuses/" + status)

func getStatus(status: String, default := 0, target := "", nextScene := false) -> int:
	target = getSingleTarget(target)
	if(target.is_empty()): return default
	var targetData := getUnitData(target)
	if(targetData == null): return default
	var statusData = DataTree.new(targetData.dget("Statuses/" + status, {}))
	var stackName := "Stack" if(!nextScene) else "NextStack"
	return statusData.dget(stackName, default)

func clampStatus(statusData: DataTree):
	var fileStatus = DataTree.new(fileTree.safeGet(statusData.dget("File", ""), 
		TYPE_DICTIONARY).duplicate_deep())
	statusData.dset("Stack", clamp(
		statusData.dget("Stack", 0), 
		await isNestedArg(fileStatus.dget("MinStack", 0)), 
		await isNestedArg(fileStatus.dget("MaxStack", INF))
	))

func statusClearSelf(status := ""):
	if(status.is_empty()): status = str(getVar("Status", ""))
	setStatus(status, 0, "@Self", false, false)
	await readUnitTag("Removed-" + status, "@Self")

func statusNextStack():
	var statusName := str(getVar("Status", ""))
	if(statusName.is_empty()): return
	var statusData := DataTree.new(getUnitData("@Self").dget("Statuses/" + getVar("Status"), {}))
	if(statusData.has("NextStack")):
		statusInflict(statusName, statusData.dget("NextStack", 0), getUnit("@Self"))
		statusData.erase("NextStack")

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

func prompt(query: String):
	EventBus.emit_signal("consoleInput", query)
	var x = EventBus.queryOutput
	return x

func queryYN(query: String) -> bool:
	while(true):
		var result = await prompt(query)
		match(result):
			"Y", "y", "1": return true
			"N", "n", "0": return false
		query = "[b][color=ff6464]ERROR : Invalid Selection[/color][/b]"
	return false

func queryUnit(query: String) -> String:
	while(true):
		var result = await prompt(query)
		if(unitList.has(result)): return result
		if(result == "skip"): return "*INVALID"
		query = "[b][color=ff6464]ERROR : Invalid Selection[/color][/b]"
	return ""

func sceneStart():
	for u in unitList:
		await readUnitTag("SceneEnd", u)
	scene += 1
	GameManager.addPushConsole("[u][b][lb]Scene " + str(scene) + "][/b][/u]")
	for u in unitList:
		await readUnitTag("SceneStart", u)
	rollSpeed()
	regenLight()
	clearSaveDice()
	for u in unitList:
		await readUnitTag("SceneStartPost", u)
		await readUnitTag("StatusNextStack", u, {}, [{"statusNextStack": []}])

func clearSaveDice():
	for u in unitList:
		var unit = unitList[u]
		unit.savedDice.clear()

func regenLight():
	for u in unitList:
		var unitData := unitList[u].dataSet
		if(await isInactive(unitData)): continue
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
		for i in int(await getSumAttribute(unitData, "SpeedDiceAmt")):
			var val = max(1, roll(
				await getSumAttribute(unitData, "SpeedDiceSize"),
				await getSumAttribute(unitData, "SpeedDiceBase"),
			))
			if(await isInactive(unitData)): usedList.set(u + "D" + str(i), val)
			else: diceList.set(u + "D" + str(i), val)

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

func isInactive(unitData: DataTree) -> bool:
	return await unitData.getComplexSeqn("Attributes/Inactive", "orBool", false)

func executeAWSkill(u1: String, u2: Array, a1: String, a2: Array) -> void:
	if(!unitList.has(u1)): return
	if(u2.size() != a2.size() || u2.size() == 0): return
	for u in u2: if(!unitList.has(u)): return
	var u1id := await createAction(u1, a1)
	var u2id: Array[int] = []
	for i in u2.size(): u2id.append(await createAction(u2[i], a2[i]))
	var u1dice := Array(getAction(u1id, "diceArr", []))
	var u2dice := []
	for id in u2id: u2dice.append(Array(getAction(id, "diceArr", [])))
	var u2oldHealth := []
	var u2oldStagger := []
	var a2Finished := []
	for u in u2:
		u2oldHealth.append(getUnitData(u).safeGet("Attributes/CurrentHealth", -1))
		u2oldStagger.append(getUnitData(u).safeGet("Attributes/CurrentStagger", -1))
		a2Finished.append(false)
	var clashData := {
		"u1oldHealth": getUnitData(u1).safeGet("Attributes/CurrentHealth", -1),
		"u1oldStagger": getUnitData(u1).safeGet("Attributes/CurrentStagger", -1),
		"u2oldHealth": u2oldHealth,
		"u2oldStagger": u2oldStagger,
		"a1Finished?": false,
		"a2Finished?": a2Finished
	}
	setUnitProp(u1, "target", u2[0])
	setUnitProp(u1, "action", u1id)
	await readActionTag("OnUse", u1)
	moveCounterDice(u1id)
	for i in u2.size():
		setUnitProp(u2[i], "target", u1)
		setUnitProp(u2[i], "action", u2id[i])
		await readActionTag("OnUse", u2[i])
		moveCounterDice(u2id[i])
	while(!(u1dice.is_empty() && u2dice.all(isEmpty))):
		if(u1dice.is_empty()): afterSkillAW(u1, u2, clashData)
		var u1Recycle = true
		var d1 := DataTree.new({} if(u1dice.is_empty()) else 
			getDiceData(u1dice.front(), u1id).duplicate_deep())
		setUnitProp(u1, "dieData", d1)
		await readDieTag("BeforeDie", u1)
		for i in u2.size():
			setUnitProp(u1, "target", u2[i])
			if(u2dice[i].is_empty()): afterSkill(u1, u2[i], clashData, false)
			var d2 := DataTree.new({} if(u2dice[i].is_empty()) else 
			getDiceData(u2dice[i].front(), u2id[i]).duplicate_deep())
			setUnitProp(u1, "dieData", d1)
			setUnitProp(u2[i], "dieData", d2)
			await readDieTag("BeforeDie", u2[i])
			var result := await executeClash(
				u1, u2[i], d1, d2)
			if(result == -1):
				if(u2dice[i].is_empty()):
					unitList[u1].savedDice.push_back(u1dice.pop_front())
				else:
					unitList[u2[i]].savedDice.push_back(u2dice[i].pop_front())
				continue
			@warning_ignore("integer_division")
			if((result / 2) % 2 == 0): u1Recycle = false
			if(result % 2 == 0): u2dice[i].pop_front()
		if(!u1Recycle): u1dice.pop_front()

	afterSkillAW(u1, u2, clashData)
	afterSkillAW(u1, u2, clashData)
	setUnitProp(u1, "target", "")
	setUnitProp(u1, "action", -1)
	clearScope(getAction(u1id, "path", ""))
	for i in u2.size():
		setUnitProp(u2[i], "target", "")
		setUnitProp(u2[i], "action", -1)
		clearScope(getAction(u2id[i], "path", ""))

func isEmpty(arr: Array):
	return arr.is_empty()

func afterSkillAW(u1: String, u2: Array, data: Dictionary):
	var subdata := data.duplicate_deep()
	for i in u2.size():
		subdata["u2oldHealth"] = data["u2oldHealth"][i]
		subdata["u2oldStagger"] = data["u2oldStagger"][i]
		subdata["a2Finished?"] = data["a2Finished?"][i]
		afterSkill(u1, u2[i], subdata, true)
		afterSkill(u1, u2[i], subdata, false)

func executeSkills(u1: String, u2: String, a1: String, a2: String) -> void:
	if(!unitList.has(u1)): return
	if(!unitList.has(u2)): return
	var u1id := await createAction(u1, a1)
	var u2id := await createAction(u2, a2)
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
	await readActionTag("Eminence", u1)
	await readActionTag("Eminence", u2)
	await readActionTag("Proactive", u1)
	await readActionTag("Reactive", u2)
	await readActionTag("OnUse", u1)
	await readActionTag("OnUse", u2)
	moveCounterDice(u1id)
	moveCounterDice(u2id)
	while(!(u1dice.is_empty() && u2dice.is_empty())):
		if(u1dice.is_empty()): afterSkill(u1, u2, clashData, true)
		if(u2dice.is_empty()): afterSkill(u1, u2, clashData, false)
		var d1 := DataTree.new({} if(u1dice.is_empty()) else 
			getDiceData(u1dice.front(), u1id).duplicate_deep())
		var d2 := DataTree.new({} if(u2dice.is_empty()) else 
			getDiceData(u2dice.front(), u2id).duplicate_deep())
		setUnitProp(u1, "dieData", d1)
		setUnitProp(u2, "dieData", d2)
		await readDieTag("BeforeDie", u1)
		await readDieTag("BeforeDie", u2)
		var result := await executeClash(
			u1, u2, d1, d2)
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
		if(u2Health == 0 && data["u2oldHealth"] > 0): await readActionTag("OnKill", u1)
		var u2Stagger = getUnitData(u2).safeGet("Attributes/CurrentStagger", -1)
		if(u2Stagger == 0 && data["u2oldStagger"] > 0): await readActionTag("OnStagger", u1)
		await readActionTag("AfterUse", u1)
		for d in getAction(getUnitProp(u1, "action"), "data/Autosave", []):
			unitList[u1].savedDice.push_back(d)
		data["a1Finished?"] = true
	else:
		if(data["a2Finished?"]): return
		var u1Health = getUnitData(u1).safeGet("Attributes/CurrentHealth", -1)
		if(u1Health == 0 && data["u1oldHealth"] > 0): await readActionTag("OnKill", u2)
		var u1Stagger = getUnitData(u1).safeGet("Attributes/CurrentStagger", -1)
		if(u1Stagger == 0 && data["u1oldStagger"] > 0): await readActionTag("OnStagger", u2)
		await readActionTag("AfterUse", u2)
		for d in getAction(getUnitProp(u2, "action"), "data/Autosave", []):
			unitList[u2].savedDice.push_back(d)
		data["a2Finished?"] = true

func createAction(unit: String, action: String) -> int:
	var isIntercept = action.begins_with("*")
	if(isIntercept): action = action.substr(1)
	var diceArr = createDiceArr(unit, action)
	if(diceArr.is_empty()): return -1
	actionID += 1
	var actionTree = DataTree.new()
	var path = "*Action" + str(actionID)
	setVar(path, actionTree)
	actionTree.dset("path", path)
	actionTree.dset("id", actionID)
	actionTree.dset("unit", unit)
	actionTree.dset("name", action)
	actionTree.dset("diceArr", diceArr)
	var dataCopy = Dictionary(fileTree.safeGet("Actions/" + action, 
		TYPE_DICTIONARY)).duplicate_deep()
	actionTree.dset("data", dataCopy)
	if(isIntercept): 
		dataCopy.set("Intercept", true)
		await readActionTag("OnIntercept", unit)
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

func moveCounterDice(aid: int):
	if(aid < 0): return
	var aName = getAction(aid, "name", "")
	if(isSaveDiceArr(aName)): return
	var data := DataTree.new(getAction(aid, "data"))
	var fileDiceArr: Array = data.safeGet("Dice", TYPE_ARRAY)
	var refDiceArr: Array = getAction(aid, "diceArr")
	var index := fileDiceArr.size()
	while(index > 0):
		index -= 1
		if(getDieType(DataTree.new(fileDiceArr[index])).contains("Counter")):
			data.instantiate("Autosave", [])
			fileDiceArr.pop_at(index)
			refDiceArr.pop_at(index)
			Array(data.safeGet("Autosave", TYPE_ARRAY)).append(aName + "/" + str(index))

func isSaveDiceArr(action: String) -> bool:
	var nameArr = action.replace("[lb]","[").split("SaveDice")
	return nameArr.size() == 2 && JSON.parse_string(nameArr[1]) is Array

func executeClash(u1: String, u2: String, d1: DataTree, d2: DataTree) -> int:
	var d1Data := d1.copy()
	var d2Data := d2.copy()
	setUnitProp(u1, "dieData", d1Data)
	setUnitProp(u2, "dieData", d2Data)
	var d1Roll := 0
	var d2Roll := 0
	if(!d1Data.dataset.is_empty()): 
		await readDieTag("Check", u1)
		d1Roll = await rollDie(u1, d1Data)
	if(!d2Data.dataset.is_empty()): 
		await readDieTag("Check", u2)
		d2Roll = await rollDie(u2, d2Data)
	EventBus.emit_signal("clashConsole", getDieType(d1Data), d1Roll, getDieType(d2Data), d2Roll)
	if(d1Roll - d2Roll == 0): # Tie or double unopposed
		if(dmgType(d1Data) == "Evade" && isOffense(d2Data)):
			await readDieTag("Evade", u1)
		if(dmgType(d2Data) == "Evade" && isOffense(d1Data)):
			await readDieTag("Evade", u2)
		return 0 
	var d1Result: int = 0 if(d1Roll * d2Roll == 0) else (sign(d2Roll - d1Roll) + 2)
	var d2Result: int = 0 if(d1Roll * d2Roll == 0) else (sign(d1Roll - d2Roll) + 2)
	
	var prioritySwitch := (d1Result <= d2Result) && d1Roll != 0
	var atkUnit := u1 if(prioritySwitch) else u2
	var defUnit := u2 if(prioritySwitch) else u1
	var atkRoll := d1Roll if(prioritySwitch) else d2Roll
	var defRoll := d2Roll if(prioritySwitch) else d1Roll
	var atkDice := d1Data if(prioritySwitch) else d2Data
	var defDice := d2Data if(prioritySwitch) else d1Data
	var atkType := dmgType(atkDice)
	
	if((d1Result if(prioritySwitch) else d2Result) == CLASH_WIN):
		if(!(atkType == "Evade" && isOffense(defDice))):
			await readDieTag("ClashWin", atkUnit)
		await readDieTag("ClashLose", defUnit)
	
	if(canStore(atkDice) && defRoll == 0): return -1 # Defense/Counter Recycle
	if(isOffense(atkDice)): # Offense win
		var res = await getResistance(defUnit, atkType)
		var dmg := atkRoll

		if(dmgType(defDice) == "Block"): # Offense beats Block
			dmg -= defRoll
		var dmgArr := [dmg + res[0], dmg + res[1], atkType]
		dealCombinedDamage(dmgArr, atkUnit, defUnit)
		await readDieTag("Hit", atkUnit)
		var isCrit: bool = (atkRoll - atkDice.dget("Base", 0)) == atkDice.dget("Dice", 0)
		if(isCrit):
			await readDieTag("Crit", atkUnit)
		await readUnitTag("HitReceived", defUnit, {"isCrit": isCrit})

	elif(atkType == "Block"): # Block win
		var dmgArr := [0, atkRoll - defRoll, atkType]
		dealCombinedDamage(dmgArr, atkUnit, defUnit)
	
	else:
		if(isOffense(defDice)): # Evade evades Offense
			await readDieTag("OnEvade", atkUnit)
		else: # Evade beats Evade/Block
			var dmgArr := [0, -atkRoll, atkType, true]
			dealCombinedDamage(dmgArr, atkUnit, defUnit)
	
	await readUnitTag("UsedDie", u1)
	await readUnitTag("UsedDie", u2)
	if(isOffense(d1Data)): await readUnitTag("UsedOffense", u1)
	else: await readUnitTag("UsedDefense", u1)
	if(isOffense(d2Data)): await readUnitTag("UsedOffense", u2)
	else: await readUnitTag("UsedDefense", u2)
	
	if(!(isOffense(atkDice) || isOffense(defDice))): return 0
	return recycleDie(d1Data, d1Result) * 2 + recycleDie(d2Data, d2Result)

func readUnitTag(tag: String, unit: String, metadata := {}, defaultSeq := []):
	var unitData = getUnitData(unit)
	if(unitData == null): return
	metadata.merge(composeConditionMetaData(getUnit(unit)))
	var conditionStatuses: Array = unitData.safeGet("Conditions/" + tag, TYPE_ARRAY)
	if(!defaultSeq.is_empty()): 
		conditionStatuses = unitData.safeGet("Statuses", TYPE_DICTIONARY).keys()
	for status in conditionStatuses:
		var path = unitData.safeGet("Statuses/" + status + "/File", TYPE_STRING)
		var cond := DataTree.new(fileTree.safeGet(path + "/Conditions", TYPE_DICTIONARY))
		metadata.merge({"Status": status}, true)
		await executeCondition(tag, cond, metadata, defaultSeq)

func readActionTag(tag: String, unit: String, metadata := {}, defaultSeq := []):
	metadata.merge(composeConditionMetaData(getUnit(unit)))
	if(metadata.is_empty()): return
	var dataDict = getAction(metadata["Action"], "data")
	if(dataDict != null):
		await executeCondition(tag, DataTree.new(dataDict), metadata, defaultSeq)
	await readUnitTag(tag, unit, metadata, defaultSeq)

func readDieTag(tag: String, unit: String, metadata := {}, defaultSeq := []):
	metadata.merge(composeConditionMetaData(getUnit(unit)))
	if(metadata.is_empty()): return
	var dieData = metadata["DieData"]
	if(dieData != null):
		await executeCondition(tag, dieData, metadata, defaultSeq)
	await readActionTag(tag, unit, metadata, defaultSeq)

func executeCondition(tag: String, source: DataTree, metadata := {}, defaultSeq := []):
	var tagSequence = source.copy().safeGet(tag, TYPE_ARRAY)
	if(tagSequence.is_empty()): tagSequence = defaultSeq
	return await sequence(tag, tagSequence, metadata)

func composeConditionMetaData(unit: String) -> Dictionary:
	if(!unitList.has(unit)): return {}
	return {
		"Self": unit,
		"Target": getUnitProp(unit, "target"),
		"Action": getUnitProp(unit, "action"),
		"@Action": getAction(getUnitProp(unit, "action"), "path", "*INVALID"),
		"DieData": getUnitProp(unit, "dieData"),
	}

func rollDie(unit: String, die: DataTree) -> int:
	var dieTree = die
	var minMax = dieTree.dget("FixedMax", 0) - dieTree.dget("FixedMin", 0)
	var size = dieTree.dget("Dice", 0)
	var base = dieTree.dget("Base", 0)
	if(minMax > 0): return max(1, size + base)
	if(minMax < 0): return max(1, sign(size) + base)
	var advDis = dieTree.dget("Advantage", 0) - dieTree.dget("Disadvantage", 0)
	if(advDis > 0): return max(1, await rollDieResult(unit, die, "rollAdv", [size, base], "Adv"))
	if(advDis < 0): return max(1, await rollDieResult(unit, die, "rollDis", [size, base], "Dis"))
	return max(1, await rollDieResult(unit, die, "roll", [size, base]))

func rollDieResult(unit: String, die: DataTree, method: String, args: Array, type := "") -> int:
	die.dset("tempResult", await callj(method, args))
	await readDieTag("RolledDie", unit, {"RollType": type})
	return die.dget("tempResult", 0)

func getDiceData(die: String, id := -1) -> Dictionary:
	var dieParse := die.split("/")
	if(dieParse.size() != 2): return {}
	if(!isSaveDiceArr(getAction(id, "name"))): return getAction(id, "data/Dice/" + dieParse[1], {})
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
	var dmgPath = type + "Damage"
	var stgPath = type + "Stagger"
	var dmgRes = await getSumAttribute(unitData, dmgPath)
	var stgRes = await getSumAttribute(unitData, stgPath)
	return [dmgRes, stgRes]

func getSumAttribute(unitData: DataTree, attribute: String) -> int:
	return await unitData.getComplexSeqn("Attributes/" + attribute, "add", 0)

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
