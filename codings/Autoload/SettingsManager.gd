extends Node

const settings_path := "user://Settings.tres"

var settings: Setting

signal settings_changed


func _ready() -> void:
	init_settings()


func init_settings() -> void:
	if not ResourceLoader.exists(settings_path):
		print_rich("[color=dark_magenta]No settings found, initializing...")
		reset_settings()
		await Event.wait()

	settings = ResourceLoader.load(settings_path)

	if not is_instance_valid(settings):
		print_rich("[color=dark_magenta]settings file is invalid, settings will be restored to default")
		reset_settings()
		await Event.wait()
		settings = load(settings_path)

	if not is_instance_valid(settings):
		OS.alert("Something is wrong with the settings file or user folder")

	apply_settings()


func apply_settings() -> void:
	if settings.fullscreen:
		fullscreen(true)

	if settings.glow_effect:
		World.environment.glow_enabled = true
	else:
		World.environment.glow_enabled = false

	if settings.upscaled_res:
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	else:
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

	AudioServer.set_bus_volume_db(0, settings.master_volume)
	AudioServer.set_bus_volume_db(1, settings.music_volume)
	AudioServer.set_bus_volume_db(2, settings.sfx_volume)
	AudioServer.set_bus_volume_db(3, settings.ui_volume)
	AudioServer.set_bus_volume_db(4, settings.voices_volume)
	AudioServer.set_bus_volume_db(5, settings.footsteps_volume)

	if settings.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	if SteamManager.using_steam:
		settings.player_name = SteamManager.player_name
	else:
		SteamManager.player_name = settings.player_name

	save_settings()


func save_settings() -> void:
	ResourceSaver.save(settings, settings_path)
	print_rich("[color=dark_magenta]settings saved")


func reset_settings() -> void:
	settings = Setting.new()
	customize_default_settings()
	var err: Error = ResourceSaver.save(settings, settings_path)

	if err != OK:
		printerr(error_string(err))


func customize_default_settings() -> void:
	if SteamManager.using_steam:
		var steam := Engine.get_singleton("Steam")

		if OS.get_environment("STEAMDECK") == "1" or steam.isSteamRunningOnSteamDeck():
			settings.control_scheme_enum = 7
			settings.control_scheme_override = load("res://UI/Input/SteamDeck.tres")
			print_rich("[color=dark_magenta]Running on Steam Deck, setting control scheme")

		if steam.isSteamInBigPictureMode():
			fullscreen(true)
			print_rich("[color=dark_magenta]Running on Big Picture, enabling fullscreen")

	if OS.to_string() == "macOS":
		settings.upscaled_res = false


func fullscreen(tog: bool = !settings.fullscreen) -> void:
	if !settings:
		await init_settings()

	if Engine.is_embedded_in_editor():
		UI.toast("Can't fullscreen while the window is embeded")
		settings.fullscreen = false
		return

	if tog:
		settings.fullscreen = true
		get_window().mode = Window.MODE_FULLSCREEN
		await get_tree().create_timer(0.1).timeout
		get_window().grab_focus()
	else:
		settings.fullscreen = false
		get_window().mode = Window.MODE_WINDOWED

	await get_tree().create_timer(0.15).timeout
	get_window().grab_focus()
	save_settings()
