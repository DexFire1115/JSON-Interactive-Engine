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
	#print("  ", method, " : ", args.map(func(element): return str(element).split("\n")[0]))
	for i in args.size():
		args[i] = await isNestedArg(args[i])
	#print("  ", method, " : ", args.map(func(element): return str(element).split("\n")[0]))
	if(fileTree.dget("Functions", {}).keys().has(method + ".json")):
		return await jFunc(method, args)
	elif(has_method(method)):
		return await callv(method, args)
	else: return GlobalScopeRef.globalScopeCall(method, args)

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

func varCall(variant, method: String, ...args: Array) -> Variant:
	#print(variant, ".", method, args, " -> ", result)
	return Callable.create(variant, method).callv(args)

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
	#print("parsing -> ", stackName, "/", varName)
	if(stackName.is_empty()): return varName
	return stackName + "/" + varName

func clearScope(stackName := ""):
	if(stackName.is_empty()): stackName = "/".join(stack)
	if(stackName.begins_with("*")): stackName = stackName.substr(1)
	for k in references.keys():
		if(k.contains(stackName)):
			references.erase(k)

func sequence(stackName: String, calls := [], args := {}):
	#print("\n", stackName, " > ", calls.map(func(element): 
	#	return element if(!element is Dictionary)else element.keys()[0]))
	stack.push_back(stackName)
	for arg in args:
		setVar(arg, args[arg])
	var retval = ""
	var val = ""
	#print(references.keys())
	for method in calls:
		val = await isNestedArg(method)
		if(val is String && val == "return"): break
		retval = val
		if(retval is Dictionary && retval.has("*") && retval["*"] == null):
			if(retval["retStack"] == stackName): retval = retval["retVal"]
			break
	clearScope()
	stack.pop_back()
	return retval

func ifelse(query: bool, trueCase: Array, falseCase := []):
	var retval = ""
	var val = ""
	if(query):
		for c in trueCase.duplicate_deep():
			val = await isNestedArg(c)
			if(val is String && val == "break"): break
			if(val is String && val == "return"): val = returnBlock(retval, stack.back())
			retval = val
			if(retval is Dictionary && val.has("*") && val["*"] == null): break
	else:
		for c in falseCase.duplicate_deep():
			val = await isNestedArg(c)
			if(val is String && val == "break"): break
			if(val is String && val == "return"): val = returnBlock(retval, stack.back())
			retval = val
			if(retval is Dictionary && val.has("*") && val["*"] == null): break
	return retval

func loop(arr: Array, commands: Array, varName := ""):
	var retval = ""
	var val = ""
	var conBool := false
	for a in arr:
		conBool = false
		if(!varName.is_empty()): setVar(varName, a)
		for c in commands.duplicate_deep():
			val = await isNestedArg(c)
			if(val is String && val == "break"):
				return retval
			if(val is String && val == "continue"):
				conBool = true
				break
			if(val is String && val == "return"): val = returnBlock(retval, stack.back())
			retval = val
			if(retval is Dictionary && val.has("*") && val["*"] == null):
				return retval
		if(conBool): continue
	return retval

func whileLoop(query: Array, commands: Array):
	var retval = ""
	var val = ""
	var conBool := false
	while(query[0]):
		for c in commands.duplicate_deep():
			val = await isNestedArg(c)
			if(val is String && val == "break"):
				return retval
			if(val is String && val == "continue"):
				conBool = true
				break
			if(val is String && val == "return"): val = returnBlock(retval, stack.back())
			retval = val
			if(retval is Dictionary && val.has("*") && val["*"] == null):
				return retval
		if(conBool): continue
	return retval

func returnBlock(val, stackName):
	return {
		"*": null,
		"retVal": val,
		"retStack": stackName
	}

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

func safeDict(input: Array, returnIndex := 0) -> Dictionary:
	for d in input:
		if(d.size() == 1 && d.keys()[0] is String):
			d.set("_", null)
	if(abs(returnIndex) >= input.size()): return {}
	if(returnIndex < 0): return input[input.size() - 1 - returnIndex]
	return input[returnIndex]

func joinArr(arr1: Array, arr2: Array) -> Array:
	var arrSum := arr1.duplicate()
	arrSum.append_array(arr2)
	return arrSum

func passArr(...arr: Array) -> Array:
	return arr

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

