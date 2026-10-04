extends Node

## Determines if the player should have control
## Prefer to use Event.give_control() and Event.take_control() instead of this
var controllable: bool = true:
	set(x):
		controllable = x

## Current battle scene, null if not in battle
var bt: Battle = null:
	get(): return Battle.current

## Current player node
var player: Mira:
	get():
		if is_instance_valid(player):
			return player

		return null

## Current room node
var room: Room

## Active camera in the room (Not battle camera)
var camera: Camera2D:
	get:
		if not is_instance_valid(room):
			return null

		return Global.room.cam

## Time info
var process_frame := 0
var start_time := 0.0
var first_start_time := 0.0
var play_time := 0.0
var save_time := 0.0

## Shortcut to alcine's name
static var alcine: String:
	get(): return Party.get_member("Alcine").FirstName

## For updating info like the party
signal check
signal battle_end(result: int)


#region System
func _ready() -> void:
	start_time = Time.get_unix_time_from_system()
	process_mode = Node.PROCESS_MODE_ALWAYS

	Controller.rumble(0, 0.1, 0.1)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


func quit(save_first := true) -> void:
	if save_first:
		if UI.is_open("Options"):
			UI.get_node("Options").close()

		if UI.is_open("MainMenu"):
			UI.get_node("MainMenu").close()

		if (
			not Battle.in_battle and is_instance_valid(player) and is_instance_valid(room) and (
			Global.controllable or UI.is_open("MainMenu") or UI.is_open("Options"))
		):
			await Loader.save()
		elif is_instance_valid(room):
			if not await UI.warning("The game cannot be saved right now.\nQuit the game anyways?", "QUIT", ["Canel", "Quit Game"]):
				return

		await Transition.close_in()
		if Engine.has_singleton("Steam") and SteamManager.using_steam:
			Steam.steamShutdown()

		SettingsManager.save_settings()

	get_tree().quit()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			quit()

		NOTIFICATION_WM_ABOUT:
			OS.shell_open("https://raidev.eu/miras-journal")


func _physics_process(delta: float) -> void:
	process_frame += 1
#endregion


func get_playtime() -> int:
	play_time = save_time + Time.get_unix_time_from_system() - start_time
	return int(play_time)
