extends Control

@onready var logs = $GUIArea/VBox/Logs
@onready var input = $GUIArea/VBox/HBox/Input

func _ready() -> void:
	EventBus.connect("RefreshConsole", refreshConsole)
	EventBus.connect("dmgConsole", damageCommand)
	EventBus.connect("clashConsole", displayClash)

func _on_input_text_submitted(new_text: String) -> void:
	if(new_text.is_empty()): return
	readCommand(new_text.replace("[", "[lb]"))
	refreshConsole()
	input.text = ""

func readCommand(text: String) -> void:
	var args := text.split(" ", false)
	var errorCode := 0
	match args[0]:
		"search":
			argPrint(args, "64ffff", "ffff64")
			errorCode = searchCommand(args)
		"unitsearch":
			argPrint(args, "64ffff", "aa64ff", "ffff64")
			errorCode = searchUnitCommand(args)
		"editunit":
			argPrint(args, "64ffff", "aa64ff", "ffff64", "ff64aa")
			errorCode = editUnitCommand(args)
		"scene":
			argPrint(args, "64ffff")
			errorCode = startSceneCommand(args)
		"exfn":
			argPrint(args, "64ffff")
			errorCode = executeFunctionCommand(args)
		"roll", "r":
			argPrint(args, "64ffff", "aa64ff", "ff64ff")
			errorCode = rollCommand(args)
		"light":
			argPrint(args, "64ffff", "aa64ff", "ff64ff")
			errorCode = changeLightCommand(args)
		"dmgunit":
			argPrint(args, "64ffff", "aa64ff", "ff6464", "ffff64")
			errorCode = damageCommand(args)
		"exsk":
			argPrint(args, "64ffff", "ff6464", "64ff64", "ffaa64", "64ffaa")
			errorCode = executeSkillsCommand(args)
		"savedice":
			argPrint(args, "64ffff", "aa64ff")
			errorCode = displaySaveDiceCommand(args)
		"dispskill":
			argPrint(args, "64ffff", "ffff64")
			errorCode = displaySkillCommand(args)
		"dispunit":
			argPrint(args, "64ffff", "aa64ff")
			errorCode = displayUnitCommand(args)
		"dispspeed":
			argPrint(args, "64ffff")
			errorCode = displaySpeedDiceCommand(args)
		"holddice":
			argPrint(args, "64ffff", "ffcc64")
			errorCode = saveDiceCommand(args)
		"remdice":
			argPrint(args, "64ffff", "ffcc64")
			errorCode = removeSpeedDiceCommand(args)
		_:
			errorCode = failedCommand(args)
	errorCommand(errorCode)

func searchCommand(args: PackedStringArray) -> int:
	if(args.size() < 2): return 1
	GameManager.search(args[1])
	return 0

func searchUnitCommand(args: PackedStringArray) -> int:
	if(args.size() < 2): return 1
	if(args.size() < 3):
		addPushConsole(JSON.stringify(GameManager.fetchUnit(args[1]), "    ",false))
		return 0
	addPushConsole(JSON.stringify(GameManager.fetchUnit(args[1] + "/" + args[2]), "    ",false))
	return 0

func editUnitCommand(args: PackedStringArray) -> int:
	if(args.size() < 4): return 1
	var unitData := Functions.unitList[args[1]].dataSet
	var val = args[3]
	if(args[3].ends_with("f") && args[3].trim_suffix("f").is_valid_float()):
		val = args[3].trim_suffix("f").to_float()
	if(args[3].ends_with("i") && args[3].trim_suffix("i").is_valid_int()):
		val = args[3].trim_suffix("i").to_int()
	if(args[3] == "[]arr*" || args[3] == "[lb]]arr*"): val = []
	if(args[3] == "{}obj*"): val = {}
	addPushConsole(JSON.stringify(unitData.dset(args[2],val), "    ",false))
	return 0

func startSceneCommand(_args: PackedStringArray) -> int:
	Functions.sceneStart()
	return 0

func saveDiceCommand(args: PackedStringArray) -> int:
	var dice := ""
	if(args.size() >= 2):
		dice = args[1]
		if(!Functions.diceList.has(dice)): return 4
	Functions.saveSpeedDice(dice)
	return 0

