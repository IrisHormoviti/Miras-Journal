extends Node

const settings_path := "user://Settings.tres"

## Envs that identify a device that the game ships a preset for
const DEVICE_DEFAULTS: Dictionary[String, String] = {
	"CLAM_GUEST": "res://database/SettingsPresets/ClamOS.tres",
	"STEAMDECK": "res://database/SettingsPresets/SteamDeck.tres",
}

var settings: Setting

signal settings_changed


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	init_settings()


func _on_node_added(node: Node) -> void:
	if settings and node is Light2D:
		node.enabled = settings.dynamic_lights


func init_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		print_rich("[color=dark_magenta]No settings found, initializing...")
		reset_settings()
		await Event.wait()

	settings = ResourceLoader.load(settings_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	if not is_instance_valid(settings):
		print_rich("[color=dark_magenta]settings file is invalid, settings will be restored to default")
		reset_settings()
		await Event.wait()
		settings = ResourceLoader.load(settings_path, "", ResourceLoader.CACHE_MODE_IGNORE)

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

	Engine.max_fps = settings.fps

	var container := get_node_or_null("/root/GameViewport") as SubViewportContainer

	if container:
		var shrink := 1

		if settings.upscale_factor > 0.0 and settings.upscale_factor < 1.0:
			shrink = max(1, int(round(1.0 / settings.upscale_factor)))

		container.stretch_shrink = shrink
		var viewport := container.get_node_or_null("SubViewport") as SubViewport

		if viewport:
			if shrink > 1:
				viewport.size_2d_override = Vector2i(
					int(ProjectSettings.get_setting("display/window/size/viewport_width")),
					int(ProjectSettings.get_setting("display/window/size/viewport_height")))

				viewport.size_2d_override_stretch = true
			else:
				viewport.size_2d_override = Vector2i.ZERO

	_apply_dynamic_lights()
	Controller.handle_remaps()

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
	for env: String in DEVICE_DEFAULTS:
		if OS.get_environment(env) == "1":
			apply_defaults(DEVICE_DEFAULTS[env])
			return

	if SteamManager.using_steam:
		var steam := Engine.get_singleton("Steam")

		if steam.isSteamRunningOnSteamDeck():
			apply_defaults(DEVICE_DEFAULTS["STEAMDECK"])

		if steam.isSteamInBigPictureMode():
			fullscreen(true)
			print_rich("[color=dark_magenta]Running on Big Picture, enabling fullscreen")

	if OS.to_string() == "macOS":
		settings.upscaled_res = false


func apply_defaults(path: String) -> void:
	var preset: Setting = load(path)

	if not preset:
		return

	settings = preset.duplicate()
	print_rich("[color=dark_magenta]Applying ", preset.resource_name, " defaults")


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


func _apply_dynamic_lights() -> void:
	if not settings:
		return

	_apply_lights(get_tree().root)


func _apply_lights(node: Node) -> void:
	if node is Light2D:
		node.enabled = settings.dynamic_lights

	for child in node.get_children():
		_apply_lights(child)