func getSelf(target := "") -> String:
	if(target.is_empty()): target = getSingleTarget("@Self")
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
	consoleCommand("dmgDisplay", target, dataArr)
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
	consoleCommand("lightDisplay", target, dataArr)
	return dataArr

func changeEmotion(amt := 0, target := "@Self", display := true) -> Array:
	var dataArr := [-1, -1]
	target = getSingleTarget(target)
	if(target.is_empty()): return dataArr
	var unitdata := getUnitData(target)
	if(unitdata.isEmpty()): return dataArr
	dataArr[0] = unitdata.safeGet("Attributes/EmotionPoints", -1)
	dataArr[1] = max(0, dataArr[0] + amt)
	unitdata.dset("Attributes/EmotionPoints", dataArr[1])
	if(display): consoleCommand("emotionDisplay", target, dataArr)
	return dataArr

func statusInflict(status: String, amt := 1, target := "", nextScene := false, caster := ""):
	setStatus(status, getStatus(status, 0, target, nextScene) + amt, target, nextScene, true, caster)
	
func setStatus(status: String, amt := 1, target := "", nextScene := false, apply := true, caster := ""):
	target = getSingleTarget(target)
	if(target.is_empty()): return
	var targetData := getUnitData(target)
	if(targetData == null): return
	caster = getSelf(caster)
	if(nextScene == false && apply == true):
		var statusArr = [status, amt]
		if(unitList.has(caster)):
			await readDieTag("ConfirmStatus", caster, 
				{"statusArr": statusArr, "Target": target})
			await readDieTag("ConfirmStatus-" + statusArr[0], caster, 
				{"statusArr": statusArr, "Target": target})
		await readDieTag("ValidateStatus", target, {"statusArr": statusArr})
		await readDieTag("ValidateStatus-" + statusArr[0], target, {"statusArr": statusArr})
		status = statusArr[0]
		amt = statusArr[1]
	
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
		if(unitList.has(caster)):
			await readDieTag("Caused", caster, {"Target": target})
			await readDieTag("Caused-" + status, caster, {"Target": target})
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

func queryInt(query: String, choices: Array, default := -1) -> int:
	var choicesCopy = choices.duplicate_deep()
	for i in choicesCopy.size():
		choicesCopy[i] = int(await isNestedArg(choicesCopy[i]))
	while(true):
		var result = await prompt(query)
		if(str(result).is_valid_int() && choicesCopy.has(int(result))): return int(result)
		if(result == "skip"): return default
		query = "[b][color=ff6464]ERROR : Invalid Selection[/color][/b]"
	return default

func sceneStart():
	#print("< - - - SCENE - - - >")
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