func removeSpeedDiceCommand(args: PackedStringArray) -> int:
	var dice := ""
	if(args.size() >= 2):
		dice = args[1]
		if(!(Functions.diceList.has(dice) || Functions.saveList.has(dice))): return 4
	Functions.removeSpeedDice(dice)
	return 0

func executeFunctionCommand(args: PackedStringArray) -> int:
	if(args.size() < 2): return 1
	var result = Functions.isNestedArg( JSON.parse_string( " ".join( args.slice(1) ).replace("[lb]","[") ) )
	addLog(addStyle("Result : ", "ffffff", true) + str(result))
	return 0

func rollCommand(args: PackedStringArray) -> int:
	if(args.size() < 2): return 1
	if(args.size() < 3):
		addLog(addStyle("Result : ", "ffcc64", true) + 
			# addStyle(str(Functions.roll(args[1].to_int(), 0)), "ffffff"))
			addStyle(str(Functions.callj("roll", [args[1].to_int(), 0])), "ffffff"))
		return 0
	addLog(addStyle("Result : ", "ffcc64", true) + 
		# addStyle(str(Functions.roll(args[1].to_int(), args[2].to_int())),"ffffff"))
		addStyle(str(Functions.callj("roll", [args[1].to_int(), args[2].to_int()])), "ffffff"))
	return 0

func displayUnitCommand(args: PackedStringArray) -> int:
	if(args.size() < 2): return 1
	var unitData = Functions.unitList[args[1]].dataSet
	if(unitData == null): return 3
	var text := "[u]"
	text += addStyle("Name: ", "ffffff", true)
	text += getNameTag(args[1])
	text += " [lb]"
	text += addStyle(unitData.dget("Type", ""), "ffffff")
	text += " , "
	text += addStyle(unitData.dget("Class", ""), "ffffff")
	text += "][/u]\n"
	
	text += addStyle(" Health", "ff6464", true)
	text += ": "
	text += addStyle(castNumDataToString(unitData.dget("Attributes/CurrentHealth", 0)), "ff6464")
	text += "/"
	text += addStyle(castNumDataToString(unitData.dget("Attributes/MaxHealth", 0)), "ff6464")
	text += " | "
	text += addStyle("Stagger", "ffff64", true)
	text += ": "
	text += addStyle(castNumDataToString(unitData.dget("Attributes/CurrentStagger", 0)), "ffff64")
	text += "/"
	text += addStyle(castNumDataToString(unitData.dget("Attributes/MaxStagger", 0)), "ffff64")
	text += "\n"
	
	text += addStyle(" Light", "ffffcc", true)
	text += ": "
	text += addStyle(castNumDataToString(unitData.dget("Attributes/CurrentLight", 0)), "ffffcc")
	text += "/"
	text += addStyle(castNumDataToString(unitData.dget("Attributes/MaxLight", 0)), "ffffcc")
	text += " ("
	text += addStyle(castNumDataToString(unitData.dget("Attributes/LightRegen", 0)), "ccffff")
	text += ") | "
	text += addStyle(" Emotion", "aa64ff", true)
	text += ": "
	text += addStyle(castNumDataToString(unitData.dget("Attributes/EmotionPoints", 0)), "aa64ff")
	text += "\n"
	
	text += addStyle(" Speed", "ffaa64", true)
	text += ": "
	text += addStyle("1d", "ffaa64", true)
	text += addStyle(castNumDataToString(unitData.dget("Attributes/SpeedDiceSize", 0)), "ffaa64")
	text += "+"
	text += addStyle(castNumDataToString(unitData.dget("Attributes/SpeedDiceBase", 0)), "ffaa64")
	text += " ("
	text += addStyle(castNumDataToString(unitData.dget("Attributes/SpeedDiceAmt", 0)), "ff64aa")
	text += ")\n"
	
	text += addStyle(" Slash ", "ffcccc", true)
	text += ": "
	text += weaknessPrint(castNumDataToInt(unitData.dget("Attributes/SlashDamage", 0)))
	text += " , "
	text += weaknessPrint(castNumDataToInt(unitData.dget("Attributes/SlashStagger", 0)), true)
	text += "\n"
	text += addStyle(" Pierce", "ccffcc", true)
	text += ": "
	text += weaknessPrint(castNumDataToInt(unitData.dget("Attributes/PierceDamage", 0)))
	text += " , "
	text += weaknessPrint(castNumDataToInt(unitData.dget("Attributes/PierceStagger", 0)), true)
	text += "\n"
	text += addStyle(" Blunt ", "ccccff", true)
	text += ": "
	text += weaknessPrint(castNumDataToInt(unitData.dget("Attributes/BluntDamage", 0)))
	text += " , "
	text += weaknessPrint(castNumDataToInt(unitData.dget("Attributes/BluntStagger", 0)), true)
	text += "\n"
	
	
	addPushConsole(text)
	return 0

