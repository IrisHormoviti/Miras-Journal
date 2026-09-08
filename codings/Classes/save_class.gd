extends Resource
class_name SaveFile

const VERSION := 8

## Title of the save file, independent of the save file name
@export var title: String = "Autosave"

## Path to the room the player is in
@export var room: String

## Name of the room the player is in, independent of the room path
@export var room_name: String = "???"

## String array of the party member codenames, 
## must be 4 in length, empty strings for empty slots
@export var party: Array[StringName] = [&"Mira", &"", &"", &""]

## Array of dictionaries containing member data
## Refer to the Actor class for the structure of the dictionary
@export var members: Array[Dictionary]

## Position of the player in the room, in global coordinates
@export var player_position: Vector2

## The "camera index" to be used in the room
@export var camera_index: int = 0

## Array of names of unlocked complimentary abilities
@export var complimentaries: Array[String]

## IDs of defeated enemies
@export var defeated_enemies: Array

## The time the save file was created, in unix time
@export var start_time: float

## The time the save file was created, in unix time
@export var saved_time: float

## The time played in seconds
@export var play_time: float

## Array of diary entries for each day ID
@export var diary: Dictionary[int, PackedStringArray]

## List of flags and their value
@export var flags: Dictionary[StringName, int]

## List of item filenames
@export var inventory: Array[String]

## The version of the save file
## 0 will be ignored and loaded anyways
@export var version := 0

## Depricated
var Day: int
var TimeOfDay: int


func preview() -> Texture:
	match party:
		["Mira", "Alcine"]:
			return await Loader.load_res("res://art/Previews/2.png")

		_:
			return await Loader.load_res("res://art/Previews/1.png")


func migrate() -> SaveFile:
	var migratable := true

	match version:
		6:
			flags.set("day", Day)
			flags.set("time", TimeOfDay)
			version = 7

		_:
			migratable = false

	if migratable == false:
		print("File cannot be migrated")
		return null

	if version != Loader.save_file_version:
		print("more conversions need to be done")
		return migrate()
	else:
		print("Success!")
		return self as SaveFile