func nextTurn(dice := "", isProactive := true):
	var isSavedDice := diceList.is_empty()
	if(dice.is_empty()): dice = getNextSpeedDie(!isSavedDice)
	if(dice.is_empty()): return "_"
	var unitName := getUnitFromDice(dice)
	if(!unitList.has(unitName)): return "_"
	var unitData := unitList[unitName].dataSet
	var actionList := []
	if(!dice.contains("*")):
		actionList = Array(unitData.safeGet("Actions", TYPE_ARRAY)).duplicate_deep()
	var optionInts := []
	
	if(isProactive):
		actionList.push_front(
			"*[b][color=ff6480]Void Speed Die[/color][/b]" if(isSavedDice)
			else "*[b][color=6480ff]Hold Speed Die[/color][/b]"
		)
		optionInts = [0]
	else:
		actionList.push_front("*[b][color=64ffff]Deploy Saved Dice[/color][/b]")
		actionList.push_front("*[b][color=ff6464]No Contest[/color][/b]")
		optionInts = [0,1]
	for i in range(optionInts.size(),actionList.size()):
		if(isUsable(unitData, DataTree.new(fileTree.safeGet("Actions/" + actionList[i], 
			TYPE_DICTIONARY)))): optionInts.append(i)
	EventBus.emit_signal("skillListDisplay", unitName, actionList)
	var answer := await queryInt("", optionInts, 0)
	
	if(answer == 0):
		if(isProactive):
			if(isSavedDice): removeSpeedDice(dice)
			else: saveSpeedDice(dice)
		return "_"
	
	if(!isProactive && answer == 1):
		var savediceList := Array(unitList[unitName].savedDice.duplicate())
		savediceList.push_front("*[b][color=64ff64]Deploy Dice[/color][/b]")
		optionInts = range(savediceList.size())
		var selectedInts := []
		answer = -1
		while(answer != 0):
			addLog("[u][b]Select Saved Dice:[/b][/u]")
			optionInts = range(savediceList.size())
			EventBus.emit_signal("savediceListDisplay", unitName, savediceList, optionInts)
			answer = await queryInt("", optionInts, 0)
			if(answer == 0): break
			selectedInts.append(answer - 1)
			savediceList.remove_at(answer)
			if(savediceList.size() == 1): break
		return "SaveDice" + str(selectedInts)
	
	removeSpeedDice(dice)
	var actionChoice: String = actionList[answer]
	var actionData := DataTree.new(fileTree.safeGet("Actions/" + actionChoice, TYPE_DICTIONARY))
	changeLight(-actionData.dget("Cost") , unitName)
	if(actionData.has("Emotion")): changeEmotion(-actionData.dget("Emotion") , unitName)
	if(!isProactive): return actionChoice
	
	var targetList = unitList.keys()
	var weight: int = actionData.dget("AttackWeight", 1)
	var skillTargets := {}
	for i in range(weight):
		EventBus.emit_signal("targetListDisplay", targetList)
		answer = await queryInt("", range(targetList.size()), 0)
		skillTargets.set(targetList[answer], "")
	for u in unitList.keys():
		if(skillTargets.keys().has(u)): continue
		var interceptArr := await interceptCheck(u, unitName, skillTargets.keys())
		if(interceptArr[0]):
			skillTargets.erase(interceptArr[1])
			skillTargets.set(u, "")
	for u in skillTargets:
		var targetDie := getNextUnitSpeedDie(u)
		if(targetDie.is_empty()): targetDie = getNextUnitSpeedDie(u, false)
		if(targetDie.is_empty()): targetDie = u + "D*"
		skillTargets[u] = await nextTurn(targetDie, false)
	await executeAWSkill(unitName, skillTargets.keys(), actionChoice, skillTargets.values())

func interceptCheck(unit: String, proactive: String, reactives: Array) -> Array:
	var choiceDict := {"[b][color=ff6464]No Contest[/color][/b]": "No"}
	if(!getNextUnitSpeedDie(unit, false).is_empty()):
		choiceDict.set("[b][color=64aaff]Use Saved Die[/color][/b]", "SavedDie")
	await readUnitTag("InterceptCheck", unit, {
		"Self": unit, 
		"Target": proactive,
		"choiceDict": choiceDict
	})
	addLog("[u][b]Select Intercept Option:[/b][/u]")
	var optionInts := range(choiceDict.size())
	for o in optionInts:
		var text := ""
		text += "[b][color=cceeff] " + str(o) + " | [/color][/b]"
		text += choiceDict.keys()[o]
		addLog(text)
	var answer = choiceDict.values()[await queryInt("", optionInts, 0)]
	
	var interceptUnit := ""
	if(reactives.size() == 1): interceptUnit = reactives[0]
	else:
		addLog("[u][b]Intercept For Whom?:[/b][/u]")
		EventBus.emit_signal("targetListDisplay", reactives)
		interceptUnit = reactives[await queryInt("", range(reactives.size()), 0)]
	
	var answerArr := [answer, choiceDict.values(), interceptUnit, reactives]
	await readUnitTag("ConfirmIntercept", unit, {
		"Self": unit, 
		"Target": proactive,
		"answerArr": answerArr
	})
	await readUnitTag("ValidateIntercept", unit, {
		"Self": proactive, 
		"Target": unit,
		"answerArr": answerArr
	})
	return [answerArr[0] != "No", answerArr[2]]

func getNextUnitSpeedDie(unit: String, searchUnused := true) -> String:
	unit = getSingleTarget(unit)
	if(!unitList.has(unit)): return ""
	
	var dict := diceList if(searchUnused) else saveList
	var unitKeys := dict.keys().filter(func(key: String): return key.begins_with(unit))
	var unitDict := {}
	for k in unitKeys: unitDict.set(k, dict[k])
	var val = highestInDict(unitDict)
	return(val if(val != null) else "")

func getNextSpeedDie(searchUnused := true) -> String:
	var dict = diceList if(searchUnused) else saveList
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
	var isHeld := saveList.has(die)
	if(!(diceList.has(die) || isHeld)): return 0
	if(isHeld): 
		usedList.set(die, saveList[die])
		saveList.erase(die)
	else:
		usedList.set(die, diceList[die])
		diceList.erase(die)
	var unitName := getUnitFromDice(die)
	await readUnitTag("RemDie", unitName, {"SpeedDie": die, "wasHeld": isHeld})
	unitList[unitName].speedDie = [die, isHeld]
	return 2 if(isHeld)else 1 # Die not Found

