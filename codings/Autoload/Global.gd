extends Node

const settings_path := "user://Settings.tres"

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

## The current settings
var settings: Setting

## Complimentary abilities available
var complimentaries: Array[String]

## Time info
var process_frame := 0
var start_time := 0.0
var first_start_time := 0.0
var play_time := 0.0
var save_time := 0.0

## Steam data
var using_steam := false
var steam_app_id := 4059970
var steam_user_id: int

## Account identifier for the player (Shown in the menu)
var player_name: String = "Local"

## Shortcut to alcine's name
static var alcine: String:
	get(): return Party.get_member("Alcine").FirstName

## For updating info like the party
signal check


#region System
func _ready() -> void:
	init_user()
	start_time = Time.get_unix_time_from_system()
	process_mode = Node.PROCESS_MODE_ALWAYS
	init_settings()

	#print(Input.get_joy_name(0))
	Controller.rumble(0, 0.1, 0.1)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


func quit(save_first := true) -> void:
	if save_first:
		if get_tree().root.has_node("Options"):
			get_tree().root.get_node("Options").close()

		if get_tree().root.has_node("MainMenu"):
			get_tree().root.get_node("MainMenu").close()

		if (
			not Battle.in_battle and is_instance_valid(player) and is_instance_valid(room) and (
			Global.controllable or get_tree().root.has_node("MainMenu") or get_tree().root.has_node("Options"))
		):
			Loader.icon_save()
			await Loader.save()
		elif is_instance_valid(room):
			if not await Global.warning("The game cannot be saved right now.\nQuit the game anyways?", "QUIT", ["Canel", "Quit Game"]):
				return

		await Loader.transition(Direction.CENTER)
		if Engine.has_singleton("Steam") and using_steam:
			Steam.steamShutdown()

		Global.save_settings()

	get_tree().quit()


