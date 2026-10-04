extends Node

var using_steam := false
var steam_app_id := 4059970
var steam_user_id: int
var player_name: String = "Local"


func _ready() -> void:
	init_user()


func init_user() -> void:
	steam_user_id = 0
	init_steam()

	# If a user ID wasn't set by steam
	if steam_user_id == 0:
		if FileAccess.file_exists("user://last_user_id.txt"):
			steam_user_id = int(FileAccess.get_file_as_string("user://last_user_id.txt"))
			print_rich("[color=orange]Using last used user ID, ", steam_user_id)

	# Create a user folder if it doesn't exist
	if not DirAccess.dir_exists_absolute("user://" + str(steam_user_id)):
		print_rich("[color=orange]Creating user folder for ", steam_user_id)
		DirAccess.make_dir_absolute("user://" + str(steam_user_id))

	# If there's an ID now but, the previous one was 0, migrate the save data
	if FileAccess.file_exists("user://last_user_id.txt"):
		var last_id: int = int(FileAccess.get_file_as_string("user://last_user_id.txt"))

		if FileAccess.file_exists("user://" + str(steam_user_id)) and last_id == 0 and steam_user_id != 0:
			print_rich("[color=orange]Migrating from local to account")

			for i in DirAccess.get_files_at("user://0"):
				if not FileAccess.file_exists("user://" + str(steam_user_id) + "/" + i):
					DirAccess.copy_absolute("user://0/" + i, "user://" + str(steam_user_id) + "/" + i)

	# Write the current ID to a file
	var last_id_file: FileAccess = FileAccess.open("user://last_user_id.txt", FileAccess.WRITE)
	last_id_file.store_string(str(steam_user_id))

	# Move user:// to the new directory
	ProjectSettings.set("application/config/custom_user_dir_name", "miras-journal/" + str(steam_user_id))


func init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		return

	var steam := Engine.get_singleton("Steam")
	OS.set_environment("SteamAppId", str(steam_app_id))
	OS.set_environment("SteamGameId", str(steam_app_id))
	var initialize_response: Dictionary = steam.steamInitEx(steam_app_id)
	print_rich("[color=orange]Did Steam initialize?: %s " % initialize_response)

	if initialize_response.get("status") == 0:
		print_rich("[color=orange]Running with Steam")
		using_steam = true
		steam_user_id = steam.getSteamID32(steam.getSteamID())
		player_name = steam.getPersonaName()
		print_rich("[color=orange]User: ", player_name, " ", steam_user_id)
	elif (
		initialize_response.get("status") == 1 and
		initialize_response.get("verbal") != "Could not determine Steam client install directory."
	):
		if not steam.isSubscribed():
			if steam_app_id == 4059970:
				print_rich("[color=orange]The user doesn't own the game, testing playtest")
				steam_app_id = 4063790
				init_steam()
				return
			elif steam_app_id == 4063790:
				print_rich("[color=orange]The user doesn't own playtest either, running locally")