# Saves next die if unspecified
func saveSpeedDice(die := "") -> int:
	if(die.is_empty()): die = getNextSpeedDie(!diceList.is_empty())
	if(die.is_empty()): return -1 # No Dice to Save
	if(saveList.has(die)): return 1 # Die already saved
	if(!diceList.has(die)): return 0 # Die not Found
	await readUnitTag("HoldDie", getUnitFromDice(die), {"SpeedDie": die})
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

func getDieSpeed(dice: String) -> int:
	if(dice.is_empty()): return 0
	if(diceList.has(dice)): return diceList[dice]
	if(saveList.has(dice)): return saveList[dice]
	if(usedList.has(dice)): return usedList[dice]
	return 0

func getUnitFromDice(dice: String) -> String:
	return dice.rsplit("D", true, 1)[0]

func isInactive(unitData: DataTree) -> bool:
	return await unitData.getComplexSeqn("Attributes/Inactive", "orBool", false)

func isUsable(unitData: DataTree, actionData: DataTree) -> bool:
	if(unitData.dget("Attributes/CurrentLight", 0) < actionData.dget("Cost", 0)):
		return false
	if(unitData.dget("Attributes/EmotionPoints", 0) < actionData.dget("Emotion", 0)):
		return false
	if(actionData.has("Limit") && actionData.dget("Uses", 0) >= actionData.dget("Limit", 0)): 
		return false
	return true