func init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		return

	var steam := Engine.get_singleton("Steam")
	OS.set_environment("SteamAppId", str(steam_app_id))
	OS.set_environment("SteamGameId", str(steam_app_id))
	var initialize_response: Dictionary = steam.steamInitEx(steam_app_id)
	print_rich("[color=orange]Did Steam initialize?: %s " % initialize_response)
	#Steam.inputInit()
	#Steam.enableDeviceCallbacks()
	#SteamInput.init()
	if initialize_response.get("status") == 0:
		print_rich("[color=orange]Running with Steam")
		using_steam = true
		steam_user_id = steam.getSteamID32(steam.getSteamID())
		player_name = steam.getPersonaName()
		print_rich("[color=orange]User: ", player_name, " ", steam_user_id)
	elif(
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


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			quit()

		NOTIFICATION_WM_ABOUT:
			OS.shell_open("https://raidev.eu/miras-journal")


func _physics_process(delta: float) -> void:
	process_frame += 1


func nodes_of_type(node: Node, className: String, result: Array) -> void:
	if !node: return
	if node.is_class(className):
		if node and (node is Light2D and node.shadow_enabled) and not "Editor" in node.name: result.push_back(node)

	for child in node.get_children():
		await nodes_of_type(child, className, result)
#endregion

#region settings


func refresh() -> void:
	await Loader.save()
	Loader.load_game()
	print(Input.should_ignore_device(0x28de0, 0x11ff))


func fullscreen(tog: bool = !settings.Fullscreen) -> void:
	if !settings: await init_settings()
	if Engine.is_embedded_in_editor():
		Global.toast("Can't fullscreen while the window is embeded")
		settings.Fullscreen = false
		return

	if tog:
		settings.Fullscreen = true
		get_window().mode = Window.MODE_FULLSCREEN
		await get_tree().create_timer(0.1).timeout
		get_window().grab_focus()
	else:
		settings.Fullscreen = false
		get_window().mode = Window.MODE_WINDOWED
		#if OS.to_string() == "Linux":
			#get_window().size = Vector2i(1280,800)
			#await get_tree().create_timer(0.03).timeout
			#get_window().position = DisplayServer.screen_get_size(0)/2 - Vector2i(1280,800)/2

	await get_tree().create_timer(0.15).timeout
	get_window().grab_focus()
	save_settings()


func reset_settings() -> void:
	settings = Setting.new()
	customize_default_settings()
	var err: Error = ResourceSaver.save(settings, settings_path)

	if err != OK:
		printerr(error_string(err))
		#OS.alert("Cannot write to save data directory: "+error_string(error))


func customize_default_settings() -> void:
	if using_steam:
		var steam := Engine.get_singleton("Steam")

		if OS.get_environment("STEAMDECK") == "1" or steam.isSteamRunningOnSteamDeck():
			settings.ControlSchemeEnum = 7
			settings.ControlSchemeOverride = load("res://UI/Input/SteamDeck.tres")
			print_rich("[color=orange]Running on Steam Deck, setting control scheme")

		if steam.isSteamInBigPictureMode():
			fullscreen(true)
			print_rich("[color=orange]Running on Big Picture, enabling fullscreen")

	if OS.to_string() == "macOS":
		settings.UpscaledRes = false


func init_settings() -> void:
	if not ResourceLoader.exists(settings_path):
		print_rich("[color=orange]No settings found, initializing...")
		reset_settings()
		await Event.wait()

	settings = ResourceLoader.load(settings_path)

	if not is_instance_valid(settings):
		print_rich("[color=orange]settings file is invalid, settings will be restored to default")
		reset_settings()
		await Event.wait()
		settings = load(settings_path)

	if not is_instance_valid(settings):
		OS.alert("Something is wrong with the settings file or user folder")

	apply_settings()


func apply_settings() -> void:
	#const base_res := Vector2(1280, 800)

	if settings.Fullscreen:
		fullscreen(true)

	if settings.GlowEffect:
		World.environment.glow_enabled = true
	else: World.environment.glow_enabled = false

	if settings.UpscaledRes:
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	else:
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

	#else:
		#get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		#get_window().content_scale_size = base_res * settings.UpscaleFactor
		#get_window().content_scale_factor = settings.UpscaleFactor

	AudioServer.set_bus_volume_db(0, settings.MasterVolume)
	AudioServer.set_bus_volume_db(1, settings.MusicVolume)
	AudioServer.set_bus_volume_db(2, settings.SFXVolume)
	AudioServer.set_bus_volume_db(3, settings.UIVolume)
	AudioServer.set_bus_volume_db(4, settings.VoicesVolume)
	AudioServer.set_bus_volume_db(5, settings.FootstepsVolume)

	if settings.VSync: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if using_steam:
		settings.PlayerName = player_name
	else: player_name = settings.PlayerName
	Global.save_settings()


func get_playtime() -> int:
	play_time = save_time + Time.get_unix_time_from_system() - start_time
	return int(play_time)


func save_settings() -> void:
	ResourceSaver.save(settings, settings_path)
	print_rich("[color=orange]settings saved")
#endregion


#region party Checks
func heal_party() -> void:
	for i in Party.current:
		i.full_heal()

	for i in Party.members:
		i.full_heal()


func add_test_state(chara: Actor) -> void:
	for i in ResourceLoader.list_directory("res://database/States/"):
		var state: String = i.replace(".tres", "")
		var ab: Ability = load("res://database/Abilities/Debug/TestState.tres").duplicate()
		ab.name += state
		ab.InflictsState = state
		chara.Abilities.append(ab)


func unlock_all_abilities() -> void:
	for mem in Party.members:
		for ab in mem.LearnableAbilities:
			mem.Abilities.append(ab)


func give_every_ability() -> void:
	for i in ResourceLoader.list_directory("res://database/Abilities/"):
		var ab: Ability = load("res://database/Abilities/" + i).duplicate()
		Party.Leader.Abilities.append(ab)


func add_complimentary(ability: String, from_name: String = "Mira Levenor", popup := true) -> void:
	if popup:
		var scenepack: PackedScene = load("res://UI/LevelUp/Levelup.tscn")
		var scene: Node = scenepack.instantiate()
		get_tree().root.add_child(scene)
		await Event.wait()
		scene.get_node("Levelup").got_complimentary(await Query.get_ability(ability), from_name)
		await scene.get_node("Levelup").closed

	if ability not in Global.complimentaries:
		Global.complimentaries.append(ability)


func use_ability_overworld(ab: Ability, user: Actor) -> void:
	get_viewport().gui_release_focus()
	if Ability.TP.HEALING in ab.Types:
		await Hud.choose_member(ab, user)
#endregion


func game_over() -> void:
	$"/root".add_child((await Loader.load_res("res://UI/GameOver/GameOver.tscn")).instantiate())


func options(submenu := 0) -> void:
	if get_tree().root.has_node("Options"): return
	var control := Global.controllable
	var opt: OptionsUI = (await Loader.load_res("uid://bh82q5qur5ppl")).instantiate()
	Global.controllable = control

	match submenu:
		1:
			opt.set_no_main()
			opt.save_managment()

		3:
			opt.set_no_main()
			opt.manual()

	get_tree().root.add_child(opt)


func title_screen() -> void:
	if Global.room != null: Global.room.queue_free()
	if not get_tree().root.has_node("Initializer"):
		var init: Node = (await Loader.load_res("uid://ds1hwdmholrjy")).instantiate()
		get_tree().root.add_child(init)
	else: get_tree().root.get_node("Initializer").focus()


func member_details(chara: Actor, menu := 0) -> void:
	if chara == null: return
	var dub: Node = (await Loader.load_res("uid://b7kxxkiuyhc4n")).instantiate()
	get_tree().root.add_child(dub)
	dub.draw_character(chara, menu)


func complimentary_ui(chara: Actor) -> void:
	if chara == null: return
	var dub: Node = (await Loader.load_res("res://UI/Complimentary/ComplimentaryUI.tscn")).instantiate()
	get_tree().root.add_child(dub)
	await Event.wait()
	dub.draw_character(chara)


func next_day_ui() -> void:
	get_tree().root.add_child((await Loader.load_res("res://UI/Misc/DayChangeUi.tscn")).instantiate())


func alcine_naming() -> void:
	var scene: Node = (await Loader.load_res("uid://c0dgn2l164lj0")).instantiate()
	get_tree().root.add_child(scene)
	await scene.start()


func veinet_map(cur: String) -> void:
	var Map: Node = (await Loader.load_res("uid://b31w3e1tiwp0y")).instantiate()
	get_tree().root.add_child(Map)
	Map.focus_place(cur)


func intro_effect(ref: Node) -> void:
	var node: Node = (await Loader.load_res("uid://jrg5p2oev3io")).instantiate()
	Global.room.add_child(node)
	node.ref = ref
	node.animate()


func toast(string: String) -> void:
	if get_node_or_null("/root/Toast"):
		$/root/Toast.free()

	print_rich("[color=orange]Toast: " + string)
	var tost: Node = (preload("res://UI/Misc/Toast.tscn")).instantiate()
	get_tree().root.add_child.call_deferred(tost)
	tost.get_node("BoxContainer/Toast/Label").set_deferred("text", string)


func warning(text: String, label: String = "WARNING", awnser: Array[String] = ["No", "Yes"], color: Color = Color.hex(0xdc000eff)) -> int:
	#if get_node_or_null("/root/Warning"):
		#$/root/Warning.free()

	print_rich("[color=orange]Warn: " + text)
	var tost: Node = (await Loader.load_res("res://UI/Misc/Warning.tscn")).instantiate()
	get_tree().root.add_child(tost)
	await Event.wait()
	if is_instance_valid(tost):
		return await tost.ask_for_confirm(text, label, awnser, color)
	else: return false


func error(text: String, label: String = "ERROR") -> void:
	await warning(text, label, ["OK"])


func location_name(string: String) -> void:
	if get_node_or_null("/root/LocationName"):
		$/root/LocationName.free()

	var tost: Node = (await Loader.load_res("res://UI/Misc/LocationName.tscn")).instantiate()
	get_tree().root.add_child(tost)
	tost.get_node("Label").set_deferred("text", string)
