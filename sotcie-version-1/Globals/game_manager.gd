extends Node

# Handling FileIO Functions
var loadfile: ZIPReader = ZIPReader.new()
var loadroot: String
var fileinfo: Dictionary
var homeDir: String = "/home/dexfire1115/Documents/SotCIE/"

# Handling ConsoleLogging
var consoleLog: PackedStringArray = []

# Handling Data Management
var filetree: Dictionary

# Handling Game Processes
var unitList: Dictionary[String, Unit]
var scene: int = 0
var diceList: Dictionary[String, int]
var saveList: Dictionary[String, int]
var usedList: Dictionary[String, int]

func _ready() -> void:
	$LoadArchive.current_dir = homeDir

func _on_load_archive_file_selected(path: String) -> void:
	homeDir = path.rsplit("/",true,1)[0]
	if(FileAccess.file_exists(path)):
		loadfile.open(path);
		var fileList := loadfile.get_files()
		for filePath in fileList:
				if filePath.ends_with("ref"):
					loadroot = filePath.rsplit("ref").get(0)
		for filePath in fileList:
			fileBranch(filePath)
		loadfile.close()
		Functions.runGameStat()
#		for i in range(10):
#			print(Functions.callj("propCall", ["tempArr", "duplicate"]))
#			Functions.callj("propCall", ["tempArr", "set", 
#				{"roll": [
#					{"propCall": ["tempArr", "size"]}, 
#					-1
#				]} , 
#				{"roll": [10, 10]}
#			])
#		print(Functions.callj("propCall", ["tempArr", "duplicate"]))

func search(s: String) -> void:
	addPushConsole(JSON.stringify(fetchData(s)[0], "    ",false))
	print(fetchData(s)[1])

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
	var tempDict := filetree
	for level in pathStack:
		if(level.is_empty()): return
		if(level.ends_with(".json")):
			tempDict.set(level, JSON.parse_string(loadfile.read_file(path).get_string_from_ascii()))
			continue
		if(level == "ref"):
			tempDict.set(level, null)
			continue
		if(!tempDict.has(level)): tempDict.set(level, {})
		tempDict = tempDict[level]

func fetchData(path: String) -> Array:
	return DataTree.fetchData(filetree, path)

func fetchUnit(path: String) -> Array:
	var split := path.split("/", true, 1)
	if(split.size() < 1): return [{},-2]
	var unit: Unit = unitList.get(split[0])
	var subpath: String
	if(split.size() < 2): subpath = ""
	else: subpath = split[1]
	if(!(unit is Unit)): return [{},-2]
	return unit.fetchData(subpath)
