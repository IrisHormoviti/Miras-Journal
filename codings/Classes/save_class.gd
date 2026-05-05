extends Resource
class_name SaveFile

@export var Name: String = "Autosave"
@export var Party: Array[StringName] = [&"Mira", &"", &"", &""]
@export var RoomPath: String
@export var RoomName: String = "???"
@export var Position: Vector2
@export var Camera: int = 0
@export var Z: int = 1
@export var Members: Array[Dictionary]
@export var Complimentaries: Array[String]
@export var Defeated: Array
@export var StartTime: float
@export var SavedTime: float
@export var PlayTime: float
@export var Diary: Dictionary[int, PackedStringArray]
@export var Flags: Dictionary[StringName, int]
@export var version := 0
@export var Inventory: Array[String]

## Depricated
var Day: int
var TimeOfDay: int


func preview() -> Texture:
	match Party:
		["Mira", "Alcine"]:
			return await Loader.load_res("res://art/Previews/2.png")
		_:
			return await Loader.load_res("res://art/Previews/1.png")


func migrate() -> SaveFile:
	var migratable := true
	match version:
		6:
			Flags.set("day", Day)
			Flags.set("time", TimeOfDay)
			version = 7
		_:
			migratable = false
	if migratable == false:
		print("File cannot be migrated")
		return null
	if version != Loader.SaveVersion:
		print("more conversions need to be done")
		return migrate()
	else:
		print("Success!")
		return self as SaveFile