func isTargettable(_unitData: DataTree, _targetData: DataTree) -> bool:
	return true

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
	var u2oldEmotion := []
	var a2Finished := []
	for u in u2:
		u2oldHealth.append(getUnitData(u).safeGet("Attributes/CurrentHealth", -1))
		u2oldStagger.append(getUnitData(u).safeGet("Attributes/CurrentStagger", -1))
		u2oldEmotion.append(getUnitData(u).safeGet("Attributes/EmotionPoints", -1))
		a2Finished.append(false)
	var clashData := {
		"u1oldHealth": getUnitData(u1).safeGet("Attributes/CurrentHealth", -1),
		"u1oldStagger": getUnitData(u1).safeGet("Attributes/CurrentStagger", -1),
		"u1oldEmotion": getUnitData(u1).safeGet("Attributes/EmotionPoints", -1),
		"u2oldHealth": u2oldHealth,
		"u2oldStagger": u2oldStagger,
		"u2oldEmotion": u2oldEmotion,
		"a1Finished?": false,
		"a2Finished?": a2Finished
	}
	setUnitProp(u1, "target", u2[0])
	setUnitProp(u1, "action", u1id)
	await readActionTag("OnUse", u1)
	if(getAction(u1id, "data/Uses", 0) >= getAction(u1id, "data/Limit", 0) 
	&& getAction(u1id, "data/Limit", 0) > 0):
		await readActionTag("Exhaust", u1)
	moveCounterDice(u1id)
	for i in u2.size():
		setUnitProp(u2[i], "target", u1)
		setUnitProp(u2[i], "action", u2id[i])
		await readActionTag("OnUse", u2[i])
		if(getAction(u2id[i], "data/Uses", 0) >= getAction(u2id[i], "data/Limit", 0) 
		&& getAction(u2id[i], "data/Limit", 0) > 0):
			await readActionTag("Exhaust", u2[i])
		moveCounterDice(u2id[i])
	while(!(u1dice.is_empty() && u2dice.all(isEmpty))):
		if(u1dice.is_empty()): afterSkillAW(u1, u2, clashData)
		var u1Recycle = true
		var u1Store = true
		var u1EmoState = true
		var d1 := DataTree.new({} if(u1dice.is_empty()) else 
			getDiceData(u1dice.front(), u1id).duplicate_deep())
		setUnitProp(u1, "dieData", d1)
		if(!d1.isEmpty()): await readDieTag("BeforeDie", u1)
		for i in u2.size():
			setUnitProp(u1, "target", u2[i])
			if(u2dice[i].is_empty()): afterSkillAW(u1, u2, clashData)
			var d2 := DataTree.new({} if(u2dice[i].is_empty()) else 
			getDiceData(u2dice[i].front(), u2id[i]).duplicate_deep())
			setUnitProp(u1, "dieData", d1)
			setUnitProp(u2[i], "dieData", d2)
			if(!d2.isEmpty()): await readDieTag("BeforeDie", u2[i])
			var result := await executeClash(
				u1, u2[i], d1, d2)
			if(result.is_empty()):
				if(!u2dice[i].is_empty()):
					unitList[u2[i]].savedDice.push_back(u2dice[i].pop_front())
				continue
			else:
				u1Store = false
			@warning_ignore("integer_division")
			if(result[0] != 0 && u1EmoState): 
				changeEmotion(1, u1, false)
				u1EmoState = false
			if(result[1] != 0): changeEmotion(1, u2[i], false)
			if(result[2] == 0): u1Recycle = false
			if(result[3] == 0): u2dice[i].pop_front()
		if(u1Store): unitList[u1].savedDice.push_back(u1dice.pop_front())
		elif(!u1Recycle): u1dice.pop_front()

	afterSkillAW(u1, u2, clashData)
	afterSkillAW(u1, u2, clashData)
	var u1Emotion = getUnitData(u1).safeGet("Attributes/EmotionPoints", -1)
	consoleCommand("emotionDisplay", u1, [clashData["u1oldEmotion"], u1Emotion])
	for i in u2.size():
		var u2iEmotion = getUnitData(u2[i]).safeGet("Attributes/EmotionPoints", -1)
		consoleCommand("emotionDisplay", u2[i], [clashData["u2oldEmotion"][i], u2iEmotion])
	setUnitProp(u1, "target", "")
	setUnitProp(u1, "action", -1)
	clearScope(getAction(u1id, "path", ""))
	unitList[u1].speedDie = ["", false]
	for i in u2.size():
		setUnitProp(u2[i], "target", "")
		setUnitProp(u2[i], "action", -1)
		clearScope(getAction(u2id[i], "path", ""))
		unitList[u2[i]].speedDie = ["", false]

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
		data["a1Finished?"] = subdata["a1Finished?"]
		data["a2Finished?"][i] = subdata["a2Finished?"]

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
		"u1oldEmotion": getUnitData(u1).safeGet("Attributes/EmotionPoints", -1),
		"u2oldHealth": getUnitData(u2).safeGet("Attributes/CurrentHealth", -1),
		"u2oldStagger": getUnitData(u2).safeGet("Attributes/CurrentStagger", -1),
		"u2oldEmotion": getUnitData(u2).safeGet("Attributes/EmotionPoints", -1),
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
	if(getAction(u1id, "data/Uses", 0) >= getAction(u1id, "data/Limit", 0) 
	&& getAction(u1id, "data/Limit", 0) > 0):
		await readActionTag("Exhaust", u1)
	if(getAction(u2id, "data/Uses", 0) >= getAction(u2id, "data/Limit", 0) 
	&& getAction(u2id, "data/Limit", 0) > 0):
		await readActionTag("Exhaust", u2)
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
		if(!d1.isEmpty()): await readDieTag("BeforeDie", u1)
		if(!d2.isEmpty()): await readDieTag("BeforeDie", u2)
		var result := await executeClash(
			u1, u2, d1, d2)
		if(result.is_empty()):
			if(u2dice.is_empty()):
				unitList[u1].savedDice.push_back(u1dice.pop_front())
			else:
				unitList[u2].savedDice.push_back(u2dice.pop_front())
			continue
		if(result[0] != 0): changeEmotion(1, u1, false)
		if(result[1] != 0): changeEmotion(1, u2, false)
		if(result[2] == 0): u1dice.pop_front()
		if(result[3]== 0): u2dice.pop_front()

	afterSkill(u1, u2, clashData, true)
	afterSkill(u1, u2, clashData, false)
	var u1Emotion = getUnitData(u1).safeGet("Attributes/EmotionPoints", -1)
	consoleCommand("emotionDisplay", u1, [clashData["u1oldEmotion"], u1Emotion])
	var u2Emotion = getUnitData(u2).safeGet("Attributes/EmotionPoints", -1)
	consoleCommand("emotionDisplay", u2, [clashData["u2oldEmotion"], u2Emotion])
	setUnitProp(u1, "target", "")
	setUnitProp(u2, "target", "")
	setUnitProp(u1, "action", -1)
	setUnitProp(u2, "action", -1)
	clearScope(getAction(u1id, "path", ""))
	clearScope(getAction(u2id, "path", ""))
	unitList[u1].speedDie = ["", false]
	unitList[u2].speedDie = ["", false]

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
	var data := DataTree.new(fileTree.safeGet("Actions/" + action, TYPE_DICTIONARY))
	data.dset("Uses", data.dget("Uses", 0) + 1)
	var dataCopy = Dictionary(data.dataset).duplicate_deep()
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

