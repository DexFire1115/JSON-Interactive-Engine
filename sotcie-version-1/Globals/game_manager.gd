extends Node

# Handling FileIO Functions
var loadfile: ZIPReader = ZIPReader.new()
var loadroot: String
var fileinfo: Dictionary
#var homeDir: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
var homeDir: String = "/home/dexfire1115/Documents/SotCIE/"

# Handling ConsoleLogging
@export var consoleLog: PackedStringArray = []

# Handling Data Management
@export var filetree: DataTree
@export var soundDict := {}
@onready var loadArchive = $LoadArchive
@export var clockData: DataTree

func _ready() -> void:
	loadArchive.current_dir = homeDir

func _on_load_archive_file_selected(path: String) -> void:
	homeDir = path.rsplit("/", true, 1)[0]
	if(FileAccess.file_exists(path)):
		loadfile.open(path)
		var fileList := loadfile.get_files()
		for filePath in fileList:
				if filePath.ends_with("ref"):
					loadroot = filePath.rsplit("ref").get(0)
		filetree = DataTree.new()
		for filePath in fileList:
			fileBranch(filePath)
		loadfile.close()
		clockData = DataTree.new()
		clockData.dset("sceneStats", [])
		clockData.dset("sumStats", {})
		clockData.dset("start", Time.get_ticks_msec() / 60000.0)
		Functions.runGameStat()

func search(s: String) -> void:
	addPushConsole(JSON.stringify(filetree.dget(s, ""), "    ",false))

func addPushConsole(s: String) -> void:
	var lines: PackedStringArray = s.split("\n");
	for l in lines:
		consoleLog.append(l)
	pushConsole()

func pushConsole() -> void:
	EventBus.emit_signal("RefreshConsole")

func fileBranch(path: String) -> void:
	var pathStack := path.split(loadroot, true, 1)
	if(pathStack.size() < 2): return
	pathStack = pathStack[1].split("/")
	var tempDict := filetree.dataset
	for level in pathStack:
		if(level.is_empty()): return
		if(level.ends_with(".json")):
			tempDict.set(level, JSON.parse_string(loadfile.read_file(path).get_string_from_ascii()))
			if(str(tempDict.get(level)) == "<null>"): print("ERROR : ", level)
			#print(str(tempDict.get(level)).substr(0,100))
			continue
		if(level.ends_with(".wav")):
			soundDict.set(level, AudioStreamWAV.load_from_buffer(loadfile.read_file(path)))
			tempDict.set(level, "@ExportWAV")
			continue
		if(level == "ref"):
			tempDict.set(level, null)
			continue
		if(!tempDict.has(level)): tempDict.set(level, {})
		tempDict = tempDict[level]

# Marked for removal
func fetchUnit(path: String) -> Variant:
	var split := path.split("/", true, 1)
	if(split.size() < 1): return [{},-2]
	var unit: Unit = Functions.unitList.get(split[0])
	var subpath: String
	if(split.size() < 2): subpath = ""
	else: subpath = split[1]
	if(!(unit is Unit)): return null
	return unit.dataSet.dget(subpath, null)

func newScene():
	var sceneStr := str(Functions.scene)
	var lastSceneStr := str(Functions.scene - 1)
	var lastDict = clockData.dget("sceneStats/" + lastSceneStr, {})
	updateRates(lastDict)
	clockData.dset("sceneStats/" + lastSceneStr, lastDict)
	var newDict := {}
	updateRates(newDict)
	clockData.dset("sceneStats/" + sceneStr, newDict)

func updateRates(dict: Dictionary):
	if(!dict.has("startTime")): dict["startTime"] = Time.get_ticks_msec() / 60000.0
	dict["endTime"] = Time.get_ticks_msec() / 60000.0
	dict["deltaTime"] = dict["endTime"] - dict["startTime"]
	if(!dict.has("speedDice")): dict["speedDice"] = 0
	dict["mpss"] = dict["deltaTime"] / dict["speedDice"]
	dict["sdph"] = 60.0 / dict["mpss"]

func recordSpeedDie():
	var sceneStr := str(Functions.scene)
	var dict = clockData.dget("sceneStats/" + sceneStr, {})
	if(!dict.has("speedDice")): dict["speedDice"] = 0
	dict["speedDice"] = dict["speedDice"] + 1
	updateRates(dict)

func compileSum():
	var sumDict = clockData.dget("sumStats", {})
	sumDict["startTime"] = clockData.dget("sceneStats/0/startTime", 0)
	sumDict["endTime"] = Time.get_ticks_msec() / 60000.0
	sumDict["deltaTime"] = sumDict["endTime"] - sumDict["startTime"]
	sumDict["speedDice"] = Array(clockData.dget("sceneStats", [])).reduce(
		func(accum, elem): return accum + elem.get("speedDice", 0), 0)
	sumDict["mpss"] = sumDict["deltaTime"] / sumDict["speedDice"]
	sumDict["sdph"] = 60.0 / sumDict["mpss"]