func weaknessPrint(val: int, isStagger := false) -> String:
	var text := ""
	var c1 := "ff"
	var c2 := "ff"
	if(val > 0):
		text = "+"
		c2 = "64"
	if(val < 0):
		c1 = "aa"
		c2 = "32"
	if(val == 0):
		text = " "
		c1 = "cc"
		c2 = "50"
	return addStyle(text + str(val), c1 + (c1 if(isStagger) else c2) + c2)

func displaySaveDiceCommand(args: PackedStringArray) -> int:
	if(args.size() < 2): return 1
	if (!Functions.unitList.has(args[1])): return 3
	var unit := Functions.unitList[args[1]]
	for d in unit.savedDice:
		var dieParse := d.split("/")
		if(dieParse.size() != 2): return 4
		displaySkillDice(dieParse[0], int(dieParse[1]))
	return 0

func displaySkillCommand(args: PackedStringArray) -> int:
	if(args.size() < 2): return 1
	var data = DataTree.new(GameManager.filetree.dget("Actions/" + args[1], {}))
	if(data.isEmpty()): return 2
	addLog(addStyle("[" + displaySkillTextField(data, "Cost") + "] ", "ffaa64", true) +
		displaySkillTextField(data, "Name", "ffffff", true))
	for l in data.safeGet("PreText", TYPE_ARRAY):
		if(l is String): addLog(addStyle(l, "aaaaaa"))
	
	displaySkillDice(data, -1)
	
	for l in data.safeGet("PostText", TYPE_ARRAY):
		if(l is String): addLog(addStyle(l, "aaaaaa"))
	return 0

func displaySkillDice(action, index: int):
	var data: DataTree
	if(action is String): data = DataTree.new(Functions.fileTree.safeGet("Actions/" + action, TYPE_DICTIONARY))
	if(action is DataTree): data = action
	if(!(data is DataTree)): return
	
	var diceList = data.safeGet("Dice", TYPE_ARRAY)
	if(diceList.size() < index): return
	
	if(index < 0):
		for i in diceList.size():
			displaySkillDice(data, i)
		return
	
	var d = DataTree.new(diceList[index])
	var dicePower := int(displaySkillTextField(d, "Dice"))
	var diceBase := int(displaySkillTextField(d, "Base"))
	var diceText = "" if (dicePower == 0) else ("1d" + str(abs(dicePower)))
	if(dicePower < 0): diceText = ("" if (diceBase == 0) else str(diceBase)) + "-" + diceText
	elif(dicePower > 0): diceText += "" if (diceBase == 0) else (("+" if (diceBase > 0) else "") + str(diceBase))
	else: diceText = str(diceBase)
	
	var type := displaySkillTextField(d, "Type")
	addLog(getTypeDisplay(type) + " " + addStyle(diceText, getTypeColor(type)))
	
	for l in d.safeGet("Text", TYPE_ARRAY):
		if(l is String): addLog("  " + addStyle(l, "aaaaaa"))

func displaySkillTextField(dict: DataTree, field: String, color := "", bold := false) -> String:
	var data = dict.dget(field, 0)
	var text: String
	if(dict.isComplex(data)):
		text = "N/A"
		color = "646464"
		bold = true
	else: text = str(int(data) if (data is float) else data)
	if(color.is_empty()): return text
	return addStyle(text, color, bold)

func getTypeDisplay(type: String) -> String:
	var typeDisp := "[lb]N/A]"
	if(type.contains("Offense")):
		typeDisp = "[lb]" + type.substr(0,1) + "O]"
	if(type == "Block"):
		typeDisp = "[lb]B]"
	if(type == "Evade"):
		typeDisp = "[lb]E]"
	if(type.contains("Counter")):
		typeDisp = "[lb]" + type.substr(0,1) + "C]"
	return addStyle(typeDisp, getTypeColor(type), true)

