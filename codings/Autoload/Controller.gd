extends Node

signal controller_changed

const SCHEMES: Dictionary[Variant, Variant] = {
	"None": "res://UI/Input/None.tres",
	"Keyboard": "res://UI/Input/Keyboard.tres",
	"Nintendo": "res://UI/Input/Nintendo.tres",
	"Generic": "res://UI/Input/Generic.tres",
	"Xbox": "res://UI/Input/Xbox.tres",
	"PlayStation": "res://UI/Input/PlayStation.tres",
	"PlayStationOld": "res://UI/Input/PlayStationOld.tres",
	"SteamDeck": "res://UI/Input/SteamDeck.tres",
}

## Currently active device, such as "Nintendo Switch" or "Keyboard"
var device: String = ""
## Last frame that an input event was received
var last_input := 0

var scheme_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	handle_remaps()


func get_scheme() -> ControlScheme:
	if !Global.settings: return get_scheme_from_string("None")
	if not Global.settings.ControlSchemeAuto:
		return Global.settings.ControlSchemeOverride

	if device == "":
		device = Global.settings.LastUsedDevice

	Global.settings.LastUsedDevice = device

	return get_scheme_from_string(get_scheme_from_device())


func get_scheme_from_string(type: String) -> ControlScheme:
	if not scheme_cache.has(type):
		scheme_cache[type] = load(SCHEMES[type])

	return scheme_cache[type]


func get_scheme_from_device() -> String:
	if device == "Keyboard":
		return "Keyboard"

	if "Nintendo" in device or "Pro Controller" in device or "GameCube" in device:
		return "Nintendo"

	if "XInput" in device or "360" in device:
		return "Generic"

	if "Series" in device or "Xbox" in device or "XBox" in device:
		return "Xbox"

	if "PS4" in device or "DualShock 4" in device or "PS5" in device or "DualSense" in device:
		return "PlayStation"

	if "PS3" in device or "DualShock" in device or "PS2" in device or "Sony" in device or "PlayStation" in device:
		return "PlayStationOld"

	if "Steam" in device:
		return "SteamDeck"

	return "Generic"


func _input(event: InputEvent) -> void:
	if last_input == Global.process_frame: return

	if event is InputEventMouseMotion:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if not event.is_pressed() and not (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5):
		return

	var prev_dev := device
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	if event is InputEventKey:
		device = "Keyboard"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		device = Input.get_joy_name(event.device)

	if prev_dev != device:
		if prev_dev != "":
			controller_changed.emit()
			Global.toast("Using " + device)

		handle_remaps()

	last_input = Global.process_frame
	var is_fullscreen := get_window().mode == Window.MODE_FULLSCREEN

	if Global.settings and is_fullscreen != Global.settings.Fullscreen:
		Global.fullscreen(is_fullscreen)

	check_menu_buttons(event)


func handle_remaps() -> void:
	var scheme := get_scheme()
	var use_alt := scheme.AltConfirm

	remap_action("ui_accept", "AltConfirm" if use_alt else "MainConfirm")
	remap_action("ui_cancel", "AltCancel" if use_alt else "MainCancel")


func remap_action(target_action: StringName, source_action: StringName) -> void:
	# Clean up joypad events from target action
	for event in InputMap.action_get_events(target_action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			InputMap.action_erase_event(target_action, event)

	# Copy joypad events from source action
	for event in InputMap.action_get_events(source_action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			InputMap.action_add_event(target_action, event)


func cancel() -> String:
	return "ui_cancel"


func confirm() -> String:
	return "ui_accept"


func rumble(strong: float, weak: float, duration: float, delay: float = 0) -> void:
	if Global.settings and Global.settings.ControllerVibration:
		if delay > 0: await Event.wait(delay, false)
		Input.start_joy_vibration(0, strong, weak, duration)


func check_menu_buttons(event: InputEvent) -> void:
	if Input.is_action_just_pressed("Fullscreen"):
		Global.fullscreen()

	if Input.is_action_just_pressed("SaveDir"):
		OS.shell_open(OS.get_user_data_dir())

	if Input.is_action_just_pressed("Refresh"):
		Global.refresh()

	if Global.controllable and not Hud.expanded:
		var can_open_menu := false

		if is_instance_valid(Global.player) and Global.player.sprite and Global.room.is_ready:
			can_open_menu = "Idle" in Global.player.sprite.animation

		if can_open_menu:
			if Input.is_action_just_pressed("Options"):
				Global.options(0)
			elif Input.is_action_just_pressed("SaveManagment"):
				Global.options(1)
			elif Input.is_action_just_pressed("Manual"):
				Global.options(3)
			elif Input.is_action_just_pressed("MainMenu"):
				Hud.main_menu()

	if Global.settings and Global.settings.DebugMode:
		var text_edit_visible: bool = Hud.get_node("%DebugTextEdit").visible

		if Input.is_action_just_pressed("DebugFlag"):
			Hud.cmd()
		elif not text_edit_visible:
			if Input.is_action_just_pressed("Save"):
				Loader.save()
			elif Input.is_action_just_pressed("Load"):
				Loader.load_game()
			elif Input.is_action_just_pressed("Debug"):
				Loader.travel_to("Debug", Vector2.ZERO, 0, "")
				Event.remove_flag("HideDate")
				Event.remove_flag("FlameActive")
			elif Input.is_action_just_pressed("DebugT"):
				Passive.open("testbush", "greetings")
			elif Input.is_action_just_pressed("DebugP"):
				Global.toast("Controllable set to " + str(!Global.controllable))
				if Global.controllable:
					Event.take_control()
				else:
					Event.give_control()
			elif Input.is_action_just_pressed("DebugHide"):
				if Hud.has_node("CanvasLayer/DebugText"):
					Hud.get_node("CanvasLayer/DebugText").hide()
			elif Input.is_action_just_pressed("DebugI"):
				Item.add_item("SmallPotion", "Con")
			elif Input.is_action_just_pressed("DebugA"):
				Textbox.open("testbush", "add_to_party")
			elif Input.is_action_just_pressed("Debug0"):
				Engine.time_scale = 1.0 if Engine.time_scale == 0.1 else 0.1