func executeClash(u1: String, u2: String, d1: DataTree, d2: DataTree) -> Array:
	var d1Data := d1.copy()
	var d2Data := d2.copy()
	setUnitProp(u1, "dieData", d1Data)
	setUnitProp(u2, "dieData", d2Data)
	var d1Roll := [0, 0, 0, false, false]
	var d2Roll := d1Roll.duplicate_deep()
	if(!d1Data.isEmpty()): 
		await readDieTag("Check", u1)
		d1Roll = await rollDieEmbed(u1, d1Data)
	if(!d2Data.isEmpty()): 
		await readDieTag("Check", u2)
		d2Roll = await rollDieEmbed(u2, d2Data)
	EventBus.emit_signal("clashConsole", getDieType(d1Data), d1Roll[0], getDieType(d2Data), d2Roll[0])

	if(d1Roll[0] * d2Roll[0] != 0): # Not Double Unopposed
		await readDieTag("Clash", u1)
		await readDieTag("Clash", u2)
	var clashResults = clashEval(d1Data, d2Data)
	var d1Result: int = clashResults[0]
	var d2Result: int = clashResults[1]
	
	if(d1Roll[0] - d2Roll[0] == 0): # Tie or double unopposed
		if(dmgType(d1Data) == "Evade" && isOffense(d2Data)):
			await readDieTag("Evade", u1)
		if(dmgType(d2Data) == "Evade" && isOffense(d1Data)):
			await readDieTag("Evade", u2)
		return [d1Result, d2Result, 0, 0]
	
	var prioritySwitch := bool((d1Result <= d2Result) && d1Roll[0] != 0)
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
	
	if(canStore(atkDice) && defRoll[0] == 0): return [] # Unopposed Defense/Counter Recycle
	if(isOffense(atkDice)): # Offense win
		var res = await getResistance(defUnit, atkType)
		var dmg := int(atkRoll[0])

		if(dmgType(defDice) == "Block"): # Offense beats Block
			dmg -= defRoll[0]
		var dmgArr := [dmg + res[0], dmg + res[1], atkType]
		dealCombinedDamage(dmgArr, atkUnit, defUnit)
		await readDieTag("Hit", atkUnit)
		if(atkRoll[4]):
			await readDieTag("Crit", atkUnit)
		await readUnitTag("HitReceived", defUnit, {"isCrit": atkRoll[4]})

	elif(atkType == "Block"): # Block win
		var dmgArr := [0, atkRoll[0] - defRoll[0], atkType]
		dealCombinedDamage(dmgArr, atkUnit, defUnit)
	
	else:
		if(isOffense(defDice)): # Evade evades Offense
			await readDieTag("Evade", atkUnit)
		else: # Evade beats Evade/Block
			var dmgArr := [0, -atkRoll[0], atkType, true]
			dealCombinedDamage(dmgArr, atkUnit, atkUnit)
	
	if(!d1Data.isEmpty()): 
		await readUnitTag("UsedDie", u1)
		if(isOffense(d1Data)): await readUnitTag("UsedOffense", u1)
		else: await readUnitTag("UsedDefense", u1)
	if(!d2Data.isEmpty()): 
		await readUnitTag("UsedDie", u2)
		if(isOffense(d2Data)): await readUnitTag("UsedOffense", u2)
		else: await readUnitTag("UsedDefense", u2)
	
	if(d1Data.dget("Recycle", 0) == 0): 
		d1Data.dset("Recycle", 0 if(!(isOffense(atkDice) || isOffense(defDice)))
			else recycleDie(d1Data, d1Result))
	if(d2Data.dget("Recycle", 0) == 0): 
		d2Data.dset("Recycle", 0 if(!(isOffense(atkDice) || isOffense(defDice)))
			else recycleDie(d2Data, d2Result))
	return [d1Result, d2Result, d1Data.dget("Recycle", 0), d2Data.dget("Recycle", 0)]
	#return d1Data.dget("Recycle", 0) * 2 + d2Data.dget("Recycle", 0)