func getTypeColor(type: String) -> String:
	if(type.contains("Offense")):
		return "ff6464"
	if(type == "Block"):
		return "64aaff"
	if(type == "Evade"):
		return "64aaff"
	if(type.contains("Counter")):
		return "ffcc64"
	return "aaaaaa"

func displaySpeedDiceCommand(_args: PackedStringArray) -> int:
	addLog(underlineStr(boldStr("Speed Dice Turn Order")))
	for d in Functions.sortSpeedDice(Functions.diceList):
		printSpeedDice(d, 0)
	for d in Functions.sortSpeedDice(Functions.saveList):
		printSpeedDice(d, 1)
	for d in Functions.sortSpeedDice(Functions.usedList):
		printSpeedDice(d, 2)
	return 0

func printSpeedDice(dice: String, listID := 0) -> void:
	var unit := Functions.getUnitFromDice(dice)
	if(!Functions.unitList.has(unit)): return
	var unitData := Functions.unitList[unit].dataSet
	var dict: Dictionary[String, int]
	var color: String
	match listID:
		1: 
			dict = Functions.saveList
			color = "64aaff"
		2: 
			dict = Functions.usedList
			color = "ff64aa"
		_: 
			dict = Functions.diceList
			color = "ffaa64"
	var speed := dict[dice]
	if(speed == null): return
	var text := " "
	text += addStyle(str(speed), color, true)
	text += " | "
	text += getNameTag(unit)
	text += " "
	var curLight = unitData.dget("Attributes/CurrentLight", "")
	var maxLight = unitData.dget("Attributes/MaxLight", "")
	text += addStyle("⬢".repeat(curLight),"ffffcc")
	text += addStyle("⬢".repeat(maxLight - curLight),"646464")
	text += " ("
	text += addStyle(dice, "ffcc64")
	text += ")"
	addLog(text)

func executeSkillsCommand(args: PackedStringArray) -> int:
	if(args.size() < 5): return 1
	# displaySkillCommand(["",args[3]])
	# displaySkillCommand(["",args[4]])
	Functions.executeSkills(args[1], args[2], args[3], args[4])
	return 0

func changeLightCommand(args: PackedStringArray) -> int:
	if(args.size() < 3): return 1
	if(!Functions.unitList.has(args[1])): return 3
	var unitData := Functions.unitList[args[1]].dataSet
	if(!args[2].is_valid_int()): return 5
	var diff := int(args[2])
	var oldLight = unitData.dget("Attributes/CurrentLight", "")
	var maxLight = unitData.dget("Attributes/MaxLight", "")
	unitData.dset("Attributes/CurrentLight", min(max(0, oldLight + diff), maxLight))
	var newLight = unitData.dget("Attributes/CurrentLight", "")
	var text := ""
	text += getNameTag(args[1])
	text += ": "
	text += addStyle("⬢".repeat(oldLight),"ffffcc")
	text += addStyle("⬢".repeat(maxLight - oldLight),"646464")
	text += " -> "
	text += addStyle("⬢".repeat(newLight),"ffffcc")
	text += addStyle("⬢".repeat(maxLight - newLight),"646464")
	addPushConsole(text)
	return 0

func damageCommand(args: PackedStringArray) -> int:
	if(args.size() < 3): return 1
	if(!Functions.unitList.has(args[1])): return 3
	var unitdata := Functions.unitList[args[1]].dataSet
	if(!args[2].is_valid_int()): return 5
	var hdmg := int(args[2])
	var sdmg: int
	if(args.size() < 4): sdmg = hdmg
	elif(!args[3].is_valid_int()): return 5
	else: sdmg = int(args[3])
	var oldHealth = unitdata.safeGet("Attributes/CurrentHealth", -1)
	var oldStagger = unitdata.safeGet("Attributes/CurrentStagger", -1)
	unitdata.dset("Attributes/CurrentHealth", 
		min(max(0, oldHealth - hdmg), unitdata.safeGet("Attributes/MaxHealth", -1)))
	unitdata.dset("Attributes/CurrentStagger", 
		min(max(0, oldStagger - sdmg), unitdata.safeGet("Attributes/MaxStagger", -1)))
	var newHealth = unitdata.safeGet("Attributes/CurrentHealth", -1)
	var newStagger = unitdata.safeGet("Attributes/CurrentStagger", -1)
		
	var text := ""
	text += underlineStr(boldStr("Damaged : " + getNameTag(args[1])))
	text += "\n"

	text += " "
	text += addStyle("Hlt", "ff6464", true)
	text += ": "
	text += addStyle(str(oldHealth), "ff6464")
	text += " -> "
	text += addStyle(str(newHealth), "646464" if(newHealth <= 0) else "ff6464")
	text += " | "
	text += addStyle("Stg", "ffff64", true)
	text += ": "
	text += addStyle(str(oldStagger), "ffff64")
	text += " -> "
	text += addStyle(str(newStagger), "646464" if(newStagger <= 0) else "ffff64")
	
	addPushConsole(text)
	return 0

func displayClash(t1: String, r1: int, t2: String, r2: int):
	var text := ""
	text += addStyle("[lb]" + (str(r1) if r1 > 0 else "-") + "]", getTypeColor(t1), true)
	text += " "
	if(r1 > r2):
		if(r2 > 0): text += addStyle("->>", "64ff64")
		else: text += addStyle("-->", "ff6464")
	elif(r2 > r1):
		if(r1 > 0): text += addStyle("<<-", "64ff64")
		else: text += addStyle("<--", "ff6464")
	else:
		text += addStyle(">X<", "ffff64")
	text += " "
	text += addStyle("[lb]" + (str(r2) if r2 > 0 else "-") + "]", getTypeColor(t2), true)
	addPushConsole(text)


func failedCommand(args: PackedStringArray) -> int:
	addLog(addStyle(" ".join(args), "aaaaaa", false))
	return -1

func errorCommand(code: int) -> void:
	var text := ""
	match code:
		-1: text = "No Command!"
		0: return
		1: text = "Missing Args!"
		2: text = "Skill does not exist!"
		3: text = "Unit does not exist!"
		4: text = "Dice does not exist!"
		5: text = "Wrong-Type Args!"
		_: text = "Unspecified Error!"
	addLog(addStyle(text, "ff6464", true))

func argPrint(args: PackedStringArray, ...colors: Array) -> void:
	var text := ""
	for i in args.size():
		var a := args[i]
		var c = colors[i] if(i < colors.size() && colors[i] is String) else "aaaaaa"
		text += addStyle(a, c, i == 0)
		if(i + 1 < args.size()): text += " "
	addLog(text)

func castNumDataToInt(val) -> int:
	if(val is String && (str(val).is_valid_float() || str(val).is_valid_int())):
		return int(val)
	if(val is float || val is int):
		return int(val)
	return 0
	
func castNumDataToString(val) -> String:
	if(val is String && (str(val).is_valid_float() || str(val).is_valid_int())):
		return str(int(val))
	if(val is float || val is int):
		return str(int(val))
	return "N/A"

func getNameTag(unit: String) -> String:
	if(!Functions.unitList.has(unit)): return ""
	var unitData := Functions.unitList[unit].dataSet
	var unitName = unitData.dget("Name","")
	var unitColor = unitData.dget("Color","")
	if(!(unitColor is String)): unitColor = "aaaaaa"
	if(unitName is String):
		return addStyle("[lb]" + unit + "] " + unitName, unitColor, true)
	return ""

func addStyle(text: String, color := "ffffff", bold := false, italic := false, underline := false) -> String:
	var styleText := "[color=" + color + "]" + text + "[/color]"
	if(bold): styleText = boldStr(styleText)
	if(italic): styleText = italicStr(styleText)
	if(underline): styleText = underlineStr(styleText)
	return styleText

func boldStr(text: String) -> String:
	return "[b]" + text + "[/b]"

func italicStr(text: String) -> String:
	return "[i]" + text + "[/i]"

func underlineStr(text: String) -> String:
	return "[u]" + text + "[/u]"

func addPushConsole(s: String) -> void:
	var lines: PackedStringArray = s.split("\n");
	for l in lines:
		addLog(l)
	refreshConsole()

func addLog(s: String) -> void:
	GameManager.consoleLog.append(s)

func renderLog(limit: int) -> void:
	logs.text = "";
	var arr = GameManager.consoleLog.duplicate()
	arr.reverse()
	arr.resize(min(limit,arr.size()))
	arr.reverse()
	for i in range(0,arr.size()):
		logs.text += arr[i] + "\n"

func refreshConsole() -> void:
	renderLog(40)
	