func readUnitTag(tag: String, unit: String, metadata := {}, defaultSeq := []):
	#print("\n\nUNT TAG = ", tag, " @ ", getUnit(unit), " (", unit, ")")
	var unitData = getUnitData(unit)
	if(unitData == null): return
	metadata.merge(composeConditionMetaData(getUnit(unit)))
	var conditionStatuses: Array = unitData.safeGet("Conditions/" + tag, TYPE_ARRAY)
	#print("TAG = ", tag, " -> ", conditionStatuses)
	if(!defaultSeq.is_empty()): 
		conditionStatuses = unitData.safeGet("Statuses", TYPE_DICTIONARY).keys()
	#print("TAG = ", tag, " -> ", conditionStatuses)
	conditionStatuses = conditionStatuses.duplicate_deep()
	for status in conditionStatuses:
		var path = unitData.safeGet("Statuses/" + status + "/File", TYPE_STRING)
		var cond := DataTree.new(fileTree.safeGet(path + "/Conditions", TYPE_DICTIONARY))
		metadata.merge({"Status": status}, true)
		await executeCondition(tag, cond, metadata, defaultSeq)

func readActionTag(tag: String, unit: String, metadata := {}, defaultSeq := []):
	#print("\n\nACT TAG = ", tag, " @ ", getUnit(unit), " (", unit, ")")
	metadata.merge(composeConditionMetaData(getUnit(unit)))
	if(metadata.is_empty()): return
	var dataDict = getAction(metadata["Action"], "data")
	if(dataDict != null):
		await executeCondition(tag, DataTree.new(dataDict), metadata, defaultSeq)
	await readUnitTag(tag, unit, metadata, defaultSeq)

func readDieTag(tag: String, unit: String, metadata := {}, defaultSeq := []):
	#print("\n\nDIE TAG = ", tag, " @ ", getUnit(unit), " (", unit, ")")
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

func clashEval(d1: DataTree, d2: DataTree) -> Array:
	var d1Result = d1.dget("Result/0", 0)
	var d2Result = d2.dget("Result/0", 0)
	var d1Clash := UNOPPOSED
	var d2Clash := UNOPPOSED
	if(d1Result * d2Result != 0):
		d1Clash = (sign(d2Result - d1Result) + 2)
		d2Clash = (sign(d1Result - d2Result) + 2)
	d1.dset("ClashVal", d1Clash)
	d2.dset("ClashVal", d2Clash)
	return [int(d1Clash), int(d2Clash)]

func rollDieEmbed(unit: String, die: DataTree) -> Array:
	var result = await rollDie(unit, die)
	var rawResult = die.dget("rawResult", 0)
	var arr = [
		result, # Final Val
		rawResult, # Raw Val
		rawResult - die.dget("Base"), # Baseless Roll
		rawResult == die.dget("Dice") + die.dget("Base", 0), # isCrit
		rawResult == 1 + die.dget("Base", 0) # isNegativeCrit
	]
	die.dset("Result", arr)
	return arr

func rollDie(unit: String, die: DataTree) -> int:
	var minMax = die.dget("FixedMax", 0) - die.dget("FixedMin", 0)
	var size = die.dget("Dice", 0)
	var base = die.dget("Base", 0)
	if(minMax > 0): return max(1, await rollDieResult(unit, die, "add", [size, base], "*Max"))
	if(minMax < 0): return max(1, await rollDieResult(unit, die, "add", [sign(size), base], "*Min"))
	var advDis = die.dget("Advantage", 0) - die.dget("Disadvantage", 0)
	if(advDis > 0): return max(1, await rollDieResult(unit, die, "rollAdv", [size, base], "Adv"))
	if(advDis < 0): return max(1, await rollDieResult(unit, die, "rollDis", [size, base], "Dis"))
	return max(1, await rollDieResult(unit, die, "roll", [size, base]))

func rollDieResult(unit: String, die: DataTree, method: String, args: Array, type := "") -> int:
	die.dset("rawResult", await callj(method, args))
	if(!type.contains("*")): await readDieTag("RolledDie", unit, {"RollType": type})
	return die.dget("rawResult", 0)

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

func isDefense(die: DataTree) -> bool:
	var type = getDieType(die)
	if(type.is_empty()): return false
	return !isOffense(die)

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
